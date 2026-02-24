# syntax=docker/dockerfile:1
FROM node:24-trixie-slim

ARG TZ
ENV TZ="${TZ}"

# node:24-trixie-slim は最小構成のため、必要なパッケージを明示的にインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    locales \
    git \
    curl \
    wget \
    jq \
    unzip \
    gnupg2 \
    zsh \
    less \
    nano \
    vim \
    man-db \
    sudo \
    procps \
    # SSH (git push 用)
    openssh-client \
    # ファイアウォール (init-firewall.sh) で使用
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Docker Desktop の VM は nftables カーネルモジュールを持たないため legacy に切替
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# ロケール生成 (slim イメージはロケールデータを含まない)
RUN sed -i '/ja_JP.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=ja_JP.UTF-8
ENV LC_ALL=ja_JP.UTF-8

RUN mkdir -p /usr/local/share/npm-global && \
    chown -R node:node /usr/local/share

ARG USERNAME=node

# シェル履歴: named volume で永続化 (devcontainer.json で設定)
RUN mkdir /commandhistory && \
    touch /commandhistory/.zsh_history && \
    chown -R $USERNAME /commandhistory

RUN mkdir -p /workspace /home/node/.claude && \
    chown -R node:node /workspace /home/node/.claude

# オンボーディング + ワークスペース信頼の事前設定
# CLAUDE_CONFIG_DIR=/home/node/.claude のため、~/.claude.json (ホームレベル) ではなく
# volume 内の ~/.claude/.claude.json が使用される。
# inject-credentials.sh (postStartCommand) が volume 内に正しい構造で設定するため
# ここではフォールバック用に最小限のみ配置する
RUN echo '{"hasCompletedOnboarding": true}' > /home/node/.claude.json && \
    chown node:node /home/node/.claude.json

ENV DEVCONTAINER=true
WORKDIR /workspace

# カスタムファイアウォール (Feature 付属の init-firewall.sh との衝突を回避するため別名)
COPY init-firewall.sh /usr/local/bin/setup-firewall.sh
RUN chmod +x /usr/local/bin/setup-firewall.sh && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-firewall.sh" > /etc/sudoers.d/node-firewall && \
    chmod 0440 /etc/sudoers.d/node-firewall

# 認証情報注入スクリプト (postStartCommand で実行)
COPY inject-credentials.sh /usr/local/bin/inject-credentials.sh
RUN chmod +x /usr/local/bin/inject-credentials.sh

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

# zsh-in-docker で Oh My Zsh + テーマ + プラグインを一括インストール
# -x: zsh/git/curl は既にインストール済みのためスキップ
# 外部プラグイン: URL指定で自動 git clone される
ARG ZSH_IN_DOCKER_VERSION=1.2.1
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -t powerlevel10k/powerlevel10k \
    -p git \
    -p npm \
    -p node \
    -p docker \
    -p docker-compose \
    -p sudo \
    -p extract \
    -p z \
    -p colored-man-pages \
    -p history-substring-search \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zdharma-continuum/fast-syntax-highlighting \
    -p https://github.com/zsh-users/zsh-completions \
    -a 'ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20' \
    -a 'ZSH_AUTOSUGGEST_USE_ASYNC=1' \
    -a 'ZSH_AUTOSUGGEST_MANUAL_REBIND=1' \
    -a 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' \
    -a 'POWERLEVEL9K_DISABLE_GITSTATUS=true' \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.zsh_history" \
    -x

# zsh-in-docker が .zshrc にハードコードする en_US.UTF-8 を ja_JP.UTF-8 に修正
RUN sed -i "s/en_US.UTF-8/ja_JP.UTF-8/g; s/en_US:en/ja_JP:ja/g" ~/.zshrc

# powerlevel10k テーマを手動インストール
# zsh-in-docker は "powerlevel10k/powerlevel10k" を GitHub ユーザー名と誤認するため
# 正しいリポジトリ (romkatv/powerlevel10k) から直接 clone する
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ~/.oh-my-zsh/custom/themes/powerlevel10k
