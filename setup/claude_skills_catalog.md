# Claude Code スキル・MCP カタログ

導入推奨ツールの一覧。詳細な手順は各 setup ファイルを参照してください。

| 記号 | 意味 |
|------|------|
| ✅ | 自動セットアップ可（`setup_claude.md`） |
| ⚠️ | 手動セットアップ必要（`setup_claude_manual.md`） |

---

## MCP サーバー

### Tier 0 — 基盤（Flutter / Dart 固有）

| ツール | 用途 | APIキー | Node.js | 自動化 | 配布元 |
|--------|------|:-------:|:-------:|:------:|--------|
| **Dart MCP Server** | 静的解析・テスト実行・pub.dev 検索・コード整形・シンボル解決 | — | — | ✅ | [flutter.dev](https://docs.flutter.dev/ai/mcp-server) |

### Tier 1 — 汎用・即効性あり

| ツール | 用途 | APIキー | Node.js | 自動化 | 配布元 |
|--------|------|:-------:|:-------:|:------:|--------|
| **Context7** | 任意ライブラリのドキュメントをリアルタイム参照。バージョン差異・新 API 対応 | — | — | ✅ | [context7.com](https://context7.com) |
| **Sequential Thinking** | 複雑な設計・デバッグ・要件定義を段階的推論で解決 | — | ✓ | ✅ | [MCP 公式](https://github.com/modelcontextprotocol/servers) |

### Tier 2 — プロジェクト構成次第

| ツール | 用途 | APIキー | Node.js | 自動化 | 配布元 |
|--------|------|:-------:|:-------:|:------:|--------|
| **Firebase MCP** | Firestore・Auth・Crashlytics・FCM を AI から操作 | — (login) | ✓ | ⚠️ | [firebase.google.com](https://firebase.google.com/docs/ai-assistance/mcp-server) |
| **Figma MCP** | デザイン → Flutter ウィジェット変換。デザイントークン・コンポーネント参照 | ✓ | ✓ | ⚠️ | [figma.com](https://help.figma.com/hc/en-us/articles/32132100833559) |
| **Playwright MCP** | ブラウザ自動化・E2E テスト（Flutter Web 向け） | — | ✓ | ✅ | [Microsoft](https://github.com/microsoft/playwright-mcp) |

### Tier 3 — チーム・プロセス連携

| ツール | 用途 | APIキー | Node.js | 自動化 | 配布元 |
|--------|------|:-------:|:-------:|:------:|--------|
| **Notion MCP** | 要件定義書・仕様書の参照・更新 | ✓ (OAuth) | — | ⚠️ | [notion.so](https://www.notion.so/product/mcp) |
| **Git MCP** | ローカルリポジトリのコミット・差分・ログ・blame 操作 | — | — | ✅ | [MCP 公式](https://github.com/modelcontextprotocol/servers) |

> **注記**: GitHub MCP（リモートリポジトリ操作）はこの Claude Code 環境で利用可能。Git MCP はローカル操作が対象。

---

## スキルリポジトリ

| ツール | 規模 | 主な用途 | APIキー | 自動化 | 配布元 |
|--------|------|---------|:-------:|:------:|--------|
| **dart-lang/skills + flutter/skills** | 公式スキル | 自動テスト・静的解析・UI/UX | — | ✅ | [flutter.dev](https://docs.flutter.dev/ai/agent-skills) |
| **ECC — Everything Claude Code** | 60 エージェント・232 スキル・75 コマンド | 要件定義・アーキテクチャ・CI/CD・テスト・デバッグ・Git（全領域） | — | ✅ | [affaan-m/ECC](https://github.com/affaan-m/everything-claude-code) |
| **alirezarezvani/claude-skills** | 338 スキル・16 ドメイン | アーキテクチャ・仕様作成・ドキュメント・CI/CD・UI/UX・デザイン（全領域） | — | ✅ | [alirezarezvani](https://github.com/alirezarezvani/claude-skills) |

---

## キーワード × ツール対応表

| キーワード | 対応ツール |
|-----------|-----------|
| 要件定義 | Sequential Thinking / ECC `/plan` / alirezarezvani / Notion |
| 仕様作成 | Context7 / Notion / alirezarezvani `runbook-generator` |
| ドキュメント | Context7 / Notion / ECC `/changelog` / alirezarezvani |
| アーキテクチャ | Sequential Thinking / ECC / alirezarezvani `senior-architect` |
| 静的解析 | Dart MCP / ECC AgentShield |
| 自動テスト | Dart MCP / Playwright / dart-lang/skills / alirezarezvani `playwright-pro` |
| CI/CD | ECC `/build-fix` / alirezarezvani `ci-cd-builder` |
| デバッグ | Dart MCP / Sequential Thinking / ECC / alirezarezvani `incident-commander` |
| Git | Git MCP / GitHub MCP（既利用可） / alirezarezvani `git-worktree-manager` |
| デザイン | Figma MCP / alirezarezvani `ui-designer` |
| UI/UX | Figma MCP / Playwright / flutter/skills / alirezarezvani |

---

## セットアップファイルの構成

| ファイル | 内容 |
|---------|------|
| `setup/setup.sh` | Flutter・VS Code・Node.js の OS レベルセットアップ |
| `setup/setup_claude.md` | Claude Code で「セットアップして」で実行する自動手順（✅ のみ） |
| `setup/setup_claude_manual.md` | APIキー・ブラウザ操作が必要な手動手順（⚠️ のみ） |
| `setup/claude_skills_catalog.md` | このファイル — ツール一覧・再確認用 |
| `setup/claude_skills_catalog.html` | ブラウザで見られるカタログ（フィルター機能付き） |
