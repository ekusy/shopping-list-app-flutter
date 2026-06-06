# CLAUDE.md — shopping-list-app-flutter

Claude Code がこのリポジトリで作業する際のガイドライン。

## 環境

開発環境は Docker に統一している。ホストマシンに Flutter / Dart / Firebase CLI を
直接インストールする必要はない。

- **Flutter 3.44.0 / Dart 3.12.0**（コンテナ内）
- 対応プラットフォーム: **Web / Android / iOS**
  - Web: コンテナ内で完結。ブラウザはホスト側を使用（`flutter run -d web-server` → `localhost:5000`）
  - Android: コンテナ内ビルド + ホスト側 adb 経由で実機・Wi-Fi デバッグ（手順は `docs/ANDROID_DOCKER.md`）
  - iOS: **macOS + Xcode 必須**のため Docker 化対象外。Mac ホスト上で直接 `flutter` を実行する

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
docker compose run --rm flutter flutter build web --release --pwa-strategy=offline-first
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

### iOS ビルド・デバッグ（macOS ホスト上で実行）

iOS は Docker 不可。macOS + Xcode 環境で **コンテナを経由せず直接** 実行する：

```bash
# 初回のみ: CocoaPods 同期
cd ios && pod install && cd ..

# シミュレータ / 実機ビルド & 実行
flutter run -d "iPhone 15"        # 起動中のシミュレータを指定
flutter run -d <device-id>        # 実機 (flutter devices で取得)

# 配布用ビルド
flutter build ios --release        # Xcode で archive する前段
flutter build ipa --release        # App Store 提出用 .ipa
```

事前準備：
- `flutterfire configure --platforms=ios` で `ios/Runner/GoogleService-Info.plist` を生成（`.gitignore` 済 / コミット禁止）
- Xcode で Runner.xcworkspace を開き、Signing & Capabilities にチーム / bundleId を設定
- App Tracking / Photo Library 等の Info.plist usage description が必要なら追加

### Firebase

```bash
docker compose run --rm flutter firebase deploy --only hosting
docker compose run --rm flutter firebase deploy --only firestore:rules
docker compose run --rm flutter firebase emulators:start
```

### Firebase Hosting キャッシュ制御

`firebase.json` の `hosting.headers` で以下の方針を維持すること。

| 対象 | Cache-Control | 理由 |
|---|---|---|
| `**/*.@(js\|css\|wasm)` | `public, max-age=31536000, immutable` | Flutter ビルドはコンテンツハッシュ付きファイル名のため安全 |
| `**/*.@(png\|jpg\|jpeg\|webp\|avif\|svg\|gif\|ico)` | `public, max-age=31536000, immutable` | 同上 |
| `**/*.@(woff\|woff2\|ttf\|eot)` | `public, max-age=31536000, immutable` | 同上 |
| `/index.html` | `no-cache` | エントリポイントは常に最新を取得する必要がある |
| `/flutter_service_worker.js` | `no-cache` | SW の更新を即時反映するために no-cache が必要 |

新たな静的アセット種別を追加した場合は、ハッシュ付きファイル名かどうかを確認し、適切なルールを `firebase.json` に追記すること。

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

## 設計ドキュメント

実装の前提となる設計は `docs/` 配下に集約している。**コードを変更した際は必ず関連するドキュメントも合わせて更新すること。**

- `docs/内部設計/アーキテクチャ概要.md` — レイヤー構成・依存方向・エラー変換のハブ
- `docs/内部設計/ドメインモデル.md` — エンティティ・Firestore パス階層
- `docs/内部設計/ユースケース.md` / `データフロー.md` / `状態遷移.md`
- `docs/外部仕様/エラー仕様.md` — AppError コード一覧・i18n キー対応

エラーハンドリングは、UI 層では `lib/core/errors/app_error.dart` の `AppError` のみを扱い、
Firebase 固有の例外は `lib/data/firebase/firebase_error_converter.dart` で `AppError` に
変換してから送出する（詳細は `docs/外部仕様/エラー仕様.md`）。

## Deferred Loading（遅延ロード）

PR #20 で初期バンドルサイズ削減のため導入済み。
新しい route（画面）を追加する際は `deferred as` import を検討すること。
`lib/presentation/` の既存 screen を参照。

## テスト作成のルール

- ウィジェットテストで `easy_localization` を使う場合は必ず
  `test/helpers/test_localization.dart` の `pumpLocalized` / `setUpTestLocalization` を使う。
  標準の `RootBundleAssetLoader` は非同期のため、同一ファイル内の複数テストで
  2件目以降が空描画になる既知の問題がある。
- ボタン等のタップは `find.bySemanticsLabel` でラベルを使って特定するのが望ましい
  （`find.text` は絵文字アイコン等で不安定になりやすい）。

## ブランチ・マージ規約

ブランチモデルと CI/CD の全体方針は `docs/開発ガイド/Gitワークフロー.md` を参照（Issue #25）。

- `main`（デプロイ用 / モバイルビルド起点）・`develop`（開発用 / Web 先行評価デプロイ起点）・
  `feature/*`（実装用）の 3 ブランチモデルで運用する。
- 何らかの変更を行う際は必ず **`develop` から作業ブランチ**を作成してから作業する
  - 接頭辞は用途で使い分ける: `feature/`, `fix/`, `chore/`, `docs/`, `perf/`
  - 命名例: `feature/add-item-sort`, `fix/24-first-login-list`, `chore/25-git-workflow`
- `main` / `develop` への直接コミット・プッシュは禁止（ブランチ保護で強制）。
- `main` から新規ブランチを作成しない（`develop` を唯一の派生元とする）。

> **オーナーへの注意**: ブランチ保護は管理者を対象外（enforce admins 無効）に設定している。
> これは緊急対応用の例外であり、オーナーも原則として保護ルール（PR 経由・`test` 必須）を遵守すること。
> 保護をバイパスした直接 push は事故対応など真にやむを得ない場合に限る。

### マージリクエスト（Pull Request）

- 作業ブランチ → `develop` への PR を作成してマージする。リリース時は `develop` → `main` の PR を作成する。
- `main` / `develop` へのマージは必ず **PR を作成**してから行う（直接マージ禁止）。
- マージ条件: `test`（`flutter analyze` + `flutter test`）が成功していること。
- PR には以下を明記する:

```markdown
## 対応内容
<!-- 何を変更したか・なぜ変更したかを記述 -->

## 影響範囲
<!-- 変更が影響するファイル・機能・画面 -->

## 確認項目
- [ ] flutter analyze が通る
- [ ] flutter test が通る
- [ ] 対象機能の動作確認済み
- [ ] 関連ドキュメント（docs/）を更新した
```

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
- Android: Docker に SDK 組込済。実機検証とリリース署名設定が残（`docs/ANDROID_DOCKER.md`）
- iOS: scaffold あり。`flutterfire configure --platforms=ios` 後に Xcode で署名・実機ビルド検証が残
- Firebase Hosting デプロイ（`firebase deploy --only hosting`）
