#!/bin/bash
set -e

ZSHRC="$HOME/.zshrc"
PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"

# ---- 外部プラグインの clone ----
[ -d "$PLUGINS_DIR/zsh-autosuggestions" ] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"

[ -d "$PLUGINS_DIR/fast-syntax-highlighting" ] || \
    git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting "$PLUGINS_DIR/fast-syntax-highlighting"

[ -d "$PLUGINS_DIR/zsh-completions" ] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions "$PLUGINS_DIR/zsh-completions"

# ---- .zshrc カスタマイズ (冪等性を確保) ----
if ! grep -q 'starship init zsh' "$ZSHRC" 2>/dev/null; then

    # [sed 挿入] source 前に必要な設定を挿入
    sed -i '/^source \$ZSH\/oh-my-zsh.sh/i \
ZSH_THEME=""\
plugins+=(npm node docker docker-compose sudo extract z colored-man-pages history-substring-search zsh-autosuggestions fast-syntax-highlighting zsh-completions)' "$ZSHRC"

    # [追記] source 後でも有効な設定を末尾に追加
    cat >> "$ZSHRC" << 'EOF'

# ---- DevContainer カスタマイズ ----

# ロケール
export LANG='ja_JP.UTF-8'
export LANGUAGE='ja_JP:ja'
export LC_ALL='ja_JP.UTF-8'

# zsh-autosuggestions
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# シェル履歴 (named volume で永続化)
export HISTFILE=/commandhistory/.zsh_history
export PROMPT_COMMAND='history -a'

# Starship プロンプト (Oh My Zsh source 後に初期化)
eval "$(starship init zsh)"

# プロンプト表示切替 (minimal ↔ verbose)
# verbose: git_status, nodejs, package バージョンを表示
prompt-verbose() {
  export STARSHIP_CONFIG="$HOME/.config/starship-verbose.toml"
  echo "Prompt: verbose (git_status, nodejs, package ON)"
}
prompt-minimal() {
  unset STARSHIP_CONFIG
  echo "Prompt: minimal (default)"
}
EOF
fi

# ---- Starship 設定ファイルの配置 ----
mkdir -p "$HOME/.config"
cp /workspace/.devcontainer/starship.toml "$HOME/.config/starship.toml"
cp /workspace/.devcontainer/starship-verbose.toml "$HOME/.config/starship-verbose.toml"
