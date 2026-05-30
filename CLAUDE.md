# CLAUDE.md — shopping-list-app-flutter

Claude Code がこのリポジトリで作業する際のガイドライン。

## 環境

- Flutter 3.44 / Dart 3.12（`/snap/bin/flutter`、`/snap/bin/dart`）
- WSL 上で Windows 側の Flutter SDK（`/mnt/g/flutter/...`）が PATH に混入する。
  `settings.json` の `env.PATH` で `/snap/bin` を先頭に固定済み。
  **`flutter` / `dart` は常に `/snap/bin/` のものを使う。**
- Android SDK 未インストール（Android ビルドはユーザー環境依存）
- Chrome: `/usr/bin/google-chrome`（Web デバッグ用）

## 開発コマンド

### 静的解析・フォーマット

```bash
flutter analyze                        # lint（flutter_lints）
dart format lib test                   # コードフォーマット
dart format --output=none --set-exit-if-changed lib test  # フォーマットチェックのみ
```

### テスト

```bash
flutter test                           # 全テスト実行
flutter test test/widgets/             # ウィジェットテストのみ
flutter test --name "テスト名"          # 名前でフィルタ
flutter test --coverage                # カバレッジ収集 → coverage/lcov.info
```

### ローカル起動（Web）

```bash
flutter run -d chrome                  # Chrome でデバッグ起動（ホットリロード有効）
flutter run -d chrome --web-port=5000  # ポート指定
flutter run -d chrome --release        # リリースモードで起動
```

### ビルド

```bash
flutter build web                      # Web 静的ビルド → build/web/
flutter build web --release            # リリースビルド（tree-shake icons 有効）
flutter build apk                      # Android APK（要 Android SDK）
flutter build appbundle                # Android App Bundle（Play 配布用）
```

### Firebase

```bash
firebase deploy --only firestore:rules # Firestore セキュリティルールをデプロイ
firebase deploy --only hosting         # Web を Firebase Hosting にデプロイ
firebase emulators:start               # ローカルエミュレータ起動（Firestore / Auth）
```

### 依存管理

```bash
flutter pub get                        # 依存解決
flutter pub upgrade                    # パッチ・マイナーアップグレード
flutter pub outdated                   # 更新可能パッケージ一覧
dart pub global activate flutterfire_cli  # FlutterFire CLI インストール/更新
flutterfire configure \
  --project=household-shopping-list-f7c12 \
  --platforms=android,ios,web \
  --android-package-name=com.ekusy.shopping_list_app \
  --ios-bundle-id=com.ekusy.shoppingListApp \
  --yes                                # Firebase 設定ファイル再生成
```

## アーキテクチャ概要

```
lib/
├── core/            # errors / constants / theme / utils（横断的関心事）
├── domain/          # entities + abstract repositories（ビジネスロジック）
├── data/            # Firestore/Auth/Storage の実装 + mapper/converter
├── presentation/    # Riverpod providers / go_router / screens / widgets
└── main.dart
test/
├── core/            # AppError, invite_code/url, item_icons
├── data/            # repository 実装テスト（fake_cloud_firestore）
├── domain/          # エンティティロジック
├── helpers/         # 共通テストユーティリティ（test_localization.dart）
├── presentation/    # provider/controller テスト
└── widgets/         # ウィジェットテスト
```

## テスト作成のルール

- ウィジェットテストで `easy_localization` を使う場合は必ず
  `test/helpers/test_localization.dart` の `pumpLocalized` / `setUpTestLocalization` を使う。
  標準の `RootBundleAssetLoader` は非同期のため、同一ファイル内の複数テストで
  2件目以降が空描画になる既知の問題がある。
- ボタン等のタップは `find.bySemanticsLabel` でラベルを使って特定するのが望ましい
  （`find.text` は絵文字アイコン等で不安定になりやすい）。

## コミット規約

```
feat:     新機能
fix:      バグ修正
refactor: 動作変更なしのリファクタリング
test:     テスト追加・修正
chore:    ビルド・設定・依存の変更
docs:     ドキュメントのみの変更
perf:     パフォーマンス改善
```

## gitignore 対象（コミット禁止）

- `android/app/google-services.json`（flutterfire configure で再生成）
- `ios/Runner/GoogleService-Info.plist`
- `.firebase/`、`firebase-debug.log`
- `build/`（このマシンでは `/tmp/sla_build` へのシンボリックリンク）

## 残作業

詳細は `docs/REMAINING_TASKS.md` を参照。
- Android ビルド検証（要 Android SDK）
- iOS ビルド（要 macOS + Xcode）
- Firestore ルールのデプロイ → 完了
- Firebase Hosting デプロイ（`firebase deploy --only hosting`）
