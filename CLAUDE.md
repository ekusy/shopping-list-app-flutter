# CLAUDE.md — shopping-list-app-flutter

Claude Code がこのリポジトリで作業する際のガイドライン。

## 環境

開発環境は Docker に統一している。ホストマシンに Flutter / Dart / Firebase CLI を
直接インストールする必要はない。

- **Flutter 3.44.0 / Dart 3.12.0**（コンテナ内）
- 対応プラットフォーム: **Web / Android / iOS**
  - Web: コンテナ内で完結。ブラウザはホスト側を使用（`flutter run -d web-server` → `localhost:5000`）
  - Android: コンテナ内ビルド + ホスト側 adb 経由で実機・Wi-Fi デバッグ（手順は `docs/ANDROID_DOCKER.md`）
  - iOS: **macOS + Xcode 必須**のため Docker 化対象外。Mac ホスト上で直接 `flutter` を実行する（手順は `docs/IOS_LOCAL.md`）

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

iOS は Docker 不可。macOS + Xcode 環境で **コンテナを経由せず直接** 実行する。
**環境構築・実機セットアップ・トラブルシュートの詳細手順は `docs/IOS_LOCAL.md` を参照**
（ホストにコンテナと同一バージョンの Flutter を導入して使う）。

```bash
# シミュレータ / 実機ビルド & 実行
flutter run -d <simulator-udid>    # xcrun simctl list devices available で取得
flutter run -d <device-id>         # 実機 (flutter devices で取得)

# 配布用ビルド
flutter build ios --release        # Xcode で archive する前段
flutter build ipa --release        # App Store 提出用 .ipa
```

要点：
- iOS ネイティブ依存は **Swift Package Manager** で解決（Podfile 無し / `pod install` 不要）
- `IPHONEOS_DEPLOYMENT_TARGET` は **15.0**（Firebase iOS SDK の最低要件。下げないこと）
- Firebase 初期化は `lib/firebase_options.dart` で完結。`GoogleService-Info.plist` は
  ネイティブ設定が必要なプラグイン（google_sign_in 等）導入時のみ
  `flutterfire configure --platforms=ios` で生成する（`.gitignore` 済 / コミット禁止）
- 実機 debug 実行は USB 接続を推奨（Wi-Fi はタイムアウトしやすい。回避策は `docs/IOS_LOCAL.md` §3）

### Firebase

```bash
docker compose run --rm flutter firebase deploy --only hosting
docker compose run --rm flutter firebase deploy --only firestore:rules
docker compose run --rm flutter firebase deploy --only storage          # storage.rules のデプロイ（#38）
docker compose run --rm flutter firebase emulators:start
```

> **`storage.rules`（#38 / #43）**: リポジトリ管理の Storage Security Rules。
> 商品画像（`groups/{groupId}/items/{itemId}.jpg`）とよく買う物テンプレート画像
> （`groups/{groupId}/favoriteItems/{favoriteId}.jpg`、#43）はグループメンバーのみ読み書き可。
> アバター（`avatars/{uid}`）は本人のみ書き込み可。
> 変更時は `firebase deploy --only storage` で反映すること。

### Cloud Functions（Node / TypeScript）

バックエンド（Issue #37 Phase 0〜）は `functions/`（TypeScript / firebase-functions v2 / Node 22）。
ビルド・lint・テストは flutter イメージを肥大化させないため、専用の `functions` サービス
（`node:22`）で実行する（#33 Q7 の決定）。

```bash
docker compose run --rm functions npm ci          # 依存インストール（package-lock.json 生成）
docker compose run --rm functions npm run build   # tsc で lib/ へコンパイル
docker compose run --rm functions npm run lint    # eslint
docker compose run --rm functions npm test        # vitest
```

エミュレータ（Functions のみ）:

```bash
docker compose run --rm --service-ports functions npx firebase-tools emulators:start --only functions
```

デプロイは Firebase CLI 経由（`firebase.json` の `functions.predeploy` で lint → build を自動実行）。
**flutter サービスからはデプロイしないこと**。`functions/node_modules` は `functions_node_modules`
ボリュームにのみ存在し flutter コンテナにマウントされず、かつ flutter イメージの Node/npm が古いため、
predeploy の lint が `/bin/sh: 0: Illegal option --` で失敗する。**`functions` サービス（node:22）から
実行する**。`firebase.json` はリポジトリルート（`/app`）にあるため `cd /app` してから実行する:

```bash
docker compose run --rm functions sh -c "cd /app && npx --yes firebase-tools deploy --only functions --non-interactive"
```

> Storage Rules / Hosting / Firestore rules・indexes は flutter サービスの `firebase deploy` で可
> （例: `firebase deploy --only storage`）。Functions のみ上記の `functions` サービス経由が必須。

認証は `FIREBASE_TOKEN`（`.env`）のほか、**ホストの gcloud ADC をマウントする方式**も使える
（`firebase login:ci` の対話認証が不要になる）。詳細は `docs/DEPLOYMENT.md` の「認証方式」を参照:

```bash
docker compose run --rm \
  -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
  functions sh -c "cd /app && npx --yes firebase-tools deploy --only functions --non-interactive"
```

ロジックと trigger wrapper の分離方針など詳細は `functions/README.md` を参照。

### Firestore インデックス / TTL

複合インデックスと **TTL ポリシーは `firestore.indexes.json` で一元管理**する。

- 複合インデックス: `indexes` に定義。
- **TTL**: `fieldOverrides` に `{ "collectionGroup": "...", "fieldPath": "expiresAt", "ttl": true, "indexes": [] }`
  で定義（現状 `itemHistory` / `suggestions` の `expiresAt`）。`"indexes": []` は不要な単一フィールド
  インデックスを張らない指定。
- 反映: `docker compose run --rm functions npx firebase-tools deploy --only firestore:indexes`。
- **重要**: TTL を gcloud / コンソールで個別設定しないこと。`firestore.indexes.json` に記載の無い
  TTL は `firebase deploy --only firestore:indexes`（`--force`）時に **field override ごと削除される**
  （#56 で実害発生）。TTL は必ずこのファイルで管理する。

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
| `functions_node_modules` | `/app/functions/node_modules` | Functions の npm 依存（OS 依存バイナリのホスト混入回避） |

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

状態の一覧は `docs/REMAINING_TASKS.md`、着手順の提案は `docs/開発計画/実装順序.md` を参照。
- Android: Docker に SDK 組込済。実機検証とリリース署名設定が残（`docs/ANDROID_DOCKER.md` / #36 / #91）
- iOS: シミュレータ・実機での開発ビルド検証済み（2026-07-08、手順は `docs/IOS_LOCAL.md`）。App Store 配布用の署名・ビルドが残
- Web: `develop` へのマージで Firebase Hosting へ自動デプロイ済み（`.github/workflows/deploy-web.yml`）。
  Firestore / Storage ルール・インデックス・Functions のデプロイは手動
- 通知（FCM 実送信）は未実装（#44 / #45）。監視（Crashlytics / Analytics）も未導入（#92）
