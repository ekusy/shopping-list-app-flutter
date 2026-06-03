---
name: issue-flow
description: Use this skill when the user wants to start working on a GitHub Issue. Guides the full flow: feature branch creation → implementation → test/lint verification → PR creation → user review. Enforces branch and PR conventions defined in CLAUDE.md.
user-invocable: true
---

GitHub Issue に着手する際の標準フローを実行するスキル。
以下のステップを順番に進める。ユーザーから Issue 番号・タイトル・作業内容の指示を受けてから開始する。

---

## Step 1 — Issue の内容を確認する

`gh issue view <issue番号>` で Issue の本文・ラベル・担当者を取得し、
実装方針・影響範囲を把握する。不明点があればユーザーに確認する。

---

## Step 2 — feature ブランチを作成する

**ルール:**
- ベースは必ず最新の `main` ブランチ
- 命名規則: `feature/<slug>`, `fix/<slug>`, `chore/<slug>` など（CLAUDE.md 参照）
- `main` への直接コミット・プッシュは禁止

```bash
git checkout main
git pull origin main
git checkout -b feature/<slug>
```

ブランチ作成後、ユーザーに通知してから実装へ進む。

---

## Step 3 — 実装する

CLAUDE.md のアーキテクチャ・設計ドキュメント（`docs/内部設計/`）を参照しながら実装する。
エラーハンドリングは `AppError` に統一し、Firebase 固有例外は `FirebaseErrorConverter` 経由で変換する。

---

## Step 4 — テスト・ドキュメントを整備する

PR 作成前に以下を確認・実施する:

1. **単体テスト** — 対応内容をカバーするテストを追加・修正する
   - ウィジェットテストは `test/helpers/test_localization.dart` の `pumpLocalized` / `setUpTestLocalization` を使う
2. **ドキュメント更新** — `docs/` 配下の関連ドキュメントを変更内容に合わせて更新する

---

## Step 5 — 静的解析・テストを全件 OK にする

以下のコマンドを実行し、**すべて成功すること**を確認してから次へ進む:

```bash
docker compose run --rm flutter flutter analyze
docker compose run --rm flutter dart format --output=none --set-exit-if-changed lib test
docker compose run --rm flutter flutter test
```

エラーがあれば修正してから再実行する。

---

## Step 6 — PR を作成する

`gh pr create` で PR を作成する。本文は以下のテンプレートを使う:

```markdown
## 対応内容
<!-- 何を変更したか・なぜ変更したかを記述 -->

## 対応内容詳細
<!-- 実装方針・設計上の判断・考慮した代替案などを記述 -->

## 影響範囲
<!-- 変更が影響するファイル・機能・画面 -->

## 確認項目
- [ ] flutter analyze が通る
- [ ] flutter test が通る
- [ ] 対象機能の動作確認済み
- [ ] 単体テストを追加・修正した
- [ ] 関連ドキュメント（docs/）を更新した

Closes #<issue番号>
```

PR URL をユーザーに通知する。

---

## Step 7 — ユーザーのレビューを受ける

PR 作成後はユーザーにレビューを依頼して待機する。
レビューで修正が発生した場合は以下を繰り返す:

1. 修正を実装する
2. **Step 4（テスト・ドキュメント整備）** を再確認する
3. **Step 5（静的解析・テスト）** を再実行して全件 OK を確認する
4. 修正をコミット・プッシュする（同一 PR に追加される）

---

## 注意事項

- コミットメッセージは CLAUDE.md の規約（`feat:`, `fix:`, `refactor:` 等）に従う
- `google-services.json` / `GoogleService-Info.plist` は絶対にコミットしない
- 作業完了まで `main` への直接プッシュは行わない
