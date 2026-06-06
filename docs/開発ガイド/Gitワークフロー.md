# Git ワークフロー

本リポジトリのブランチ運用と CI/CD の方針を定める（Issue #25）。

> **ステータス**: 段階導入中。`develop` ブランチの作成とブランチ保護ルールの適用は
> リポジトリオーナーによる手動設定が必要（本書「手動設定手順」参照）。設定完了までは
> 従来どおり `main` ベースの運用（feature → main への PR）も許容する。

## 1. ブランチモデル

```
main ─────────●────────────────●───────────   デプロイ用（モバイルビルドのトリガ）
               ▲                ▲
               │ PR (squ/merge) │ PR
develop ──●────┴───●────────●───┴──────────    開発用（Firebase Hosting デプロイのトリガ）
           ▲       ▲        ▲
           │PR     │PR      │PR
feature ───┴─ ... ─┴─ ... ──┴─                 実装用（実作業はここ）
```

| ブランチ | 役割 | 直接 push | 派生元 | マージ先 |
|---|---|---|---|---|
| `main` | デプロイ用（モバイルビルド起点） | **禁止** | — | — |
| `develop` | 開発用（Web 先行評価デプロイ起点） | **禁止** | `main` | `main`（PR） |
| `feature/*` 等 | 実装用 | 可 | `develop` | `develop`（PR） |

- `main` から新規ブランチを作成しない（`develop` を唯一の派生元とする）。
- 実作業は必ず `feature/*`（`fix/*`, `chore/*`, `docs/*`, `perf/*` 等、用途で接頭辞を使い分け）で行う。
- `main` への新規コミットは必ず `develop` からの PR を経由する。

### 命名規則

`feat:` `fix:` `refactor:` `test:` `chore:` `docs:` `perf:` に対応する接頭辞をブランチ名にも用いる。
例: `feature/add-item-sort`, `fix/24-first-login-list`, `chore/25-git-workflow`。

## 2. PR フロー

1. `develop` を最新化し、そこから作業ブランチを作成する。
2. 実装・テスト・ドキュメント更新を行う。
3. `develop` を base に PR を作成する（テンプレートは CLAUDE.md / issue-flow 参照）。
4. **CI（test）が全件 OK** かつレビュー承認後にマージする。
5. リリース時は `develop` → `main` の PR を作成し、CI 通過後にマージする。

### マージ条件（必須）

- `test` ジョブ（`flutter analyze` + `flutter test`）が成功していること。
- レビュー承認（ブランチ保護で必須化）。

## 3. CI/CD

GitHub Actions で以下を自動化する（`.github/workflows/`）。

| ワークフロー | トリガ | 内容 |
|---|---|---|
| `test.yml` | 全 PR / `develop`・`main` への push | `flutter analyze` + `flutter test`。**マージ前ゲート**。 |
| `deploy-web.yml` | `develop` への push | `flutter build web` → Firebase Hosting デプロイ（Web 先行評価）。 |
| `build-mobile.yml` | `main` への push | Android ビルド（成果物アーティファクト）。iOS は CodeMagic 連携予定（プレースホルダ）。 |

### 補足・未確定事項（TODO）

- **Android リリース署名**: 現状は未署名ビルド（スモーク）。署名鍵（keystore）を Secrets に
  登録し、`build appbundle --release` で AAB を生成する手順は別途整備（`docs/ANDROID_DOCKER.md`）。
- **iOS**: macOS ランナーが必要なため GitHub Actions では実行しない。**CodeMagic** で
  `main` 連動のビルド/配布を設定予定。設定後、本書とワークフローに連携内容を追記する。
- **Firebase Hosting のデプロイ先**: Web 版は先行評価用途のため `develop` を live チャンネルに
  デプロイする。Secrets `FIREBASE_SERVICE_ACCOUNT` / projectId `household-shopping-list-f7c12` を使用。

## 4. 手動設定手順（リポジトリオーナー）

コードでは完結しない。GitHub のリポジトリ設定で以下を行うこと。

1. **`develop` ブランチの作成**
   ```bash
   git checkout main && git pull
   git checkout -b develop && git push -u origin develop
   ```
2. **デフォルトブランチを `develop` に変更**（Settings → General → Default branch）。
   - 日常の PR が既定で `develop` を base に向くようにする。
3. **ブランチ保護ルール**（Settings → Branches → Add rule）を `main` と `develop` に設定:
   - Require a pull request before merging（直接 push 禁止）
   - Require status checks to pass before merging → `test` を必須チェックに指定
   - Require approvals（レビュー必須）
   - （`main`）Restrict who can push / linear history など必要に応じて
4. **Secrets の確認**（Settings → Secrets and variables → Actions）:
   - `FIREBASE_SERVICE_ACCOUNT`（Firebase Hosting デプロイ用サービスアカウント JSON）
5. （任意）CLAUDE.md / `.claude/skills/issue-flow` のブランチ規約を本書（`develop` ベース）に
   合わせて更新する。破壊的変更のため、上記 1〜3 の適用完了後に行う。

## 関連

- `.github/workflows/`（実体）
- `docs/DEPLOYMENT.md` / `docs/ANDROID_DOCKER.md`
- CLAUDE.md「ブランチ・マージ規約」
