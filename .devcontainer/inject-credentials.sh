#!/usr/bin/env bash
# コンテナ内で実行される postStartCommand スクリプト
# CLAUDE_CREDENTIALS_B64 環境変数をデコードして .credentials.json に復元する
#
# 冪等性: 環境変数が未設定の場合は何もしない
# named volume に書き込むため再起動後も永続化される
set -euo pipefail

CLAUDE_DIR="/home/node/.claude"
CREDENTIALS_FILE="${CLAUDE_DIR}/.credentials.json"

if [ -z "${CLAUDE_CREDENTIALS_B64:-}" ]; then
    echo "INFO: CLAUDE_CREDENTIALS_B64 が未設定です (.credentials.json の注入をスキップ)"
    exit 0
fi

# ディレクトリ確保 (named volume が空の場合)
mkdir -p "$CLAUDE_DIR"

# デコードして一時ファイルに書き出し → アトミックに配置
TEMP_FILE=$(mktemp "${CLAUDE_DIR}/.credentials.json.XXXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT

printf '%s' "$CLAUDE_CREDENTIALS_B64" | base64 -d > "$TEMP_FILE"

# JSON として有効か検証
if ! jq empty "$TEMP_FILE" 2>/dev/null; then
    echo "ERROR: デコードされた .credentials.json が不正な JSON です" >&2
    exit 1
fi

# 既存ファイルと内容が同一ならスキップ (不要な書き込みを避ける)
if [ -f "$CREDENTIALS_FILE" ] && cmp -s "$TEMP_FILE" "$CREDENTIALS_FILE"; then
    echo "✓ .credentials.json は最新です (変更なし)"
    exit 0
fi

mv "$TEMP_FILE" "$CREDENTIALS_FILE"
trap - EXIT
chmod 600 "$CREDENTIALS_FILE"

echo "✓ .credentials.json をコンテナに注入しました"

# --- TUI 初回プロンプトの事前設定 ---
# named volume が空の初回起動時、TUI は以下のダイアログを順に表示する:
#   1. オンボーディング (テーマ選択)
#   2. ワークスペース信頼確認 (プロジェクト単位)
# これらを事前設定して即座に使用可能にする
CLAUDE_JSON="${CLAUDE_DIR}/.claude.json"
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"

if [ ! -f "$CLAUDE_JSON" ]; then
    echo '{}' > "$CLAUDE_JSON"
fi

NEEDS_UPDATE=false

# hasCompletedOnboarding チェック
if ! jq -e '.hasCompletedOnboarding == true' "$CLAUDE_JSON" > /dev/null 2>&1; then
    NEEDS_UPDATE=true
fi

# hasTrustDialogAccepted チェック (プロジェクト単位)
if ! jq -e --arg ws "$WORKSPACE_DIR" '.projects[$ws].hasTrustDialogAccepted == true' "$CLAUDE_JSON" > /dev/null 2>&1; then
    NEEDS_UPDATE=true
fi

if [ "$NEEDS_UPDATE" = true ]; then
    jq --arg ws "$WORKSPACE_DIR" '
        .hasCompletedOnboarding = true |
        .projects[$ws] = (.projects[$ws] // {}) + {
            "hasTrustDialogAccepted": true,
            "hasCompletedProjectOnboarding": true
        }
    ' "$CLAUDE_JSON" > "${CLAUDE_JSON}.tmp" && mv "${CLAUDE_JSON}.tmp" "$CLAUDE_JSON"
    echo "✓ TUI 初回プロンプトを事前設定しました"
else
    echo "✓ TUI 初回プロンプトは設定済みです (変更なし)"
fi
