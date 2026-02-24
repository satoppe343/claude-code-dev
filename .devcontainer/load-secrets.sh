#!/usr/bin/env bash
# ホスト側 (macOS) で実行される initializeCommand スクリプト
# Claude Code の認証情報を収集し .env.run に書き出す
#
# 認証方式 (優先順):
#   1. ~/.claude/.credentials.json (claude login で生成、user:profile スコープ付き)
#   2. macOS キーチェーンの CLAUDE_CODE_OAUTH_TOKEN (claude setup-token、非インタラクティブ用)
#
# 初回セットアップ:
#   claude login  (ブラウザ認証 → ~/.claude/.credentials.json が生成される)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.run"

# 出力ファイルを初期化 (空でも --env-file のエラー防止)
: > "$ENV_FILE"
chmod 600 "$ENV_FILE"

HAS_CREDENTIALS=false

# --- 方式1: .credentials.json (プライマリ / TUI 対応) ---
CREDENTIALS_FILE="${HOME}/.claude/.credentials.json"
if [ -f "$CREDENTIALS_FILE" ]; then
    # user:profile スコープの有無を検証
    # .credentials.json の構造: { "claudeAiOauth": { "scopes": [...], ... } }
    if command -v jq &>/dev/null; then
        SCOPES=$(jq -r '
            (.claudeAiOauth.scopes // []) | join(",")
        ' "$CREDENTIALS_FILE" 2>/dev/null || true)

        if [ -n "$SCOPES" ]; then
            if echo "$SCOPES" | grep -q "user:profile"; then
                echo "✓ .credentials.json: user:profile スコープ確認済み"
            else
                echo "WARNING: .credentials.json に user:profile スコープがありません" >&2
                echo "  TUI モードで認証エラーが発生する可能性があります" >&2
                echo "  再度 'claude login' を実行してください" >&2
            fi
        fi
    fi

    CREDENTIALS_B64=$(base64 < "$CREDENTIALS_FILE" | tr -d '\n')
    printf 'CLAUDE_CREDENTIALS_B64=%s\n' "$CREDENTIALS_B64" >> "$ENV_FILE"
    echo "✓ .credentials.json を Base64 エンコードしました"
    HAS_CREDENTIALS=true
else
    echo "INFO: ~/.claude/.credentials.json が見つかりません (TUI にはこのファイルが必要です)" >&2
fi

# --- 方式2: macOS キーチェーン (フォールバック / 非インタラクティブ用) ---
# 注意: CLAUDE_CODE_OAUTH_TOKEN は Claude Code CLI が .credentials.json より優先して使用する。
# .credentials.json が存在する場合にこの変数も設定すると、スコープ不足 (user:inference のみ)
# のトークンが優先されて TUI モードの認証に失敗する。
# そのため .credentials.json がない場合のみフォールバックとして設定する。
if [ "$HAS_CREDENTIALS" = false ]; then
    TOKEN=$(security find-generic-password \
        -a "$USER" \
        -s "CLAUDE_CODE_OAUTH_TOKEN" \
        -w 2>/dev/null || true)

    if [ -n "$TOKEN" ]; then
        printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "$TOKEN" >> "$ENV_FILE"
        echo "✓ OAuth トークンをキーチェーンから読み込みました (非インタラクティブ用フォールバック)"
        HAS_CREDENTIALS=true
    fi
else
    echo "INFO: .credentials.json がプライマリ認証として使用されるため CLAUDE_CODE_OAUTH_TOKEN のロードをスキップ"
fi

# --- 結果サマリー ---
if [ "$HAS_CREDENTIALS" = false ]; then
    echo "" >&2
    echo "ERROR: 認証情報が見つかりません" >&2
    echo "" >&2
    echo "セットアップ手順:" >&2
    echo "  ホスト側のターミナルで以下を実行してください:" >&2
    echo "" >&2
    echo "  claude login" >&2
    echo "" >&2
    echo "  ブラウザ認証が完了すると ~/.claude/.credentials.json が生成されます" >&2
    echo "  その後、DevContainer を再ビルドしてください" >&2
fi
