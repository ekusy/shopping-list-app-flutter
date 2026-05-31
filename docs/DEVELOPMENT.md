# ローカル開発 (ビルド & 実行)

Flutter Web アプリの日常的な開発作業をまとめた手順書。
すべて Docker コンテナ内で実行する前提 (ホストに Flutter / Dart のインストール不要)。

関連ドキュメント:
- デバッグ実行: `docs/DEBUGGING.md`
- 本番デプロイ: `docs/DEPLOYMENT.md`

## 前提

- Docker Desktop (Windows) または Docker Engine + Compose v2 (Linux/Mac)
- 各コマンドは `shopping-list-app-flutter/` (このリポジトリのルート) で実行する

## 初回セットアップ

イメージをビルドする (Flutter SDK のダウンロード含むため数分かかる)。

```bash
docker compose build
```

依存パッケージを取得 (`pubspec.lock` の通りに解決)。

```bash
docker compose run --rm flutter flutter pub get
```

## 開発サーバー起動 (ホットリロード有効)

```bash
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
```

- ホストのブラウザで `http://localhost:5000` にアクセス
- ターミナルで `r` 押下 → ホットリロード
- `R` 押下 → フルリスタート (state を破棄して再起動)
- `q` 押下 → サーバー停止

> `--service-ports` を付けないと `docker-compose.yml` 側で定義した
> `5000:5000` のポートマッピングが有効にならない (`run` の挙動)。

### 起動オプションのバリエーション

```bash
# プロファイルモード (リリースに近いパフォーマンス、ただし debugger 接続可)
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --profile --web-hostname=0.0.0.0 --web-port=5000

# 起動時引数を渡す (例: --dart-define で環境フラグ)
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000 \
  --dart-define=USE_EMULATOR=true
```

## 静的解析・フォーマット

```bash
# 解析
docker compose run --rm flutter flutter analyze

# フォーマット (書き換える)
docker compose run --rm flutter dart format lib test

# フォーマットチェックのみ (CI 用、差分があれば exit 1)
docker compose run --rm flutter dart format --output=none --set-exit-if-changed lib test
```

## テスト

```bash
# 全テスト
docker compose run --rm flutter flutter test

# 特定ディレクトリ
docker compose run --rm flutter flutter test test/widgets/

# 特定ファイル
docker compose run --rm flutter flutter test test/widgets/item_card_test.dart

# 名前で絞り込み
docker compose run --rm flutter flutter test --plain-name "checked state"

# カバレッジ取得 (coverage/lcov.info に出力)
docker compose run --rm flutter flutter test --coverage
```

カバレッジを HTML で見たい時は `lcov` を使う:

```bash
docker compose run --rm flutter bash -c \
  "apt-get update && apt-get install -y lcov && genhtml coverage/lcov.info -o coverage/html"
# coverage/html/index.html をブラウザで開く
```

## 依存管理

```bash
# pubspec.yaml に追加したパッケージを解決
docker compose run --rm flutter flutter pub get

# 互換性を保ったまま最新化
docker compose run --rm flutter flutter pub upgrade

# 新しいバージョンの提示 (実際には更新しない)
docker compose run --rm flutter flutter pub outdated

# パッケージ追加
docker compose run --rm flutter flutter pub add <package_name>
docker compose run --rm flutter flutter pub add --dev <package_name>
```

## リリースビルド

```bash
docker compose run --rm flutter flutter build web --release
```

出力先は **`build_vol` ボリューム** (ホスト FS には現れない)。
詳細は `docs/DEPLOYMENT.md` の「仕組み」を参照。

### ビルドモード比較

| モード | コマンド | 用途 |
|---|---|---|
| debug | `flutter run` (デフォルト) | 日常開発。ホットリロード、アサーション有効 |
| profile | `flutter run --profile` / `flutter build web --profile` | パフォーマンス計測 |
| release | `flutter build web --release` | 本番配布 (最適化、tree-shaking) |

## コンテナに直接入って作業する

`flutter` / `dart` / `firebase` などコマンドを連続で叩きたい時は対話シェルが楽。

```bash
docker compose run --rm flutter bash
```

`exit` で抜けると `--rm` によりコンテナは破棄されるが、`build_vol` `pub_cache`
`dart_tool_vol` の名前付きボリュームは残る。

## ボリュームの管理

| ボリューム | 中身 | 削除して困ること |
|---|---|---|
| `pub_cache` | pub パッケージのキャッシュ | 次回 `pub get` で再ダウンロード (数分) |
| `build_vol` | Web ビルド成果物 (`build/`) | 次回 `flutter build` で再生成 |
| `dart_tool_vol` | Dart ツールの内部状態 (`.dart_tool/`) | 次回ビルド時に再生成 |

### すべて削除してリセット

```bash
docker compose down -v
```

### 個別に削除

```bash
docker volume rm shopping-list-app-flutter_build_vol
docker volume rm shopping-list-app-flutter_pub_cache
docker volume rm shopping-list-app-flutter_dart_tool_vol
```

### イメージから作り直す (Dockerfile を変更した時など)

```bash
docker compose build --no-cache
```

## アセット (翻訳ファイル等) の追加

`assets/translations/` に JSON を追加した場合、`pubspec.yaml` の
`flutter.assets` に列挙されていれば自動的に取り込まれる。
追加・削除した時は `pub get` ではなく、`flutter run` / `flutter build` で
再起動が必要。ホットリロードでは反映されないこともあるので、
`R` (フルリスタート) を使う。

## よくあるトラブル

| 症状 | 対処 |
|---|---|
| `pub get` で `package_config.json` 関連のエラー | `docker volume rm shopping-list-app-flutter_dart_tool_vol` してから再実行 |
| ホットリロードが効かない | `R` でフルリスタート / それでもダメなら `q` → 再起動 |
| `flutter run` が "Waiting for connection from debug service" で止まる | `--web-hostname=0.0.0.0` を必ず付ける (デフォルトの localhost ではコンテナ外から繋がらない) |
| ブラウザに古い JS がキャッシュされる | シークレットウィンドウ or DevTools で "Disable cache" |
| `Failed to compile`: import が解決できない | `flutter pub get` 忘れ。再実行 |
| Firebase 初期化エラー (UI は起動するが Firestore が動かない) | `lib/firebase_options.dart` が空テンプレートの可能性。 `flutterfire configure` をホスト側で実行 |
