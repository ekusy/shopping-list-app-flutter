# 03. 商品画像の Firestore → Storage 移行（ドラフト）

アイテム写真の保存先を「Firestore ドキュメント内の Base64 データ URI」から
Firebase Storage に移行する。

## 1. 現状と問題

現在の実装（`lib/presentation/widgets/add_item_form.dart` / `item_edit_modal.dart`）:

- 写真は `ImageHelper.toDataUri(bytes)` で **Base64 データ URI 化され、
  アイテムドキュメントの `imageUrl` フィールドに直接保存**されている。
- Storage は既に導入済みだが用途は**アバターのみ**
  （`FirebaseStorageRepository.uploadAvatar` → `avatars/{uid}`）。

| 問題 | 内容 |
|---|---|
| ドキュメント上限 | Firestore の 1 ドキュメント上限は 1MiB。Base64 は元バイナリの約 1.33 倍に膨らみ、写真 1 枚で上限に迫る（現状どこまで縮小しているかは実装時に要確認） |
| 読み取り帯域とコスト | `watchItems` はコレクション全体を購読するため、**リストを開くたびに全アイテムの画像バイトが毎回流れる**。スナップショット更新のたびに再転送され、モバイル回線で重い |
| 他機能への波及 | よく買う物リスト（テンプレート複製）・履歴アーカイブで肥大ドキュメントのコピーが増える。**本移行は他機能より先に実施したい**（[README](./README.md) 依存図） |
| キャッシュ不能 | データ URI は HTTP キャッシュ・CDN が効かない。Storage のダウンロード URL なら端末・ブラウザキャッシュが効く |

## 2. 設計スケッチ

### 2.1 Storage パスとアップロードフロー

- パス: `groups/{groupId}/items/{itemId}.jpg`
  - アイテムと 1:1 で上書き可能なパスにする（複数枚対応（Pro 構想）が来たら
    `groups/{groupId}/items/{itemId}/{photoId}.jpg` へ拡張）。
- フロー: 端末でリサイズ・JPEG 圧縮（長辺 1024px / 品質 80 目安。アバターの既存処理に
  倣う）→ `putData` → `getDownloadURL()` を `imageUrl` に保存。
  - **`imageUrl` フィールドの意味は「データ URI」から「https URL」に変わるだけ**で、
    スキーマ変更は不要。表示側 `imageProviderFromUrl` は URL/データ URI の双方を
    すでに吸収しているはずなので、移行期間中の混在も表示は壊れない（実装時に要確認）。
- アイテム追加時はドキュメント ID が必要 → 「先に `add` で ID 確定 → 画像アップロード →
  `imageUrl` を update」の 2 段階にする（既存 `addItem` が ID を返すため対応可能）。

### 2.2 StorageRepository の拡張

```dart
abstract class StorageRepository {
  Future<String> uploadAvatar(String uid, Uint8List bytes);        // 既存
  Future<String> uploadItemImage(String groupId, String itemId, Uint8List bytes); // 追加
  Future<void> deleteItemImage(String groupId, String itemId);     // 追加
}
```

### 2.3 削除時の後始末

アイテム削除時に Storage 側の画像が孤児になる。選択肢:

| 案 | 内容 | 評価 |
|---|---|---|
| A（推奨） | AI 提案 Phase 0 で導入する `onDocumentDeleted` トリガー（`../AI提案機能/01-履歴データ設計.md`）に **Storage 削除を相乗り** | クライアント無変更・一括削除にも自動対応。Phase 0 と実装を共有 |
| B | クライアントが削除時に Storage も消す | `deletePurchasedItems` 等の一括系すべてに追加が必要。オフライン時に漏れる |

Phase 0 より先に本移行を実施する場合のみ、暫定で B + 定期清掃を許容する。

### 2.4 Storage Security Rules

現状 `storage.rules` がリポジトリに見当たらない（アバターがどう保護されているか
実装時に要確認・**要整備**）。商品画像の追加分:

```text
match /groups/{groupId}/items/{itemId}.jpg {
  allow read, write: if request.auth != null
    && firestore.exists(/databases/(default)/documents/groups/$(groupId))
    && request.auth.uid in
       firestore.get(/databases/(default)/documents/groups/$(groupId)).data.memberIds;
}
```

- write には `request.resource.size < 1 * 1024 * 1024` と
  `request.resource.contentType.matches('image/.*')` の制約も付ける。
- Storage Rules からの Firestore 参照（クロスサービスルール）が使えるリージョン/設定かは
  実装時に要確認。不可ならカスタムクレーム or パス設計の見直し。

### 2.5 既存データの移行

開発フェーズで「既存データはリセット前提」の方針（ドメインモデル §6 の移行と同じ扱い）が
取れるなら**移行バッチは作らない**のが最安。リリース後に実施する場合は:

1. 新規保存を Storage 方式に切り替え（表示は混在許容）
2. 一度だけの移行スクリプト（Functions or ローカル Admin スクリプト）で
   データ URI を検出 → Storage へアップロード → `imageUrl` を差し替え
3. 全件移行を確認後、データ URI の書き込み経路（`ImageHelper.toDataUri` 直保存）を削除

## 3. Free/Pro 境界（サービス展開計画より）

- **グループあたり写真総枚数: Free 15 枚 / Pro 無制限**、アイテムあたり Free 1 枚 / Pro 複数枚。
- 枚数カウントは Firestore 側で持つ必要がある（Storage の list は高くつく）。
  `groups/{groupId}` に `photoCount` を持たせ、§2.3 のトリガーで増減させる案を推奨。
  クライアント側チェックは UX 用、強制は Rules（`photoCount` 参照）またはトリガー側で。

## 4. 論点

| # | 論点 | 推奨 |
|---|---|---|
| 1 | 実施タイミング | **よく買う物リスト・履歴より先**。データリセットが許される開発フェーズのうちに |
| 2 | 既存データ | 開発フェーズ中ならリセット（移行バッチなし） |
| 3 | リサイズ仕様 | 長辺 1024px / JPEG 品質 80 / 上限 1MiB（Rules でも強制） |
| 4 | サムネイル生成 | 初期は不要（1024px をそのまま表示）。一覧のパフォーマンス問題が出たら Extensions の Resize Images で `_200x200` 生成を検討 |
| 5 | `storage.rules` の整備 | 本移行と同時に必須（アバター含めて現状を確認し、リポジトリ管理 + `firebase deploy --only storage` をフローに追加） |
