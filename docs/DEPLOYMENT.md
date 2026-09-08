# Firebase デプロイ手順

Flutter Web アプリ (Hosting) と Cloud Functions を Firebase にデプロイする手順書。
Docker コンテナを介したデプロイを前提とし、認証情報はリポジトリ外 (`.env` またはホストの ADC) に置き、
プロジェクト設定は `.firebaserc` / `firebase.json` でリポジトリに保存する。

## 構成

| 項目 | 値 |
|---|---|
| Firebase プロジェクト ID | `household-shopping-list-f7c12` |
| 公開ディレクトリ | `build/web` (Docker 名前付きボリューム `build_vol` 上) |
| プラン | Blaze (Functions / Vertex AI 利用のため) |
| デプロイ実行環境 (Hosting / Firestore / Storage) | `docker compose run --rm flutter ...` |
| デプロイ実行環境 (Functions) | `docker compose run --rm functions ...` (CLAUDE.md / #33 Q7) |

## Git コミットの可否

> **重要**: デプロイ関連ファイルは「機密 / 非機密」が混在する。表の通り扱うこと。

| パス | コミット | 備考 |
|---|---|---|
| `firebase.json` | ✅ する | Hosting / Firestore / Storage / Functions / Emulator の設定。機密値なし |
| `firestore.rules` | ✅ する | セキュリティルール本体。これを git で管理するのが目的 |
| `.firebaserc` | ✅ する | プロジェクトエイリアスのみ。プロジェクト ID は `firebase.json` でも公開済み |
| `lib/firebase_options.dart` | ✅ する | Firebase Web SDK の API キーを含むが、これは公開前提の識別子。実際の防御は Firestore ルール + Auth で行う |
| `.env.example` | ✅ する | テンプレート。プレースホルダのみで実値は含めない |
| `docs/DEPLOYMENT.md` | ✅ する | この手順書 |
| `.env` | ❌ しない | `FIREBASE_TOKEN` を含む。`.gitignore` 済 |
| `.firebase/` | ❌ しない | デプロイキャッシュ。`.gitignore` 済 |
| `build/` | ❌ しない | ビルド成果物。`.gitignore` 済 |
| `~/.config/configstore/firebase-tools.json` | ❌ しない | CLI のログイン状態。コンテナ外で保持されるホスト側ファイル |
| `~/.config/gcloud/` | ❌ しない | gcloud の認証情報 (ADC 含む)。ホスト側にのみ置き、コンテナへは読み取り専用マウントで渡す |

---

## 認証方式

デプロイの認証には 2 方式ある。**どちらか一方を用意すればよい**。

| 方式 | 準備 | 向いている用途 |
|---|---|---|
| **A. ADC (Application Default Credentials)** | ホストに gcloud CLI + `gcloud auth application-default login` | ホストで gcloud を使っている場合。トークンの発行・保管が不要 |
| **B. `FIREBASE_TOKEN`** | `firebase login:ci` でリフレッシュトークンを発行し `.env` に保存 | CI / gcloud を入れたくない環境 |

> **対話認証はコンテナ内・エージェント経由では実行できない**。`gcloud auth application-default login` も
> `firebase login:ci` もブラウザ認証と認可コードの貼り付けを伴うため、**ホストのターミナルで実行する**こと
> (stdin の無い環境では `EOFError` でクラッシュする)。

---

## 初回セットアップ (一度だけ)

### 1-A. ADC を用意する (方式 A)

ホストのターミナルで一度だけ実行する。

```bash
brew install --cask gcloud-cli   # 未導入の場合。cask 名は google-cloud-cli ではない
gcloud auth application-default login
gcloud auth application-default set-quota-project household-shopping-list-f7c12
```

`~/.config/gcloud/application_default_credentials.json` が生成される。
これをコンテナに読み取り専用でマウントし、`GOOGLE_APPLICATION_CREDENTIALS` で指す (デプロイ手順は後述)。

> gcloud は Homebrew cask の場合 PATH に入らない。`/opt/homebrew/share/google-cloud-sdk/bin` を
> PATH に追加するか、`source /opt/homebrew/share/google-cloud-sdk/path.zsh.inc` を `~/.zshrc` に書く。

### 1-B. Firebase CI トークンを取得して `.env` に保存 (方式 B)

`.env.example` をコピーして `.env` を作る。

```bash
cp .env.example .env
```

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

### 2. `.firebaserc` を作成

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

### 3. Firebase Console で Hosting を有効化

[Firebase Console](https://console.firebase.google.com/project/household-shopping-list-f7c12/hosting) →
Hosting → 「始める」をクリック (UI 上の案内は無視して構わない。実際のデプロイは CLI から行う)。

---

## 通常のデプロイ (Hosting)

`.firebaserc` と認証情報 (方式 A または B) が揃っていれば、以下 2 コマンドで完結する。

```bash
# 1. Web ビルド
docker compose run --rm flutter flutter build web --release

# 2. Hosting にデプロイ
docker compose run --rm flutter firebase deploy --only hosting
```

成功すると `Hosting URL: https://household-shopping-list-f7c12.web.app` が表示される。

方式 A (ADC) の場合は、ホストの認証情報をマウントして渡す:

```bash
docker compose run --rm \
  -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
  flutter firebase deploy --only hosting
```

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

## Cloud Functions のデプロイ

**必ず `functions` サービス (node:22) から実行する**。flutter サービスからは実行しないこと
(`firebase.json` の `functions.predeploy` が lint → build を走らせるが、flutter イメージの Node/npm が古く
`/bin/sh: 0: Illegal option --` で失敗する。また `functions/node_modules` は専用ボリューム上にあり
flutter コンテナにはマウントされていない)。`firebase.json` はリポジトリルート (`/app`) にあるため `cd /app` する。

```bash
# 全関数をデプロイ (方式 A: ADC)
docker compose run --rm \
  -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
  functions sh -c "cd /app && npx --yes firebase-tools deploy --only functions --non-interactive"

# 特定の関数だけ (影響範囲を絞りたい場合)
docker compose run --rm \
  -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
  functions sh -c "cd /app && npx --yes firebase-tools deploy --only functions:weeklySuggestions --non-interactive"
```

方式 B (`FIREBASE_TOKEN`) の場合は `-v` / `-e` を省略できる (compose が `.env` から注入する)。

### デプロイ後の確認

`gcloud` をホストに導入している場合、ログとスケジュール実行を CLI から確認できる。

```bash
# デプロイ済み関数の一覧 (更新時刻を含む)
gcloud functions list

# ログ (2nd gen でもそのまま読める)
gcloud functions logs read weeklySuggestions --region=asia-northeast1 --limit=20

# 構造化ログの絞り込み (service_name は全小文字)
gcloud logging read 'resource.labels.service_name="weeklysuggestions" AND jsonPayload.message:"run summary"' \
  --limit=5 --freshness=8d \
  --format='value(timestamp, jsonPayload.totalGroups, jsonPayload.generated, jsonPayload.skipped, jsonPayload.failed)'

# 週次ジョブの手動実行 (提案は ISO 週 ID 単位の上書きなので冪等)
gcloud scheduler jobs run firebase-schedule-weeklySuggestions-asia-northeast1 --location=asia-northeast1
```

---

## 仕組み

### 認証情報の受け渡し

**方式 B (`FIREBASE_TOKEN`)**: `docker-compose.yml` の `environment: FIREBASE_TOKEN=${FIREBASE_TOKEN:-}` により、
ホストの環境変数 (または compose が自動読込する `.env`) からコンテナへ
`FIREBASE_TOKEN` が渡される。Firebase CLI は `FIREBASE_TOKEN` を自動で検知して
非対話モードで動作するため、毎回ログインする必要がない。

`.env` が存在しない場合は空文字が渡されるだけで、エラーにはならない
(デプロイ以外の通常作業を妨げない)。

**方式 A (ADC)**: ホストの `~/.config/gcloud` を読み取り専用でマウントし、
`GOOGLE_APPLICATION_CREDENTIALS` に認証情報ファイルのパスを渡す。firebase-tools は
これを Application Default Credentials として解釈するため、ユーザーアカウントの ADC でも動作する
(サービスアカウントキーは不要)。`flutter` / `functions` どちらのサービスでも同じ方法で使える。

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
| `Error: Failed to authenticate, have you run firebase login?` | 方式 B なら `.env` の `FIREBASE_TOKEN` が空 or 期限切れ。方式 A なら `-v` / `-e` の指定漏れ、または ADC 未取得 |
| `Error: HTTP Error: 403, The caller does not have permission` | 認証に使った Google アカウントがプロジェクトに招待されていない。Firebase Console でメンバー追加 |
| `Error: Specified public directory 'build/web' does not exist` | `flutter build web --release` を実行していない |
| デプロイは成功したが古い内容が表示される | ブラウザのキャッシュ。シークレットウィンドウで確認 |
| `firebase deploy` が `Reading firebase.json` でハングする | `.firebaserc` が無い。「初回セットアップ 2」を実施 |
| Functions の predeploy が `/bin/sh: 0: Illegal option --` で落ちる | flutter サービスから実行している。`functions` サービス (node:22) から実行する |
| `EOFError: EOF when reading a line` (gcloud / firebase のログイン中) | stdin の無い環境で対話認証を実行している。ホストのターミナルで実行する |

---

## 関連ファイル

- `firebase.json` — Hosting / Firestore / Functions / Emulators の設定
- `firestore.rules` — Firestore セキュリティルール
- `storage.rules` — Storage セキュリティルール
- `.firebaserc` — プロジェクトエイリアス
- `.env.example` — 環境変数テンプレート
- `docker-compose.yml` — コンテナ定義 (`environment` で `FIREBASE_TOKEN` を注入)
- `functions/README.md` — Cloud Functions の構成・開発手順
