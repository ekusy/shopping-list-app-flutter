# デバッグ実行

Flutter Web アプリのデバッグ方法をまとめた手順書。

関連ドキュメント:
- ローカル開発 (ビルド & 実行): `docs/DEVELOPMENT.md`
- 本番デプロイ: `docs/DEPLOYMENT.md`

## デバッグ方法の選択

| 目的 | 使うツール |
|---|---|
| ウィジェットツリーの確認 / レイアウト調査 | Flutter DevTools (Inspector) |
| パフォーマンス計測 (フレームレート / ビルド回数) | Flutter DevTools (Performance) |
| HTTP / Firestore 通信の確認 | Chrome DevTools (Network) |
| 値の確認 / ステップ実行 | VS Code or Flutter DevTools (Debugger) |
| ログ出力の確認 | `debugPrint` + ブラウザコンソール / DevTools (Logging) |
| Firestore / Auth の通信を本番から切り離す | Firebase Emulator Suite |
| Firestore セキュリティルールの動作確認 | Firebase Console の Rules Playground |

---

## 1. Flutter DevTools (基本)

`flutter run` 起動時に出力される DevTools URL をホストのブラウザで開く。

```bash
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000
```

起動ログに以下のような行が出る:

```
The Flutter DevTools debugger and profiler on Web Server is available at:
http://127.0.0.1:9100?uri=http://127.0.0.1:xxxx
```

DevTools の port (9100) は `docker-compose.yml` で公開済みなので、
ホストのブラウザでそのまま URL を開ける。

> DevTools がコンテナ内で `127.0.0.1` のみで待ち受ける場合、
> ホストから繋がらないことがある。その時は `flutter run` に
> `--devtools-server-address=0.0.0.0` を追加するか、Chrome DevTools での
> デバッグに切り替える。

### DevTools の主要タブ

- **Inspector**: ウィジェットツリーを可視化。レイアウトの問題やパディングを目視確認
- **Performance**: フレーム時間、ビルド回数を計測。`Rebuild Stats` で過剰な rebuild を検出
- **Memory**: メモリリーク調査
- **Network**: HTTP リクエスト一覧 (Web では Chrome DevTools のほうが見やすい)
- **Logger**: `debugPrint` / `log()` の出力を確認

---

## 2. `debugPrint` / `log()` でのログ確認

最も手早い方法。Web ターゲットでは出力先は **Chrome DevTools の Console** と
`flutter run` のターミナルの両方。

```dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

// シンプルなログ (1行)
debugPrint('Loaded ${items.length} items');

// 構造化ログ (DevTools の Logger タブで見やすい)
developer.log(
  'Item synced',
  name: 'shopping_list.sync',
  error: error,
  stackTrace: stack,
);
```

`debugPrint` はリリースビルドでも残るが、`assert` の中に入れたものは
リリース時に最適化で除去される:

```dart
assert(() {
  debugPrint('Debug-only log');
  return true;
}());
```

---

## 3. Chrome DevTools (Web 特有)

Web ターゲットなので、ブラウザの標準 DevTools がそのまま使える。
`F12` で開く。

- **Console**: `print` / `debugPrint` の出力
- **Network**: Firestore の REST/WebSocket 通信、画像読み込みなど
  - Firestore は WebSocket (`google.firestore.v1.Firestore/Listen`) を使うので
    "WS" タブでフィルタすると見やすい
- **Application**: localStorage, IndexedDB, Cookie の確認
  - Firebase Auth のセッションは IndexedDB に保存される
- **Sources**: ソースマップが効いていれば Dart ソース上にブレークポイントを置ける
  - リリースビルドでは効かない、`flutter run` (debug) で起動した時のみ

---

## 4. VS Code でのブレークポイント

Docker 越しのデバッガ接続は手数が多いので、**コンテナ内の `dds`
(Dart Debug Service) のポートをホストに公開し、VS Code から接続** する流れ。

### `.vscode/launch.json` の例

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Docker Flutter (Web)",
      "type": "dart",
      "request": "attach",
      "vmServiceUri": "http://localhost:8181/"
    }
  ]
}
```

### 起動コマンド

DDS のポート (8181) は `docker-compose.yml` で公開済み。
ポート番号を固定するため、起動時に明示する:

```bash
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000 \
  --dds-port=8181 --host-vmservice-port=8181
```

起動後、VS Code の Run and Debug から "Attach to Docker Flutter (Web)" を選んで
接続。ブレークポイントが効くようになる。

> Web ターゲットでのデバッガ接続は Native ターゲットより不安定なことがある。
> 動かない時はまず Chrome DevTools の Sources でのブレークポイントを試す。

---

## 5. Firebase Emulator Suite

本番 Firestore を汚さずに動作確認したい時に使う。
`firebase.json` で Firestore (8080) と Auth (9099) のポートは設定済み。

エミュレータの各ポート (4000 / 8080 / 9099) は `docker-compose.yml` で
公開済みなので、追加のポート指定なしで起動できる。

### エミュレータ起動

```bash
docker compose run --rm --service-ports flutter firebase emulators:start
```

### アプリ側の接続コード

`lib/main.dart` には既に接続コードが入っており、`--dart-define=USE_EMULATOR=true`
を付けて起動するとエミュレータに繋がる。

```bash
docker compose run --rm --service-ports flutter \
  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000 \
  --dart-define=USE_EMULATOR=true
```

接続先ホストを変えたい時 (例: 別マシンのエミュレータを使うなど):

```bash
... --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.1.10
```

> エミュレータの host は **ブラウザから見た host** であることに注意。
> Flutter Web は実際にはブラウザが直接 Firestore に繋ぐので、
> `localhost:8080` が **ホスト側 (= Docker の 8080 ポート)** を指す。
> `docker-compose.yml` のポートマッピングが効くのはこのため。

### Emulator UI

ブラウザで `http://localhost:4000` にアクセス。
データの追加・削除、Auth ユーザーの作成などが GUI で可能。

> `firebase.json` で `"ui":{"enabled":false}` になっているので、
> 使いたい場合は `true` に変更する。

---

## 6. Firestore セキュリティルールのデバッグ

### Rules Playground (Firebase Console)

[Firebase Console](https://console.firebase.google.com/project/household-shopping-list-f7c12/firestore/rules) →
Rules タブ → 右上の "Rules Playground"。
特定のドキュメントパス・認証状態に対してルールがどう評価されるかを試せる。

### エミュレータでのルールテスト

エミュレータ起動中はリクエストが Console の **Firestore → Requests** タブに
記録される。`Denied` のリクエストは赤くハイライトされ、どのルール行で
弾かれたかが分かる。

---

## 7. Riverpod の状態デバッグ

`ProviderScope` に `ProviderObserver` を渡すと、すべての Provider の
変更ログが取れる。

```dart
class _LoggingObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    debugPrint('[Riverpod] ${provider.name ?? provider.runtimeType} '
        '$previousValue → $newValue');
  }
}

// main.dart
runApp(
  ProviderScope(
    observers: [_LoggingObserver()],
    child: const ShoppingListApp(),
  ),
);
```

DevTools には Riverpod 専用タブは無いので、ログ出力で確認するのが基本。

---

## 8. go_router のデバッグ

ルーティングの遷移ログを出すには、Router 設定で `debugLogDiagnostics: true` を有効化。

```dart
// presentation/router/app_router.dart
GoRouter(
  debugLogDiagnostics: true,
  // ...
);
```

これで `navigate` / `redirect` のたびにコンソールにログが出る。

---

## 9. パフォーマンス / リビルド回数の確認

`flutter run` のターミナルで `P` を押すと **Performance Overlay** の ON/OFF。
画面右上に Build / Raster のフレーム時間が表示される。

`Rebuild Stats` で過剰な再ビルドを検出するには DevTools の
Performance タブ → 右上の歯車 → "Track Widget Rebuilds" を有効化。

---

## トラブルシューティング

| 症状 | 原因 / 対処 |
|---|---|
| DevTools の URL を開いても "Could not connect" | ポートをホストに公開していない。`-p 9100:9100` 等を追加 |
| Chrome DevTools の Sources に Dart ソースが出ない | リリースビルドではソースマップが無効。`flutter run` (debug) で起動する |
| ブレークポイントが「Unbound」表示になる | ホットリロード後のソースとブレークポイントの行ずれ。`R` でフルリスタート |
| エミュレータに繋がらず本番 Firestore に書かれてしまう | 接続コードが入っていない / `--dart-define=USE_EMULATOR=true` を忘れている |
| エミュレータが "address already in use" | 前回のエミュレータプロセスが残っている。`docker compose down` で全停止 |
| `debugPrint` の出力が見当たらない | Chrome DevTools の Console は Verbose レベルが非表示の場合がある。フィルタ設定を確認 |
