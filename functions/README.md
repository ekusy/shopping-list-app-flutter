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
├── lib/            # 純粋ロジック層: firebase-functions / firebase-admin に依存しない。
│   ├── health.ts          #   → 単体テスト可能・将来 Dart へ移植可能
│   ├── health.test.ts
│   ├── history.ts         # 購買履歴イベント判定・サマリー集約の純粋ロジック
│   ├── history.test.ts
│   ├── name_key.ts         # 商品名正規化・nameKey 導出
│   └── name_key.test.ts
├── data/           # firebase-admin（Firestore）I/O 層。
│   └── history_store.ts   # itemHistory / purchaseHistorySummaries の読み書き、
│                           #   グループ存在確認、recursiveDelete
└── triggers/       # 薄い trigger wrapper。HTTP/Firestore イベント・ログのみ。
    ├── health.ts          # health
    ├── items.ts           # onItemUpdated / onItemDeleted
    └── groups.ts          # onGroupDeleted
```

- **`src/lib/` は `firebase-functions` / `firebase-admin` を import しない。** 判定・計算ロジックはここに置く。
- **`src/data/` は `firebase-admin` への依存をこの層に閉じる。** Firestore の読み書きはここに集約する。
- **`src/triggers/` は薄く保つ**: フレームワーク固有の関心事（イベント形状・ログ）のみを扱い、
  判定・計算は `src/lib/` を、I/O は `src/data/` を呼び出すだけにする。
- 新しいトリガーを追加する際もこの 3 層分離を必ず守る。
- `index.ts` のトリガー export 名は **デプロイ済み関数名と完全一致**させること（リネームは
  delete + recreate を招くため避ける）。

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
  **グループ解散ガード**: 記録前に親グループ文書 `groups/{groupId}` の存在を確認し、
  存在しない場合（グループ解散による `onGroupDeleted` の recursiveDelete 経由の削除）
  は記録をスキップする（PR3）。
- `onGroupDeleted`（`onDocumentDeleted('groups/{groupId}', { timeoutSeconds: 300,
  memory: '512MiB' })`）— グループ解散時に `recursiveDelete` でグループ配下の
  全サブコレクション（`items` / `tags` / `itemHistory` / `purchaseHistorySummaries` /
  旧 `lists` とその nested サブコレクションを含む）を再帰削除（PR3）。
- スキーマ・設計の詳細は `docs/ドラフト/AI提案機能/01-履歴データ設計.md` を参照。

## 今後（同 Issue の後続 PR）

- PR3 完了。残りは以下のみ:
  - 手動手順: Firestore ネイティブ TTL ポリシー（`itemHistory.expiresAt`、180日）設定。
  - 週次 AI 提案パイプライン（`purchaseHistorySummaries` を入力に Gemini を活用）。
  - emulator 統合テスト（`onGroupDeleted` の recursiveDelete・`onItemDeleted` の
    グループ解散ガードはエミュレータでの結合確認が望ましいが、本 PR では未実施。
    純粋ロジックの vitest 単体テストのみで担保）。
