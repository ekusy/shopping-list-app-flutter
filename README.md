# shopping-list-app-flutter

家族で共有する買い物リストアプリ（Flutter 製）。  
「気づいたら記録、記録したら自動で共有、『買います』『買った』で行動も共有」。

[shopping-list-app](https://github.com/ekusy/shopping-list-app)（Expo / React Native）を
Flutter へ移植したものです。

## 対応プラットフォーム

| プラットフォーム | 状態 | 開発環境 |
|---|---|---|
| **Web** | ✅ 検証済み | Docker（コンテナ完結） |
| **Android** | 🟡 Docker 環境整備済み・実機検証待ち | Docker + ホスト adb（`docs/ANDROID_DOCKER.md`） |
| **iOS** | 🟡 scaffold あり・ビルド未検証 | macOS + Xcode（Docker 化対象外） |

## 技術スタック

| 分類 | 技術 |
|---|---|
| フレームワーク | Flutter 3.44 / Dart 3.12 |
| 状態管理 / DI | flutter_riverpod |
| ルーティング | go_router（認証ガード付き宣言的ルーティング） |
| バックエンド | Firebase（firebase_auth / cloud_firestore / firebase_storage） |
| i18n | easy_localization（日本語 / 英語） |
| 画像 | image_picker + image（選択・リサイズ） |
| その他 | connectivity_plus（オフライン検知）、share_plus（招待共有） |
| テスト | flutter_test + fake_cloud_firestore + firebase_auth_mocks + mocktail |
| 開発環境 | Docker（Flutter / Android SDK / JDK 21 / Firebase CLI をコンテナ内で管理。iOS のみ macOS ホスト） |

## アーキテクチャ

クリーンアーキテクチャ + MVVM。依存方向は外側 → 内側（presentation → domain ← data）。

```
lib/
├── core/            # 横断的関心事: errors / constants / theme / utils
├── domain/          # entities（不変モデル）+ abstract repositories（インターフェース）
├── data/            # Firestore/Auth/Storage の repository 実装・mapper・error converter
├── presentation/    # providers(ViewModel) / router / screens / widgets / utils
├── firebase_options.dart   # Firebase 設定（実値投入・コミット済み。再生成は flutterfire configure）
└── main.dart        # エントリポイント（Firebase / easy_localization 初期化）
```

## クイックスタート（Web）

**前提: Docker および Docker Compose V2 がインストール済みであること。**

```bash
# 1. リポジトリをクローン
git clone <repo-url>
cd shopping-list-app-flutter

# 2. Docker イメージをビルド（初回のみ、5-15 分かかります）
docker compose build

# 3. 開発サーバーを起動
docker compose run --rm --service-ports flutter flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
```

ブラウザで **http://localhost:5000** を開くとアプリが表示されます。

### Android / iOS で動かしたい場合

- **Android**: [docs/ANDROID_DOCKER.md](./docs/ANDROID_DOCKER.md) — Docker 内ビルド + ホスト adb proxy で実機 / Wi-Fi デバッグまで対応
- **iOS**: 後述の「[iOS ビルド](#ios-ビルドmacos-ホストで実行)」セクション参照（macOS + Xcode が必須）

> Firebase の接続設定が必要な場合は [docs/REMAINING_TASKS.md](./docs/REMAINING_TASKS.md) を参照してください。

## 開発コマンド

すべてのコマンドはプロジェクトルートで実行します。  
Flutter / Firebase CLI はコンテナ内で動作するため、ホストへのインストールは不要です。

### コンテナ起動・停止

```bash
# イメージビルド（Dockerfile 変更時も実行）
docker compose build

# 対話シェルでコンテナに入る
docker compose run --rm flutter bash

# 起動中のコンテナをすべて停止・削除
docker compose down
```

### 開発サーバー（ホットリロード付き）

```bash
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
```

| キー | 操作 |
|---|---|
| `r` | ホットリロード |
| `R` | フルリスタート |
| `q` | 終了 |

### 静的解析・フォーマット

```bash
# 静的解析（flutter_lints）
docker compose run --rm flutter flutter analyze

# コードフォーマット（上書き）
docker compose run --rm flutter dart format lib test

# フォーマットチェックのみ（CI 用、変更なし）
docker compose run --rm flutter dart format --output=none --set-exit-if-changed lib test
```

### テスト

```bash
# 全テスト実行
docker compose run --rm flutter flutter test

# ウィジェットテストのみ
docker compose run --rm flutter flutter test test/widgets/

# テスト名でフィルタ
docker compose run --rm flutter flutter test --name "テスト名"

# カバレッジ収集（coverage/lcov.info に出力）
docker compose run --rm flutter flutter test --coverage
```

### ビルド

```bash
# Web リリースビルド（build/web/ に出力）
docker compose run --rm flutter flutter build web --release

# Android ビルド（コンテナ完結）
docker compose run --rm flutter flutter build apk --release          # APK
docker compose run --rm flutter flutter build appbundle --release    # App Bundle (.aab)
```

ビルド成果物は Docker の named volume（`build_vol`）に保存されます。  
ホストへ取り出す場合:

```bash
# 一時コンテナからホストへコピー
id=$(docker create $(docker compose images -q flutter))
docker cp "$id":/app/build/web ./build_output
docker rm "$id"

# 名前指定でコピー (例: APK)
docker compose cp flutter:/app/build/app/outputs/flutter-apk/app-release.apk ./app-release.apk
```

### Android デバッグ・実機インストール

ホスト側で adb server を起動した上で：

```bash
# 接続確認
docker compose run --rm flutter flutter devices

# ホットリロード付き実行（DevTools は localhost:9100）
docker compose run --rm --service-ports flutter flutter run -d <device-id>

# ビルド済み APK を install
docker compose run --rm flutter flutter install
```

USB / Wi-Fi 両方の接続手順、署名、トラブルシュートは [docs/ANDROID_DOCKER.md](./docs/ANDROID_DOCKER.md) を参照。

### iOS ビルド（macOS ホストで実行）

iOS は macOS + Xcode が必須のため **Docker 化対象外**。Mac 上で直接 `flutter` を実行する：

```bash
# 初回のみ: CocoaPods 同期
cd ios && pod install && cd ..

# シミュレータ / 実機実行
flutter run -d "iPhone 15"
flutter run -d <device-id>          # flutter devices で取得

# 配布用ビルド
flutter build ios --release          # Xcode で archive 用
flutter build ipa --release          # App Store 提出用 .ipa
```

事前準備：

- `flutterfire configure --platforms=ios` で `ios/Runner/GoogleService-Info.plist` を生成（`.gitignore` 済 / **コミット禁止**）
- `ios/Runner.xcworkspace` を Xcode で開き、Signing & Capabilities にチーム / bundleId を設定
- `Info.plist` に必要な NSPhotoLibraryUsageDescription などの permission 説明を追加

### Firebase

```bash
# Firestore セキュリティルールをデプロイ
docker compose run --rm flutter firebase deploy --only firestore:rules

# Web を Firebase Hosting にデプロイ
docker compose run --rm flutter firebase deploy --only hosting

# ローカルエミュレータ起動（Firestore / Auth）
docker compose run --rm --service-ports flutter firebase emulators:start
```

> 初回は `docker compose run --rm flutter bash` でコンテナに入り、  
> `firebase login --no-localhost` で認証してください。

### 依存管理

```bash
# 依存解決
docker compose run --rm flutter flutter pub get

# パッチ・マイナーアップグレード
docker compose run --rm flutter flutter pub upgrade

# 更新可能パッケージ一覧
docker compose run --rm flutter flutter pub outdated
```

## 主な機能

- **認証**: サインアップ、ログイン、ログアウト、プロフィール編集（アバター画像アップロード）、アカウント削除
- **グループ**: 作成、改名、退出、解散、切替、招待コード参加、メンバー削除、招待 URL 共有
- **タグ**: 追加（無料プラン: 5件 / 有料: 50件）、改名、削除、OR フィルタ
- **アイテム**: 追加 / クイック追加 / 編集 / 削除 / 購入済み切替 / 「買います」宣言 / 一括タグ付け / 購入済み一括削除 / 同期待ちバッジ
- **その他**: オフライン対応とネットワーク状態表示、i18n（日本語 / 英語）

## テスト構成

```
test/
├── core/            # AppError、invite_code/url、item_icons
├── data/            # repository 実装テスト（fake_cloud_firestore 使用）
├── domain/          # エンティティロジック
├── helpers/         # 共通テストユーティリティ（test_localization.dart）
├── presentation/    # provider / controller テスト
└── widgets/         # ウィジェットテスト
```

ウィジェットテストでは `test/helpers/test_localization.dart` の同期アセットローダーを使用し、
`easy_localization` を同一ファイル内の複数テストで安定動作させています。

## ドキュメント

| 区分 | ドキュメント | 内容 |
|---|---|---|
| 開発ガイド | [DEVELOPMENT.md](./docs/DEVELOPMENT.md) | ローカル開発（ビルド & 実行） |
| 開発ガイド | [DEBUGGING.md](./docs/DEBUGGING.md) | DevTools / VS Code アタッチによるデバッグ |
| 開発ガイド | [ANDROID_DOCKER.md](./docs/ANDROID_DOCKER.md) | Android 開発手順（Docker + ホスト adb） |
| 開発ガイド | [DEPLOYMENT.md](./docs/DEPLOYMENT.md) | Firebase デプロイ手順 |
| 内部設計 | [アーキテクチャ概要](./docs/内部設計/アーキテクチャ概要.md) | レイヤー構成・依存方向・エラー変換 |
| 内部設計 | [ドメインモデル](./docs/内部設計/ドメインモデル.md) | エンティティ関係・Firestore パス階層 |
| 内部設計 | [ユースケース](./docs/内部設計/ユースケース.md) | 機能一覧・画面パス対応 |
| 内部設計 | [データフロー](./docs/内部設計/データフロー.md) | 購読・招待コード参加フロー |
| 内部設計 | [状態遷移](./docs/内部設計/状態遷移.md) | Item / 認証 / グループのライフサイクル |
| 外部仕様 | [エラー仕様](./docs/外部仕様/エラー仕様.md) | AppError コード一覧・i18n キー対応 |
| 開発計画 | [スプリント計画](./docs/開発計画/スプリント計画.md) | ロードマップ・Story 一覧 |
| 残作業 | [REMAINING_TASKS.md](./docs/REMAINING_TASKS.md) | デプロイ準備・残ユーザー作業 |

## 残作業・デプロイ準備

詳細は [docs/REMAINING_TASKS.md](./docs/REMAINING_TASKS.md) を参照してください。

- Firebase プロジェクト接続: 完了（`firebase_options.dart` に実値投入・コミット済み）
- Firestore ルール: `firestore.rules` 同梱済み（`firebase deploy --only firestore:rules` の実行は要ユーザー作業）
- Android ビルド: Docker に Android SDK 組込済み・実機検証およびリリース署名設定は未（[docs/ANDROID_DOCKER.md](./docs/ANDROID_DOCKER.md)）
- iOS ビルド: scaffold あり・`flutterfire configure --platforms=ios` 後に Xcode で署名・実機ビルド検証が必要
- Web: ビルド検証済み / Firebase Hosting デプロイ: 未実施
