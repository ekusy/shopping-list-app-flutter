# Firebase デプロイ手順

Flutter Web アプリを Firebase Hosting にデプロイする手順書。
Docker コンテナを介したデプロイを前提とし、認証情報は `.env` で外部化、
プロジェクト設定は `.firebaserc` / `firebase.json` でリポジトリに保存する。

## 構成

| 項目 | 値 |
|---|---|
| Firebase プロジェクト ID | `household-shopping-list-f7c12` |
| 公開ディレクトリ | `build/web` (Docker 名前付きボリューム `build_vol` 上) |
| プラン | Spark (無料枠) |
| デプロイ実行環境 | `docker compose run --rm flutter ...` |

## Git コミットの可否

> **重要**: デプロイ関連ファイルは「機密 / 非機密」が混在する。表の通り扱うこと。

| パス | コミット | 備考 |
|---|---|---|
| `firebase.json` | ✅ する | Hosting / Firestore / Emulator の設定。機密値なし |
| `firestore.rules` | ✅ する | セキュリティルール本体。これを git で管理するのが目的 |
| `.firebaserc` | ✅ する | プロジェクトエイリアスのみ。プロジェクト ID は `firebase.json` でも公開済み |
| `lib/firebase_options.dart` | ✅ する | Firebase Web SDK の API キーを含むが、これは公開前提の識別子。実際の防御は Firestore ルール + Auth で行う |
| `.env.example` | ✅ する | テンプレート。プレースホルダのみで実値は含めない |
| `docs/DEPLOYMENT.md` | ✅ する | この手順書 |
| `.env` | ❌ しない | `FIREBASE_TOKEN` を含む。`.gitignore` 済 |
| `.firebase/` | ❌ しない | デプロイキャッシュ。`.gitignore` 済 |
| `build/` | ❌ しない | ビルド成果物。`.gitignore` 済 |
| `~/.config/configstore/firebase-tools.json` | ❌ しない | CLI のログイン状態。コンテナ外で保持されるホスト側ファイル |

---

## 初回セットアップ (一度だけ)

### 1. `.env` を作成

`.env.example` をコピーして `.env` を作る。

```bash
cp .env.example .env
```

### 2. Firebase CI トークンを取得して `.env` に保存

非対話デプロイ用のトークンを発行する。**ホストの Firebase CLI** で実行するのが最も簡単 (コンテナ内でも `--no-localhost` 付きで可能だが手数が増える)。

ホスト側に Firebase CLI が無い場合は、コンテナで一度だけログインして取得する:

```bash
docker compose run --rm flutter bash -c "firebase login:ci --no-localhost"
```

表示された URL をホストのブラウザで開いて Google 認証 → コンソールに表示された認可コードを貼り付け → 標準出力に `1//0abc...XYZ` のような **リフレッシュトークン** が表示される。

そのトークンを `.env` に貼り付ける:

```env
FIREBASE_TOKEN=1//0abc...XYZ
```

> このトークンは Google アカウントの権限と同等。**絶対にコミット・共有しないこと**。
> 取り消したい場合は `firebase logout --token "1//0abc..."` で無効化できる。

### 3. `.firebaserc` を作成

プロジェクトエイリアスをファイル化してコミットする。以下の内容で
リポジトリルートに `.firebaserc` を作る (この手順は手動コミット推奨):

```json
{
  "projects": {
    "default": "household-shopping-list-f7c12"
  }
}
```

または対話的に生成:

```bash
docker compose run --rm flutter firebase use --add --token "$FIREBASE_TOKEN"
```

### 4. Firebase Console で Hosting を有効化

[Firebase Console](https://console.firebase.google.com/project/household-shopping-list-f7c12/hosting) →
Hosting → 「始める」をクリック (UI 上の案内は無視して構わない。実際のデプロイは CLI から行う)。

---

## 通常のデプロイ

`.env` と `.firebaserc` が揃っていれば、以下 2 コマンドで完結する。

```bash
# 1. Web ビルド
docker compose run --rm flutter flutter build web --release

# 2. Hosting にデプロイ
docker compose run --rm flutter firebase deploy --only hosting
```

成功すると `Hosting URL: https://household-shopping-list-f7c12.web.app` が表示される。

### Firestore ルールも一緒に更新したい場合

```bash
docker compose run --rm flutter firebase deploy --only hosting,firestore:rules
```

### プレビューチャネルにデプロイ (本番反映前の動作確認)

```bash
docker compose run --rm flutter firebase hosting:channel:deploy preview-$(date +%Y%m%d)
```

7 日間有効なプレビュー URL が発行される。本番 URL とは別なので安全に確認可能。

---

## 仕組み

### 環境変数の受け渡し

`docker-compose.yml` の `env_file: - .env` により、ホストの `.env` の値が
コンテナ内に環境変数として注入される。Firebase CLI は `FIREBASE_TOKEN` を
自動で検知して非対話モードで動作するため、毎回ログインする必要がない。

### ビルド出力の保持

`build/` は名前付きボリューム `build_vol` 上にあり、`docker compose run --rm` で
コンテナを破棄してもボリュームは残る。よって `flutter build web` と
`firebase deploy` を別コマンドで実行しても同じ成果物を参照できる。

クリーンビルドしたい時:

```bash
docker compose down -v   # ボリュームごと破棄 (pub_cache も消える点に注意)
# または特定のボリュームのみ:
docker volume rm shopping-list-app-flutter_build_vol
```

---

## トラブルシューティング

| 症状 | 原因 / 対処 |
|---|---|
| `Error: Failed to authenticate, have you run firebase login?` | `.env` の `FIREBASE_TOKEN` が空 or 期限切れ。再発行する |
| `Error: HTTP Error: 403, The caller does not have permission` | トークンを発行した Google アカウントがプロジェクトに招待されていない。Firebase Console でメンバー追加 |
| `Error: Specified public directory 'build/web' does not exist` | `flutter build web --release` を実行していない |
| デプロイは成功したが古い内容が表示される | ブラウザのキャッシュ。シークレットウィンドウで確認 |
| `firebase deploy` が `Reading firebase.json` でハングする | `.firebaserc` が無い。「初回セットアップ 3」を実施 |

---

## 関連ファイル

- `firebase.json` — Hosting / Firestore / Emulators の設定
- `firestore.rules` — Firestore セキュリティルール
- `.firebaserc` — プロジェクトエイリアス
- `.env.example` — 環境変数テンプレート
- `docker-compose.yml` — コンテナ定義 (`env_file` で `.env` を読み込み)
