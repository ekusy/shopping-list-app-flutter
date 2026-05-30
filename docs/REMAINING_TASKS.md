# 残作業・デプロイ準備ガイド

このリポジトリは Flutter への移植（機能・UI・単体テスト）が完了し、
`flutter analyze` クリーン / 単体テスト 64 件成功 / **Web ビルド成功** の状態です。
一方で、**実行・配布には以下のユーザー作業が必要**です（環境要因・要シークレットのため自動化不可）。

凡例: 🔴 必須 / 🟡 推奨 / 🟢 任意

---

## 1. 🔴 Firebase プロジェクト接続

現状 `lib/firebase_options.dart` は `YOUR_*` プレースホルダのテンプレートです。
このままでも UI のビルド・起動はできますが、認証・Firestore・Storage へは接続できません。

### 手順
1. [Firebase コンソール](https://console.firebase.google.com/) でプロジェクトを作成
   （または既存の `shopping-list-app` プロジェクトを再利用）。
2. Authentication で **メール/パスワード** サインインを有効化。
3. Cloud Firestore と Storage を有効化。
4. FlutterFire CLI で設定ファイルを生成（テンプレートを上書き）:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   - Android の applicationId / iOS の bundleId は `com.ekusy.shopping_list_app` /
     `com.ekusy.shoppingListApp` を想定（`android/app/build.gradle.kts` ・
     `lib/firebase_options.dart` 参照）。
   - これにより `lib/firebase_options.dart` が実値で上書きされ、Android は
     `google-services.json`、iOS は `GoogleService-Info.plist` が配置されます。
     これらは **コミットしない**（`.gitignore` 済み / シークレット相当）。

### Firestore セキュリティルールのデプロイ
本リポジトリに `firestore.rules`（元アプリから移植）と `firebase.json` を同梱済み。
```bash
firebase deploy --only firestore:rules
```

---

## 2. 🔴 Android ビルド検証

開発機（WSL）に **Android SDK が未インストール**のため、Android ビルドは未検証です。

### 手順
1. Android Studio または command-line tools で Android SDK を導入し、
   `flutter doctor` がグリーンになることを確認。
   ```bash
   flutter doctor          # Android toolchain の項目を解消する
   ```
2. ビルド:
   ```bash
   flutter build apk            # 動作確認用 APK
   flutter build appbundle      # Play 配布用 App Bundle (.aab)
   ```
3. リリース署名（Play 配布時）:
   - キーストアを作成し `android/key.properties` を用意（**コミット禁止** / `.gitignore` 済み）。
   - `android/app/build.gradle.kts` に署名設定を追加（現状はデバッグ署名のまま）。

> WSL 補足: `dart` / `flutter` は Windows 版 SDK を指す PATH 設定になっている場合があります。
> Linux 版（例: `/snap/bin/flutter`）を使用してください。

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
| Android ビルド成功 | 🔴 要 Android SDK（本ドキュメント §2） |
| デプロイ準備完了 | 🟡 Firebase 接続 + ルール/Hosting 設定済み、要シークレット投入（§1, §4） |
| Flutter ベストプラクティス準拠 | ✅ クリーンアーキテクチャ + MVVM + Riverpod |
| 直感的な UI | ✅ 元アプリの UX を踏襲 |
| 残ユーザータスクの明確化 | ✅ 本ドキュメント |
| ドキュメント作成 | ✅ README + 本ドキュメント |
