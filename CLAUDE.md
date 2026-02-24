# DevContainer Setup - 設定方針

## プロジェクト概要

Claude Code を Docker コンテナ内で使用するための開発環境構成。
Node.js 開発向け。ミニマムなイメージサイズと実用性・セキュリティのバランスを重視。

## 設計方針

### イメージサイズ

- なるべく小さく保つ。ただし実用性を犠牲にしない
- slim バリアントを基本とし、必要なパッケージのみ明示的にインストールする

### OS / ランタイム選定

- なるべく新しい安定版を使う
- なるべくサイズが小さく採用実績が多いイメージを使う
- claude-codeとnode-jsを使用する上で制限があるイメージは採用しない
- Docker タグはコードネーム固定とする（デフォルトタグは OS が予告なく変わりうるため）

### セキュリティ

- 三層防御を基本とする: 入口（コンテンツ取得）、処理（ファイル操作）、出口（ネットワーク送信）
- ファイアウォール（iptables）を含める。デフォルト deny + ホワイトリスト方式
- settings.json で curl/wget/nc 等のネットワーク送信コマンドを deny する
- WebFetch は allow に入れず都度確認とする（プロンプトインジェクションの入口になりうるため）
- Read 権限は作業ディレクトリ + 必要な設定ファイルにスコープ限定する
- 機密ファイル（.env, ~/.ssh, ~/.aws 等）は deny で保護する

### 認証

- サブスクリプション（Pro/Max）を使用する。ANTHROPIC_API_KEY は絶対に設定しない（設定すると API 従量課金になる）
- WindowsおよびmacOSでの既知の不具合が確認されている方式は採用しない
- プライマリ認証: `claude login`（ブラウザ認証）で `user:inference` + `user:profile` スコープ付きの `.credentials.json` を取得
- `.credentials.json` を Base64 エンコードして環境変数経由でコンテナに注入（load-secrets.sh → inject-credentials.sh）
- フォールバック: `claude setup-token` のトークンを macOS キーチェーンに保存（非インタラクティブモード `claude -p` 用）
- `setup-token` は `user:inference` スコープのみのため TUI モードでは認証エラーになる（既知の制限）
- ホストの `~/.claude/` をバインドマウントしない（macOS 側が `.credentials.json` を削除する問題を回避）
- 認証情報は named volume で永続化し、再ビルド時の再認証を回避する
- 認証においてホストOS側で設定が必要であればその手順を実行するよう促す

### シェル環境

- zsh + Oh My Zsh を使用する
- 外部プラグインを含むフル構成とする（autosuggestions, syntax-highlighting, completions）
- テーマは おすすめのものを3つほどピックアップしてユーザーに確認する
- パフォーマンスに影響するプラグイン（nvm 等）は避ける

### Claude Code インストール

- DevContainer Feature 方式を使用する（Dockerfile では直接インストールしない）
- Dockerfileとdevcontainer.jsonでの役割の分離、バージョン管理の容易さ、VS Code 拡張の自動追加などを考慮して現段階でのベストプラクティスな方式を採用する

### 開発ツール

- 必要そうな追加開発ツールについてはユーザー側に追加するかどうか確認する

### コミットメッセージ

- Anthropic 社の Co-Authored-By やその他 Anthropic 関連のコメントをコミットメッセージに含めない
- コミットメッセージは概要（2-3行程度）のみ簡潔に記述する

### 設定ファイルのドキュメント

- settings.json にコメントは入れない（JSON はコメント非対応、JSONC も Claude Code 未サポート）
- CLAUDE.md にはトークン消費を考慮し、設定方針のみを簡潔に記述する。設定値の詳細は記載しない

### 認証設定について

下記はホストOSで設定が必要だった場合の例であり、作業実行時に最新の情報を取得して最適な方法を提案するようにする事

#### プライマリ認証: claude login（TUI + 非インタラクティブ両対応）

ステップ1: ブラウザ認証
claude login

ブラウザが開きます。ログイン後、~/.claude/.credentials.json が自動生成されます

ステップ2: スコープの確認
cat ~/.claude/.credentials.json | jq '.claudeAiOauth.scopes'

user:inference と user:profile が含まれていれば成功です

ステップ3: load-secrets.sh のテスト
cd /Users/satoshi/mydir/dev/repo/ai/claude-code/dev-env/devcontainer-setup
.devcontainer/load-secrets.sh

✓ .credentials.json を Base64 エンコードしました と表示されれば準備完了です

#### フォールバック: setup-token（非インタラクティブ専用）

claude -p のみ使用する場合のオプション。TUI では認証エラーになります（user:profile スコープ不足）。

ステップ1: claude setup-token（表示されたトークンをコピー）
ステップ2: security add-generic-password -a “$USER” -s “CLAUDE_CODE_OAUTH_TOKEN” -w “<トークン>” -U
