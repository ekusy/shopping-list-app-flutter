# Claude Code 手動セットアップ手順

API キーまたはブラウザ操作が必要なため、`setup_claude.md` の自動手順では実行できないツールの設定手順です。

---

## Firebase MCP

### 前提条件

- Node.js がインストール済みであること（`node --version` で確認）
- Firebase プロジェクトが作成済みであること

### 手順

**1. Firebase CLI のログイン（ブラウザが開きます）**

```bash
npx firebase-tools@latest login
```

ブラウザで Google アカウントを選択して認証してください。

認証後、以下でログイン状態を確認:

```bash
npx firebase-tools@latest projects:list
```

**2. MCP サーバーの登録**

```bash
claude mcp add firebase npx -- -y firebase-tools@latest mcp
```

**3. 確認**

```bash
claude mcp list | grep firebase
```

`firebase: npx -y firebase-tools@latest mcp` が表示されれば成功です。

### 利用可能になる機能

- Firestore のクエリ・読み書き
- Firebase Authentication のユーザー管理
- Firebase Crashlytics のクラッシュログ参照
- Firebase Cloud Messaging の送信
- セキュリティルールの検証・取得
- Firebase プロジェクトの作成・管理

---

## Notion MCP

### 前提条件

- Notion のアカウントがあること
- Claude Code が起動していること

### 手順

**1. MCP サーバーの登録**

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

**2. Claude Code 内で OAuth 認証**

Claude Code のセッション内で以下のコマンドを入力してください:

```
/mcp
```

一覧に `notion` が表示されたら選択し、ブラウザで Notion アカウントにログインして認証を完了させてください。

**3. Notion インテグレーションの権限設定**

認証後、Notion の設定画面でアクセスを許可するページ・データベースを選択してください:

1. Notion を開く → 左サイドバー → `設定とメンバー`
2. `インテグレーション` → Claude Code のインテグレーションを確認
3. アクセスさせたいページの `…` メニュー → `インテグレーションに接続`

**4. 確認**

```bash
claude mcp list | grep notion
```

### 利用可能になる機能

- 要件定義書・仕様書の参照・更新
- データベースの読み書き
- ページの作成・編集

---

## Figma MCP

### 前提条件

- Figma のアカウントがあること（Professional 以上推奨）
- アクセストークンを発行できる権限があること

### 手順

**1. Figma アクセストークンの発行**

1. https://www.figma.com/settings を開く
2. `アカウント` → `アクセストークン` セクションへ移動
3. `新しいトークンを生成` をクリック
4. トークン名を入力（例: `claude-code`）し、スコープを選択:
   - `File content` → 読み取り
   - `Dev resources` → 読み取り（任意）
5. 発行されたトークンをコピー（**一度しか表示されません**）

**2. MCP サーバーの登録**

```bash
FIGMA_API_TOKEN=<発行したトークン> claude mcp add figma npx -- -y figma-mcp-server
```

または、トークンを環境変数に設定してから実行:

```bash
export FIGMA_API_TOKEN=<発行したトークン>
claude mcp add figma npx -- -y figma-mcp-server
```

**3. 確認**

```bash
claude mcp list | grep figma
```

**4. 動作確認**

Claude Code で以下のように指示して動作確認してください:

```
Figma ファイル <Figma のURL> のコンポーネント一覧を取得して
```

### 利用可能になる機能

- Figma デザインのコンポーネント・デザイントークン参照
- オートレイアウト・バリアントの読み取り
- デザイン → Flutter ウィジェットコードの生成

### トークンのセキュリティ

- トークンは `.bashrc` / `.zshrc` などに保存しないことを推奨
- シェルセッションのみ有効な環境変数として管理するか、パスワードマネージャーで管理してください
- トークンが漏洩した場合は Figma の設定画面で即座に失効させてください

---

## セットアップ完了後の確認

すべての手動セットアップ完了後に実行してください:

```bash
claude mcp list
```

以下がすべて表示されれば完了です:

```
dart          : ...  ✓ Connected
context7      : ...  ✓ Connected
sequential-thinking : ...  ✓ Connected
playwright    : ...  ✓ Connected
git           : ...  ✓ Connected
firebase      : ...  ✓ Connected
notion        : ...  ✓ Connected
figma         : ...  ✓ Connected
```
