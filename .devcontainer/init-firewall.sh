#!/bin/bash
# デフォルト deny + ホワイトリスト方式のファイアウォール
# postStartCommand でコンテナ起動時に毎回実行される
# 必要な capability: NET_ADMIN, NET_RAW (devcontainer.json の runArgs で設定)
set -euo pipefail

echo "=== ファイアウォール初期化 ==="

# Docker 内部 DNS ルールを保持 (フラッシュ前に退避)
DOCKER_DNS_RULES=$(iptables-save | grep -- "127.0.0.11" || true)

iptables -F OUTPUT
iptables -F INPUT
iptables -F FORWARD

if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "$DOCKER_DNS_RULES" | iptables-restore --noflush
fi

# 基本通信の許可
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT    # DNS
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT    # SSH (git)
iptables -A OUTPUT -o lo -j ACCEPT                 # localhost
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# IP ホワイトリスト (ipset: O(1) の高速マッチング)
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

# 許可ドメインの DNS 解決と登録
# 注意: 起動時に1回だけ解決。CDN の IP 変更には対応できない
ALLOWED_DOMAINS=(
    "api.anthropic.com"             # Claude API
    "claude.ai"                     # OAuth 認証 (Pro/Max サブスクリプション)
    "console.anthropic.com"         # OAuth トークン交換・リフレッシュ
    "platform.claude.com"           # Console 認証 (console.anthropic.com のリブランド)
    "sentry.io"                     # エラーレポート
    "statsig.anthropic.com"         # Feature flags
    "statsig.com"                   # Feature flags
    "registry.npmjs.org"            # npm
    "marketplace.visualstudio.com"  # VS Code 拡張
    "vscode.blob.core.windows.net"  # VS Code アセット
    "update.code.visualstudio.com"  # VS Code 更新
)

echo "ドメイン解決中..."
for domain in "${ALLOWED_DOMAINS[@]}"; do
    ips=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+' || true)
    for ip in $ips; do
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done
    if [ -n "$ips" ]; then
        echo "  ✓ $domain"
    else
        echo "  ✗ $domain (DNS 解決失敗)"
    fi
done

# GitHub IP レンジ (API から動的取得し、aggregate で CIDR 集約)
echo "GitHub IP レンジ取得中..."
GITHUB_META=$(curl -s --max-time 10 https://api.github.com/meta 2>/dev/null || true)
if [ -n "$GITHUB_META" ]; then
    GITHUB_IPS=$(echo "$GITHUB_META" | jq -r '(.git // [])[], (.web // [])[], (.api // [])[]' 2>/dev/null | sort -u | aggregate 2>/dev/null || true)
    for cidr in $GITHUB_IPS; do
        ipset add allowed-domains "$cidr" 2>/dev/null || true
    done
    echo "  ✓ GitHub IP レンジ追加完了"
else
    echo "  ✗ GitHub IP レンジ取得失敗"
fi

# ホストネットワーク (ローカル開発サーバー等へのアクセス用)
HOST_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$HOST_GATEWAY" ]; then
    HOST_SUBNET=$(echo "$HOST_GATEWAY" | sed 's/\.[0-9]*$/.0\/24/')
    ipset add allowed-domains "$HOST_SUBNET" 2>/dev/null || true
    echo "  ✓ ホストネットワーク: $HOST_SUBNET"
fi

# ホワイトリスト適用 + デフォルト REJECT (DROP ではなく即座にエラーを返す)
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable

echo ""
echo "=== 動作検証 ==="

if curl -s --max-time 3 https://example.com > /dev/null 2>&1; then
    echo "  ✗ FAIL: example.com がブロックされていない"
else
    echo "  ✓ PASS: example.com がブロックされている"
fi

if curl -s --max-time 5 https://api.github.com > /dev/null 2>&1; then
    echo "  ✓ PASS: api.github.com に接続可能"
else
    echo "  ✗ WARN: api.github.com に接続できない"
fi

echo ""
echo "=== ファイアウォール初期化完了 ==="
