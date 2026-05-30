# shopping-list-app-flutter

家族で共有する買い物リストアプリ（Flutter 版）。
「気づいたら記録、記録したら自動で共有、『買います』『買った』で行動も共有」。
[shopping-list-app](https://github.com/ekusy/shopping-list-app)（Expo / React Native）を
Flutter へ移植したものです。

## 技術スタック

| 分類 | 技術 |
|---|---|
| フレームワーク | Flutter 3.44 / Dart 3.12 |
| 状態管理 / DI | flutter_riverpod（MVVM の ViewModel を Provider で表現） |
| ルーティング | go_router（認証ガード付き宣言的ルーティング） |
| バックエンド | Firebase（firebase_auth / cloud_firestore / firebase_storage） |
| i18n | easy_localization（日本語 / 英語、`assets/translations/*.json`） |
| 画像 | image_picker + image（選択・リサイズ） |
| その他 | connectivity_plus（オフライン検知）、share_plus（招待共有） |
| テスト | flutter_test + fake_cloud_firestore + firebase_auth_mocks + mocktail |

> 元の `*.native.ts` / `*.ts` のプラットフォーム分岐は、FlutterFire が Web/ネイティブを
> 統一して扱うため廃止しています。#142 で廃止済みの `lists` 機能も移植対象外です。

## アーキテクチャ

クリーンアーキテクチャ + MVVM。依存方向は外側 → 内側（presentation → domain ← data）。

```
lib/
├── core/            # 横断的関心事: errors / constants / theme / utils
├── domain/          # entities（不変モデル）+ abstract repositories（インターフェース）
├── data/            # Firestore/Auth/Storage の repository 実装・mapper・error converter
├── presentation/    # providers(ViewModel) / router / screens / widgets / utils
├── firebase_options.dart   # ★テンプレート（プレースホルダのみ。要差し替え）
└── main.dart        # エントリポイント（Firebase / easy_localization 初期化）
```

- ベンダー依存（Firebase）は `domain/repositories` の抽象インターフェース越しに利用し、
  実装を `data/` に隔離。テストではモック実装に差し替え可能。
- エンティティは不変（`copyWith` で複製）。

## クイックスタート

前提: Flutter SDK 3.44 以上。WSL 環境では Windows 側の SDK ではなく Linux 版
（例: `/snap/bin/flutter`）を使用すること。

```bash
# 1. 依存取得
flutter pub get

# 2. Firebase 設定ファイルを再生成（クローン直後など google-services.json がない場合）
#    詳細は docs/REMAINING_TASKS.md を参照
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=household-shopping-list-f7c12 \
  --platforms=android,ios,web \
  --android-package-name=com.ekusy.shopping_list_app \
  --ios-bundle-id=com.ekusy.shoppingListApp \
  --yes

# 3. 起動
flutter run -d chrome      # Web（Chrome が必要）
flutter run                # 接続中の Android/iOS 端末・エミュレータ
```

## 開発コマンド

### 解析・フォーマット

```bash
flutter analyze                                              # lint（flutter_lints）
dart format lib test                                         # コードフォーマット（上書き）
dart format --output=none --set-exit-if-changed lib test     # フォーマットチェックのみ（CI用）
```

### テスト

```bash
flutter test                           # 全テスト
flutter test test/widgets/             # ウィジェットテストのみ
flutter test --name "テスト名"          # 名前でフィルタ
flutter test --coverage                # カバレッジ収集 → coverage/lcov.info
```

### 起動

```bash
flutter run -d chrome                  # Web・デバッグ起動（ホットリロード有効）
flutter run -d chrome --web-port=5000  # ポート指定
flutter run -d chrome --release        # リリースモードで動作確認
flutter run                            # 接続中の Android/iOS 端末
```

### ビルド

```bash
flutter build web                      # Web 静的ビルド → build/web/
flutter build apk                      # Android APK（要 Android SDK）
flutter build appbundle                # Android App Bundle（Play 配布用）
```

### Firebase

```bash
firebase deploy --only firestore:rules # Firestore セキュリティルール
firebase deploy --only hosting         # Web を Firebase Hosting にデプロイ
firebase emulators:start               # ローカルエミュレータ（Firestore / Auth）
```

## 主な機能

- **認証**: サインアップ（ユーザードキュメント作成・任意の表示名）、ログイン、ログアウト、
  プロフィール編集（アバター画像アップロード）、アカウント削除（オーナーはガード）
- **グループ**: 作成（既定タグ「急ぎ」「まとめ買い」付き）、改名、退出（オーナー不可）、
  解散、切替、招待コード参加、メンバー削除、招待コード/URL 共有
- **タグ**: 追加（プラン上限: 無料5 / 有料50）、改名、削除（紐づくアイテムのタグを解除）、
  OR フィルタ
- **アイテム**: 追加 / クイック追加 / 編集 / 削除 / 購入済み切替 / 「買います」宣言 /
  一括タグ付け / 購入済み一括削除 / 並べ替え / 同期待ちバッジ
- **その他**: オフライン対応とネットワーク状態表示、通知トグル（フラグのみ）、i18n（ja/en）

## テスト

```bash
flutter test
```

`test/` 配下に core / data / domain / presentation / widgets のテストを配置。
ウィジェットテストでは `test/helpers/test_localization.dart` の同期アセットローダーを使い、
`easy_localization` を 1 ファイル内の複数テストで安定描画させています。

## 残作業・デプロイ準備

Firebase 接続・Firestore ルールデプロイ済み。Android ビルドは環境依存のため未検証。
詳細は [docs/REMAINING_TASKS.md](./docs/REMAINING_TASKS.md) を参照してください。
