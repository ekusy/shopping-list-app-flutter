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

## 設計原則: trigger wrapper とロジックの分離

将来 Dart Cloud Functions が GA（現状は HTTP/callable のみで Firestore トリガー・
`onSchedule` がデプロイ不可）になった際の移植コストを抑えるため、最初からレイヤを分ける。

```
src/
├── index.ts        # trigger wrapper（薄く保つ）: HTTP/Firestore イベント・ログのみ。
│                   #   ここだけが firebase-functions に依存する。
└── lib/            # 純粋ロジック層: firebase-functions に依存しない。
    ├── health.ts          #   → 単体テスト可能・将来 Dart へ移植可能
    ├── health.test.ts
    ├── history.ts         # 購買履歴イベント判定・サマリー集約の純粋ロジック
    ├── history.test.ts
    ├── name_key.ts         # 商品名正規化・nameKey 導出
    └── name_key.test.ts
```

- **`src/lib/` は `firebase-functions` を import しない。** ビジネスロジックはここに置き、
  trigger からは呼び出すだけにする。
- 新しいトリガーを追加する際もこの分離を必ず守る（Firestore I/O はトリガー側、
  判定・計算は `src/lib/` の純粋関数）。

## 現状（PR1: 足場 + PR2: 履歴捕捉コア）

- `health`（`onRequest`）— ツールチェーン疎通確認用のヘルスチェック。
- `onItemUpdated`（`onDocumentUpdated('groups/{groupId}/items/{itemId}')`）—
  `status` が `active` → `purchased` に遷移した際に `itemHistory` へ `purchased`
  イベントを記録し、`purchaseHistorySummaries/{nameKey}` をトランザクションで更新。
  直近 1 時間以内に同一アイテムの `purchased` イベントがある場合はスキップ
  （トグルノイズ対策）。
- `onItemDeleted`（`onDocumentDeleted('groups/{groupId}/items/{itemId}')`）—
  アイテム削除時に削除時点のスナップショットから `deleted` イベントを記録。
  `statusAtDeletion === 'active'` の場合のみ `deletedWithoutPurchaseCount` を更新。
- スキーマ・設計の詳細は `docs/ドラフト/AI提案機能/01-履歴データ設計.md` を参照。

## 今後（同 Issue の後続 PR）

- PR3: `onDocumentDeleted('groups/{groupId}')` によるサブコレクション再帰削除
  （`itemHistory` / `purchaseHistorySummaries` を含む）。
- 手動手順: Firestore ネイティブ TTL ポリシー（`itemHistory.expiresAt`、180日）設定。
- 週次 AI 提案パイプライン（`purchaseHistorySummaries` を入力に Gemini を活用）。
