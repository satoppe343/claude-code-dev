#!/bin/bash
set -e

/workspace/.devcontainer/setup-zsh.sh

# プロジェクト依存パッケージのインストール
npm install
