# Claude Code セットアップ手順

このファイルは Claude Code 上で「セットアップして」と指示することで
以下の手順を自動実行するためのガイドです。

> **API キーやブラウザ操作が必要な項目は自動化できません。**
> 該当ツール（Firebase / Notion / Figma）は `setup_claude_manual.md` を参照し、手動で設定してください。

---

## 前提条件

`setup/setup.sh` が完了していること:

- Dart 3.9 以上
- Node.js（npx が使えること）
- git

---

## 「セットアップして」で実行する手順

### ステップ 1: 前提条件チェック

```bash
dart --version
node --version
git --version
```

いずれかが見つからない場合は中断し、ユーザーに案内してください:

| コマンド | 不足時の対処 |
|---------|------------|
| `dart` | `setup/setup_flutter.sh` を再実行 |
| `node` | `setup/setup_node.sh` を再実行 |
| `git`  | `sudo apt-get install -y git` |

---

### ステップ 2: Dart / Flutter Agent Skills

プロジェクトルートで実行してください:

```bash
npx --yes skills add dart-lang/skills --skill '*' --agent universal
npx --yes skills add flutter/skills   --skill '*' --agent universal
```

確認:

```bash
ls .agents/skills/
```

---

### ステップ 3: Dart MCP サーバー

```bash
claude mcp add --scope project --transport stdio dart -- dart mcp-server
```

確認:

```bash
claude mcp list | grep dart
```

---

### ステップ 4: Context7 MCP（ドキュメントリアルタイム参照）

APIキー不要。pub.dev・Flutter など任意ライブラリのドキュメントを参照できます。

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
```

---

### ステップ 5: Sequential Thinking MCP（段階的推論）

APIキー不要。複雑な設計・デバッグ・要件定義に有効です。

```bash
claude mcp add sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking
```

---

### ステップ 6: Playwright MCP（ブラウザ自動化・E2E テスト）

APIキー不要。Flutter Web の E2E テストや UI 操作の自動化に使います。

```bash
claude mcp add playwright npx -- @playwright/mcp@latest
```

---

### ステップ 7: Git MCP（ローカルリポジトリ操作）

APIキー不要。コミット・差分・ログ・blame などをAIから直接操作できます。

```bash
claude mcp add git uvx -- mcp-server-git
```

---

### ステップ 8: ECC — Everything Claude Code のインストール

**まずユーザーにインストール先を確認してください:**

> ECC をどのスコープにインストールしますか？
> - **ユーザーレベル** (`~/.claude/`) … 全プロジェクトで利用可能
> - **プロジェクトレベル** (`.claude/`) … このリポジトリのみ有効

#### ユーザーレベルの場合

```bash
git clone --depth=1 https://github.com/affaan-m/everything-claude-code.git /tmp/ecc
mkdir -p ~/.claude/agents ~/.claude/commands ~/.claude/skills ~/.claude/rules
cp /tmp/ecc/agents/*.md     ~/.claude/agents/   2>/dev/null || true
cp /tmp/ecc/commands/*.md   ~/.claude/commands/ 2>/dev/null || true
cp -r /tmp/ecc/skills/*     ~/.claude/skills/   2>/dev/null || true
cp -r /tmp/ecc/rules/common ~/.claude/rules/    2>/dev/null || true
rm -rf /tmp/ecc
```

#### プロジェクトレベルの場合

```bash
git clone --depth=1 https://github.com/affaan-m/everything-claude-code.git /tmp/ecc
mkdir -p .claude/agents .claude/commands .claude/skills .claude/rules
cp /tmp/ecc/agents/*.md     .claude/agents/   2>/dev/null || true
cp /tmp/ecc/commands/*.md   .claude/commands/ 2>/dev/null || true
cp -r /tmp/ecc/skills/*     .claude/skills/   2>/dev/null || true
cp -r /tmp/ecc/rules/common .claude/rules/    2>/dev/null || true
rm -rf /tmp/ecc
```

---

### ステップ 9: alirezarezvani/claude-skills のインストール

338 スキル・16 ドメイン対応。ステップ 8 と同じスコープに揃えることを推奨します。

#### ユーザーレベルの場合

```bash
git clone --depth=1 https://github.com/alirezarezvani/claude-skills.git /tmp/cskills
mkdir -p ~/.claude/skills
cp -r /tmp/cskills/skills/* ~/.claude/skills/ 2>/dev/null || true
rm -rf /tmp/cskills
```

#### プロジェクトレベルの場合

```bash
git clone --depth=1 https://github.com/alirezarezvani/claude-skills.git /tmp/cskills
mkdir -p .claude/skills
cp -r /tmp/cskills/skills/* .claude/skills/ 2>/dev/null || true
rm -rf /tmp/cskills
```

---

### ステップ 10: 手動セットアップ項目の通知 🔔

以下のツールは **API キーまたはブラウザ操作** が必要なため、自動化できません。
**`setup/setup_claude_manual.md`** を参照して手動でセットアップするようユーザーに案内してください:

| ツール | 必要な操作 |
|--------|-----------|
| **Firebase MCP** | `firebase login`（ブラウザ認証） → `claude mcp add` |
| **Notion MCP** | OAuth ブラウザ認証（`claude mcp add` 後に `/mcp` で認証） |
| **Figma MCP** | Figma アクセストークンの発行と設定 |

---

### ステップ 11: 完了確認

すべてのステップ終了後、以下を実行して状態を確認してください:

```bash
claude mcp list
ls .agents/skills/ 2>/dev/null || echo "(プロジェクトスキルなし)"
```

以下をユーザーに報告してください:

- 登録された MCP サーバー一覧（`claude mcp list` 出力）
- `.agents/skills/` のスキル一覧
- ECC・alirezarezvani スキルのインストール先（ユーザー / プロジェクト）
- 手動セットアップが残っているツールの案内

---

## 導入ツール一覧

詳細は `setup/claude_skills_catalog.md` を参照してください。

| ツール | 種別 | 自動化 |
|--------|------|--------|
| Dart MCP Server | MCP | ✅ |
| Context7 | MCP | ✅ |
| Sequential Thinking | MCP | ✅ |
| Playwright MCP | MCP | ✅ |
| Git MCP | MCP | ✅ |
| Firebase MCP | MCP | ⚠️ 手動（setup_claude_manual.md） |
| Notion MCP | MCP | ⚠️ 手動（setup_claude_manual.md） |
| Figma MCP | MCP | ⚠️ 手動（setup_claude_manual.md） |
| ECC | スキルリポジトリ | ✅ |
| alirezarezvani/claude-skills | スキルリポジトリ | ✅ |
| dart-lang/skills + flutter/skills | スキルリポジトリ | ✅ |

---

## トラブルシューティング

**MCP が重複登録された:**
```bash
claude mcp remove <name>
# 再登録してください
```

**スキルが展開されない（npx skills add が失敗）:**
```bash
node --version   # Node.js が入っているか確認
npx --version
```

**git clone が失敗する:**
```bash
git --version
curl -I https://github.com  # ネットワーク確認
```
