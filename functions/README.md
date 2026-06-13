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
    ├── health.ts        #   → 単体テスト可能・将来 Dart へ移植可能
    └── health.test.ts
```

- **`src/lib/` は `firebase-functions` を import しない。** ビジネスロジックはここに置き、
  trigger からは呼び出すだけにする。
- 新しいトリガー（PR2 の `onDocumentUpdated` / `onDocumentDeleted` 等）を追加する際も
  この分離を必ず守る。

## 現状（PR1: 足場）

- `health`（`onRequest`）— ツールチェーン疎通確認用のヘルスチェック。

## 今後（同 Issue の後続 PR）

- PR2: `onItemUpdated` / `onItemDeleted` による購買履歴アーカイブ + サマリー集約、
  Security Rules、`firestore.indexes.json` への実インデックス定義追加
  （PR1 では空スキャフォルドのみ）。
- PR3: `onDocumentDeleted('groups/{groupId}')` によるサブコレクション再帰削除。
- 手動手順: Firestore ネイティブ TTL ポリシー設定。
