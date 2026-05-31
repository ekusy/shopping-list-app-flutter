# 残作業・デプロイ準備ガイド

このリポジトリは Flutter への移植（機能・UI・単体テスト）が完了し、
`flutter analyze` クリーン / 単体テスト 64 件成功 / **Web ビルド成功** / **Firebase 接続済み** の状態です。
一方で、**実行・配布には以下のユーザー作業が必要**です（環境要因・要シークレットのため自動化不可）。

凡例: ✅ 完了 / 🔴 必須 / 🟡 推奨 / 🟢 任意

---

## 1. ✅ Firebase プロジェクト接続（完了）

`flutterfire configure` により `household-shopping-list-f7c12` プロジェクトに接続済み。
- `lib/firebase_options.dart`: 実値に更新（コミット済み）
- `android/app/google-services.json`: 生成済み（**gitignored** / クローン後は再生成が必要）
- Android Gradle に `com.google.gms.google-services` プラグイン追加済み

再生成が必要な場合（クローン直後など）:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=household-shopping-list-f7c12 \
  --platforms=android,ios,web \
  --android-package-name=com.ekusy.shopping_list_app \
  --ios-bundle-id=com.ekusy.shoppingListApp \
  --yes
```

### Firestore セキュリティルールのデプロイ
本リポジトリに `firestore.rules`（元アプリから移植）と `firebase.json` を同梱済み。
```bash
firebase deploy --only firestore:rules
```

---

## 2. 🟡 Android ビルド検証

Docker イメージに **Android SDK + JDK 21 を組み込み済み**。ホスト側に必要なのは
`adb`（platform-tools）だけ。完全手順は **[`docs/ANDROID_DOCKER.md`](./ANDROID_DOCKER.md)** を参照。

### 概要
- ビルド: `docker compose run --rm flutter flutter build apk` / `... build appbundle`
- デバッグ: ホストで `adb -a -P 5037 nodaemon server start` → コンテナの `flutter run`
- インストール: `docker compose run --rm flutter flutter install`
- USB / Wi-Fi デバッグ両対応（Android 11+）

### 残課題
- **実機での動作検証**（メンテナ手元に Android 端末が無いため未確認）
- **リリース署名設定**: `android/app/build.gradle.kts` の release ビルドは現状デバッグ
  キーで署名される。Play 配布時はキーストア生成 + `android/key.properties` 整備が必要
  （手順は `docs/ANDROID_DOCKER.md` §7）。

---

## 3. 🟡 iOS ビルド（macOS 必須）

`ios/` のシェルは用意済みですが、ビルド・署名には macOS + Xcode が必要です。
`flutterfire configure` で `GoogleService-Info.plist` を配置後、Xcode で
署名チーム・bundleId を設定してビルドしてください。

---

## 4. 🟡 Web デプロイ

Web ビルドは検証済み（`flutter build web` → `build/web`）。Firebase Hosting で配信できます。
```bash
flutter build web
firebase deploy --only hosting       # firebase.json の hosting 設定を使用
```
> `flutter run -d chrome` でのローカル起動には Chrome が必要です（開発機未インストール）。
> ビルド自体（`flutter build web`）に Chrome は不要です。

---

## 5. 🟢 元アプリにあって本移植で未対応の機能

移植方針（機能パリティ優先・構造は idiomatic な Flutter へ再編）に基づき、以下は意図的に除外:

- **`lists` 機能**: #142 でフラット構造へ移行済みのため未移植（ルールのみ互換目的で残置）。
- **プッシュ通知の実送信**: 元アプリも FCM/Web Push は別途設定が必要。本移植では
  通知トグル（フラグ保存）のみ実装。実際の通知配信を行う場合は `firebase_messaging`
  の導入と各プラットフォーム設定が別途必要。

---

## 6. 🟢 CI（任意）

元アプリは GitHub Actions を利用。Flutter 版でも以下を CI 化すると安全:
```yaml
# 例: .github/workflows/ci.yml の要点
- flutter pub get
- flutter analyze
- flutter test
- flutter build web
```

---

## チェックリスト（tasks.yml 対応状況）

| tasks.yml の check | 状態 |
|---|---|
| 全機能を Flutter で再構成 | ✅ 完了（`lists` 等の廃止機能を除く） |
| 同等の単体テストが成功 | ✅ 64 件成功 |
| Web ビルド成功 | ✅ 確認済み |
| Android ビルド成功 | 🟡 Docker に SDK 組込済（§2 / `ANDROID_DOCKER.md`）。実機検証は手元端末待ち |
| デプロイ準備完了 | 🟡 ✅ Firebase 接続済み・ルール/Hosting 設定済み。残: Firestore ルールデプロイ（§1）、Web Hosting deploy（§4） |
| Flutter ベストプラクティス準拠 | ✅ クリーンアーキテクチャ + MVVM + Riverpod |
| 直感的な UI | ✅ 元アプリの UX を踏襲 |
| 残ユーザータスクの明確化 | ✅ 本ドキュメント |
| ドキュメント作成 | ✅ README + 本ドキュメント |
