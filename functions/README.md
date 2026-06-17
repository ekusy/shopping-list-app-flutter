# functions/ — Cloud Functions (TypeScript)

shopping-list-app-flutter のサーバーサイド。**Issue #37（AI 提案 Phase 0）** で新設。
このリポジトリで初めて入るバックエンドコードであり、以降の機能（履歴アーカイブ、
週次 AI 提案、FCM 通知など）の起点となる。

## スタック

- **TypeScript** / **firebase-functions v2** SDK / **Node.js 22**
- リージョン: `asia-northeast1`（`setGlobalOptions` で集約設定）
- テスト: **vitest**（TS をそのまま実行）
- lint: **eslint** flat config + typescript-eslint

開発・CI は Docker で統一（ホストに Node を入れない）。コマンドはリポジトリ直下の
`CLAUDE.md`「### Cloud Functions」を参照。

```bash
docker compose run --rm functions npm ci
docker compose run --rm functions npm run build   # tsc → lib/
docker compose run --rm functions npm run lint
docker compose run --rm functions npm test
```

## 設計原則: bootstrap / trigger wrapper / lib / data の分離

将来 Dart Cloud Functions が GA（現状は HTTP/callable のみで Firestore トリガー・
`onSchedule` がデプロイ不可）になった際の移植コストを抑えるため、最初からレイヤを分ける（Issue #52）。

```
src/
├── bootstrap.ts    # setGlobalOptions + initializeApp（副作用のみ）。
│                   #   index.ts が最初に import することで、トリガー定義モジュール
│                   #   より前に必ず評価されることを保証する。
├── index.ts        # トリガーの re-export のみ。先頭で `import "./bootstrap"`。
│                   #   ロジック・I/O は持たない。
├── lib/            # 純粋ロジック層: firebase-functions / firebase-admin / @google/genai に依存しない。
│   ├── health.ts          #   → 単体テスト可能・将来 Dart へ移植可能
│   ├── health.test.ts
│   ├── history.ts         # 購買履歴イベント判定・サマリー集約の純粋ロジック
│   ├── history.test.ts
│   ├── name_key.ts         # 商品名正規化・nameKey 導出
│   ├── name_key.test.ts
│   ├── suggestions.ts      # 週次AI提案: weekId算出・skip判定・入力圧縮・
│   │                        #   プロンプト組立・レスポンス検証/後処理
│   └── suggestions.test.ts
├── data/           # firebase-admin（Firestore / Storage）I/O 層。
│   ├── history_store.ts   # itemHistory / purchaseHistorySummaries の読み書き、
│   │                       #   グループ存在確認、recursiveDelete
│   ├── storage_store.ts   # Storage I/O: deleteItemImage / deleteGroupImages（#38）
│   ├── suggestions_store.ts # suggestions 入出力・system/config キルスイッチ読み取り
│   └── gemini_client.ts   # @google/genai（Vertex backend）呼び出し（I/O層に隔離）
└── triggers/       # 薄い trigger wrapper。HTTP/Firestore/Scheduler イベント・ログのみ。
    ├── health.ts          # health
    ├── items.ts           # onItemUpdated / onItemDeleted
    ├── groups.ts          # onGroupDeleted
    └── suggestions.ts     # weeklySuggestions（onSchedule）
```

- **`src/lib/` は `firebase-functions` / `firebase-admin` を import しない。** 判定・計算ロジックはここに置く。
- **`src/data/` は `firebase-admin` への依存をこの層に閉じる。** Firestore の読み書きはここに集約する。
- **`src/triggers/` は薄く保つ**: フレームワーク固有の関心事（イベント形状・ログ）のみを扱い、
  判定・計算は `src/lib/` を、I/O は `src/data/` を呼び出すだけにする。
- 新しいトリガーを追加する際もこの 3 層分離を必ず守る。
- `index.ts` のトリガー export 名は **デプロイ済み関数名と完全一致**させること（リネームは
  delete + recreate を招くため避ける）。

## 現状（デプロイ済みの関数）

- `health`（`onRequest`）— ツールチェーン疎通確認用のヘルスチェック。
- `onItemUpdated`（`onDocumentUpdated('groups/{groupId}/items/{itemId}')`）—
  `status` が `active` → `purchased` に遷移した際に `itemHistory` へ `purchased`
  イベントを記録し、`purchaseHistorySummaries/{nameKey}` をトランザクションで更新。
  直近 1 時間以内に同一アイテムの `purchased` イベントがある場合はスキップ
  （トグルノイズ対策）。
- `onItemDeleted`（`onDocumentDeleted('groups/{groupId}/items/{itemId}')`）—
  アイテム削除時に削除時点のスナップショットから `deleted` イベントを記録。
  `statusAtDeletion === 'active'` の場合のみ `deletedWithoutPurchaseCount` を更新。
  **グループ解散ガード**: 記録前に親グループ文書 `groups/{groupId}` の存在を確認し、
  存在しない場合（グループ解散による `onGroupDeleted` の recursiveDelete 経由の削除）
  は記録をスキップする（PR3）。
  **Storage クリーンアップ（#38）**: 履歴記録とは独立に、Storage のアイテム画像を
  best-effort で削除する（`storage_store.deleteItemImage`）。
- `onGroupDeleted`（`onDocumentDeleted('groups/{groupId}', { timeoutSeconds: 300,
  memory: '512MiB' })`）— グループ解散時に `recursiveDelete` でグループ配下の
  全サブコレクション（`items` / `tags` / `itemHistory` / `purchaseHistorySummaries` /
  旧 `lists` とその nested サブコレクションを含む）を再帰削除（PR3）。
- `weeklySuggestions`（`onSchedule('every saturday 08:00', { timeZone: 'Asia/Tokyo',
  timeoutSeconds: 540, memory: '512MiB' })`）— グループごとにアクティブアイテム /
  直近8週間の `itemHistory` / `purchaseHistorySummaries` 上位件を集計し、Vertex AI
  Gemini（`@google/genai`, structured output）で「購入忘れの提案」「次期購入候補」を
  生成して `groups/{groupId}/suggestions/{weekId}` に保存する（Issue #40 Phase 1）。
  `system/config.suggestionsEnabled` をキルスイッチとして確認し、`false` の場合は
  Gemini を呼ばず即終了する（未設定時は既定で有効）。
- スキーマ・設計の詳細は `docs/ドラフト/AI提案機能/01-履歴データ設計.md` /
  `docs/ドラフト/AI提案機能/02-週次提案パイプライン設計.md` を参照。

## デプロイ状況・残作業

#37 Phase 0 / #40 Phase 1 / #38 はデプロイ済み（本番 `asia-northeast1`）。完了した事項:

- **TTL は `firestore.indexes.json` で一元管理**（#57）。`itemHistory.expiresAt` /
  `suggestions.expiresAt` の `ttl: true` を `fieldOverrides` に定義しデプロイ済み
  （retention 日数は Functions が書き込む `expiresAt` の値で決まる: 履歴 180 日 / 提案 90 日）。
  **gcloud / コンソールでの手動 TTL 設定は禁止**（field override 削除事故の原因。CLAUDE.md 参照）。
- #40 デプロイ前提（Functions SA への `roles/aiplatform.user` 付与・Vertex AI API 有効化・
  `@google/genai` 導入）は対応済み。
- 提案表示 UI（#41 `/suggestions`）実装済み。
- #38 商品画像の Storage クリーンアップトリガ（`onItemDeleted` / `onGroupDeleted`）デプロイ済み。

残作業:

- emulator 統合テスト（`onGroupDeleted` の recursiveDelete・`onItemDeleted` の
  グループ解散ガード・Gemini 呼び出しのモック統合）は未実施。純粋ロジックの vitest
  単体テストのみで担保している。
- `data/gemini_client.ts` の `MODEL_ID` は公開モデル ID・料金の変動に注意
  （Gemini 3.x Flash-Lite 系。2.5 系は 2026-10 廃止予定）。
- Phase 2: FCM 通知（未実装）。
