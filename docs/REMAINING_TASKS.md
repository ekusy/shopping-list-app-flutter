# 残作業・デプロイ準備ガイド

> **更新日:** 2026-09-08（前回: 2026-08-27）
> **位置づけ:** 「今どこまで動いていて、何が残っているか」の一覧。個別の作業内容は
> GitHub Issue に、設計は `docs/内部設計/` に置く。本書は **状態と Issue への入口**のみを持つ。

凡例: ✅ 完了 / 🔴 必須 / 🟡 推奨 / 🟢 任意

---

## 0. 現況サマリ

| 項目 | 状態 |
|---|---|
| Flutter 実装 | ✅ Phase 1（Sprint 1〜6）の機能 + AI 提案 / 購入履歴 / よく買う物リスト / 画像 Storage 移行まで実装済み |
| 画面 | ✅ 認証 / ダッシュボード / グループ（作成・参加・設定）/ プロフィール / 提案 / よく買う物 / 履歴 |
| バックエンド | ✅ Cloud Functions（TypeScript / Node 22）で履歴集計・週次 AI 提案・削除連動を運用中 |
| テスト | ✅ Flutter: 34 ファイル / 約 190 ケース、Functions: 約 68 ケース（vitest） |
| CI | ✅ `test.yml`（analyze + format + test / Functions lint + build + test） |
| Web デプロイ | ✅ `deploy-web.yml` により `develop` マージで Firebase Hosting へ自動デプロイ |
| モバイルデプロイ | 🔴 未署名のスモークビルドのみ（#91） |
| 通知（FCM 実送信） | 🔴 未実装（#44 / #45）。現状は通知フラグの保存のみ |
| 監視（Crashlytics / Analytics） | 🔴 未導入（#92） |

---

## 1. ✅ Firebase プロジェクト接続（完了）

`flutterfire configure` により `household-shopping-list-f7c12` に接続済み。

- `lib/firebase_options.dart`: 実値でコミット済み
- `android/app/google-services.json`: **gitignored**（クローン後は再生成が必要）
- `ios/Runner/GoogleService-Info.plist`: 現状は不要（`firebase_options.dart` で動作）。
  ネイティブ設定が必要なプラグイン導入時のみ生成する

再生成:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=household-shopping-list-f7c12 \
  --platforms=android,ios,web \
  --android-package-name=com.ekusy.shopping_list_app \
  --ios-bundle-id=com.ekusy.shoppingListApp \
  --yes
```

### ルール / インデックスのデプロイ（手動）

`firebase.json` は `firestore` / `storage` / `functions` / `hosting` を管理している。
**Hosting 以外は自動デプロイされない**ため、変更時は手動で反映すること。

```bash
docker compose run --rm flutter firebase deploy --only firestore:rules
docker compose run --rm flutter firebase deploy --only storage
docker compose run --rm functions npx firebase-tools deploy --only firestore:indexes
docker compose run --rm functions sh -c "cd /app && npx --yes firebase-tools deploy --only functions --non-interactive"
```

> Functions のみ `functions` サービス（node:22）から実行すること（理由は `CLAUDE.md`）。
> TTL は `firestore.indexes.json` の `fieldOverrides` で管理する（#56 の再発防止）。

---

## 2. ✅ Web デプロイ（自動化済み）

`develop` へのマージで `.github/workflows/deploy-web.yml` が Firebase Hosting（`live` チャネル）へ
デプロイする。手動実行（`workflow_dispatch`）も可。

手元からデプロイする場合:
```bash
docker compose run --rm flutter flutter build web --release --pwa-strategy=offline-first
docker compose run --rm flutter firebase deploy --only hosting
```

> `main` へのマージでは Web デプロイは走らない（モバイルビルドのみ）。

---

## 3. 🟡 Android

Docker イメージに Android SDK + JDK を組込済み。ホスト側に必要なのは `adb` だけ。
手順は **[`docs/ANDROID_DOCKER.md`](./ANDROID_DOCKER.md)**。

### 残課題

- **実機での動作検証**（メンテナ手元に Android 端末が無いため未確認 / #36）
- **リリース署名**: release ビルドは現状デバッグキーで署名される。キーストア生成と
  `android/key.properties` の整備が必要（#36 / 手順は `docs/ANDROID_DOCKER.md` §7）
- **CI のリリースビルド化**: `build-mobile.yml` は `flutter build apk --debug` のまま（#91）

---

## 4. 🟡 iOS（macOS 必須）

**開発ビルドは検証済み**（2026-07-08 / シミュレータ iOS 26.5 + 実機 iPhone 12 Pro / iOS 26.6）。
環境構築〜実機インストールの手順は [`docs/IOS_LOCAL.md`](./IOS_LOCAL.md)。

### 残課題

- App Store 配布用の署名（有料 Apple Developer Program）と `flutter build ipa` の検証（#36）
- CodeMagic 等での `main` 連動ビルド / TestFlight 配信の整備（#91）

---

## 5. 🔴 ストア配布・課金・通知の前提（オーナー作業）

いずれも開発者アカウント・鍵・法的文書を伴うため、コードだけでは完結しない。

| 内容 | Issue |
|---|---|
| プライバシーポリシー・利用規約の整備 | #35 |
| 署名鍵 / ストアアカウント / APNs / VAPID / RevenueCat の整備 | #36 |

---

## 6. 🟡 品質・基盤の残作業

コードベースの調査（2026-08-27）で洗い出した未対応項目と、本番で発生中の不具合。

| 内容 | Issue | 状態 |
|---|---|---|
| **Web 版の日本語が tofu（□）表示になる** | #75 | 🔴 本番で発生中。最優先 |
| 招待リンクがネイティブで開けない（intent-filter / URL scheme 未設定） | #87 | |
| `normalizeName` の Dart / TS 乖離（NFKC 未対応） | #88 | 🔧 対応中（PR #95） |
| Firestore / Storage セキュリティルールの自動テストが無い | #89 | |
| `integration_test`（E2E）が無い | #90 | |
| モバイル CI のリリース署名 / AAB 化・iOS 連携 | #91 | |
| Crashlytics / Analytics 未導入（βゲート指標が計測不能） | #92 | |
| アプリ名・テーマカラーのブランド不統一 | #93 | |

---

## 7. 🟢 機能ロードマップ

実装トラッキングは **#46**（ロードマップ Issue）に集約している。着手順の提案は
[`docs/開発計画/実装順序.md`](./開発計画/実装順序.md) を参照。

### 実装済み

- #37 AI 提案 Phase 0（購買履歴基盤）/ #40 週次提案パイプライン / #41 提案画面
- #38 商品画像の Storage 移行 / #43 よく買う物リスト / #42 購入履歴タイムライン
- #39 マネタイズ M0（PlanLimits 共通化 + plan フィールドの Rules 保護）
- #52 functions/src のレイヤ分割

> #39 / #52 は実装が入っていたが Issue が Open のまま残っていた（2026-09-05 に棚卸ししてクローズ）。
> #39 の受け入れ条件のうち「Rules 変更分の自動テスト」だけは未達で、#89 のスコープに含める。

### 未着手（Issue 済み）

- #44 通知第 1 弾（FCM 基盤）→ #45 AI 提案 Phase 2（提案プッシュ）
- #49 誤購入の取り消し / #10〜#14 UI 改善 / #77 コスト削減

> Web の tofu 表示（#75）は機能ロードマップではなく**本番で発生中の不具合**のため §6 に移した。

### 未起票（着手条件が揃ってから起票）

- 購入履歴 Step 2: 統計ダッシュボード（Pro 専用）
- マネタイズ M1（投げ銭）→ M2（Pro 購読）→ M3（ファミリープラン）
- AI 提案 Phase 3（フィードバック還流・プラン連動）

---

## 8. 🟢 元アプリにあって本移植で未対応の機能

移植方針（機能パリティ優先・構造は idiomatic な Flutter へ再編）に基づき意図的に除外:

- **`lists` 機能**: ユーザー定義タグへ置き換え済みのため未移植（ルールのみ互換目的で残置）
- **プッシュ通知の実送信**: 元アプリも FCM / Web Push は別途設定が必要。本移植では
  通知トグル（フラグ保存）のみ実装。実送信は #44 で対応する
