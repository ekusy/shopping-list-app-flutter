# CLAUDE.md — shopping-list-app-flutter

Claude Code がこのリポジトリで作業する際のガイドライン。

## 環境

開発環境は Docker に統一している。ホストマシンに Flutter / Dart / Firebase CLI を
直接インストールする必要はない。

- **Flutter 3.44.0 / Dart 3.12.0**（コンテナ内）
- **Web / Android 対応**（iOS は macOS + Xcode が必要なためコンテナ外）
- Web: ブラウザはホスト側のものを使用（`flutter run -d web-server` → `localhost:5000`）
- Android: コンテナ内ビルド + ホスト側 adb 経由で実機・Wi-Fi デバッグ（手順は `docs/ANDROID_DOCKER.md`）

## Docker コマンド

### イメージビルド（初回 / Dockerfile 変更時）

```bash
docker compose build
```

### 開発サーバー起動（ホットリロード有効）

```bash
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
```

ホストのブラウザで `http://localhost:5000` にアクセス。
ターミナルで `r` キー押下でホットリロード、`R` でフルリスタート。

### 静的解析・フォーマット

```bash
docker compose run --rm flutter flutter analyze
docker compose run --rm flutter dart format lib test
docker compose run --rm flutter dart format --output=none --set-exit-if-changed lib test
```

### テスト

```bash
docker compose run --rm flutter flutter test
docker compose run --rm flutter flutter test test/widgets/
docker compose run --rm flutter flutter test --coverage
```

### ビルド

```bash
docker compose run --rm flutter flutter build web --release
docker compose run --rm flutter flutter build apk --release          # Android APK
docker compose run --rm flutter flutter build appbundle --release    # Android App Bundle (.aab)
```

### Android デバッグ・インストール

ホスト側で adb server を起動した上で：

```bash
docker compose run --rm flutter flutter devices
docker compose run --rm --service-ports flutter flutter run -d <device-id>
docker compose run --rm flutter flutter install
```

詳細手順（USB / Wi-Fi 接続、署名、トラブルシュート）は `docs/ANDROID_DOCKER.md`。

### Firebase

```bash
docker compose run --rm flutter firebase deploy --only hosting
docker compose run --rm flutter firebase deploy --only firestore:rules
docker compose run --rm flutter firebase emulators:start
```

### 依存管理

```bash
docker compose run --rm flutter flutter pub get
docker compose run --rm flutter flutter pub upgrade
docker compose run --rm flutter flutter pub outdated
```

### コンテナに入る（対話操作）

```bash
docker compose run --rm flutter bash
```

### ボリューム構成

| ボリューム名 | マウント先 | 用途 |
|---|---|---|
| `pub_cache` | `/root/.pub-cache` | pub パッケージキャッシュ（再ビルド高速化） |
| `build_vol` | `/app/build` | ビルド出力（ホスト FS を経由しない高速パス） |
| `gradle_cache` | `/root/.gradle` | Gradle 依存・ラッパー DL（Android ビルド高速化） |
| `dart_tool_vol` | `/app/.dart_tool` | package_config.json（ホスト絶対パス混入回避） |

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
- `build/`

## 残作業

詳細は `docs/REMAINING_TASKS.md` を参照。
- Android ビルド検証 → 手順は `docs/ANDROID_DOCKER.md`（コンテナ完結 + ホスト adb proxy）
- iOS ビルド（要 macOS + Xcode）
- Firebase Hosting デプロイ（`firebase deploy --only hosting`）
