# Android 開発手順（Docker 中心）

Android のビルド・デバッグ・インストールを Docker コンテナで完結させるための手順。
Windows / macOS / Linux ホスト共通だが、本ドキュメントの実例は Windows + PowerShell。

## アーキテクチャ

```
┌─────────────────────────┐      ┌────────────────────────────────┐
│ ホスト OS                │      │ flutter コンテナ                 │
│                         │ TCP  │                                │
│  adb server (:5037) ◄───┼──────┤  flutter / gradle / adb client │
│   │                     │      │  ANDROID_HOME=/opt/android-sdk │
│   ├─ USB 実機           │      │  JDK 21                        │
│   └─ Wi-Fi 実機         │      │                                │
└─────────────────────────┘      └────────────────────────────────┘
```

- **コンテナ内**: Flutter / Android SDK / JDK / Gradle / Firebase CLI
- **ホスト**: `platform-tools` の `adb` のみ（USB / Wi-Fi デバイスとの物理通信を担当）
- **接続**: コンテナの `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037` で
  ホストの adb server を経由してデバイスへ到達

ホストに置く必要があるのは `adb` 単体（約 15 MB）のみで、
Android Studio や SDK の重量導入はホスト側に不要。

> **エミュレータについて**: Windows Docker Desktop は KVM を提供しないため、
> Android エミュレータをコンテナ内で実用速度で動かすことは出来ない。
> 実機（USB or Wi-Fi）または **ホスト側で起動したエミュレータ** に対して
> 同じ adb server 経由でつなぐ運用とする。

---

## 0. 初回セットアップ

### 0-1. イメージビルド（Android SDK 込み）

```powershell
docker compose build
```

初回は Android SDK / JDK / Flutter のダウンロードで 5–15 分かかる。
2 回目以降はキャッシュが効く。

### 0-2. ホストに adb を導入

#### Windows（推奨：Chocolatey）

```powershell
choco install adb -y
```

または Google 公式 zip を手動展開：
<https://developer.android.com/tools/releases/platform-tools>
展開先（例：`C:\platform-tools`）を `PATH` に追加。

#### Linux

```bash
sudo apt-get install -y adb
```

#### macOS

```bash
brew install --cask android-platform-tools
```

### 0-3. adb のバージョン整合性に注意

ホスト adb のバージョンが古いと、コンテナ内（最新版）と通信できないことがある。
両者で `adb version` の **Version 文字列前半が同じ** であれば OK。

```powershell
adb version
docker compose run --rm flutter adb version
```

ズレている場合：ホスト側を最新化する（コンテナを古い方に合わせるのは非推奨）。

### 0-4. ホスト adb server を全インターフェースで起動

Docker コンテナからホスト adb に到達させるため、loopback ではなく
すべてのインターフェースで listen させる必要がある。

```powershell
# 既存 server を停止 → 全 IF で再起動
adb kill-server
adb -a -P 5037 nodaemon server start
```

`-a` が「all interfaces で listen」フラグ。
PowerShell をそのまま占有するので別ウィンドウで起動するのが楽。

> **常駐させたい場合**: スタートアップフォルダや `nssm` でサービス化可能。
> Windows Defender ファイアウォールで TCP 5037 の受信を許可しておく。

---

## 1. デバイス接続

### A. USB 接続

1. スマホで **開発者オプション → USB デバッグ** を有効化
2. USB 接続 → ホストで認証ダイアログを許可
3. ホストで確認：
   ```powershell
   adb devices
   # List of devices attached
   # ABCD1234   device
   ```
4. コンテナからも見えることを確認：
   ```powershell
   docker compose run --rm flutter adb devices
   ```
   同じデバイスが表示されれば成功。

### B. ホスト側エミュレーター

Windows Docker Desktop は KVM を提供しないため、エミュレーターはホスト側で起動し
ホストの adb server 経由でコンテナに接続する。

#### 前提: emulator コマンドの準備

`adb` のみ（platform-tools）では `emulator` コマンドは含まれない。
以下のどちらかで Android SDK を導入する：

- **Android Studio**（推奨）: インストール後、Virtual Device Manager で AVD を作成
- **cmdline-tools のみ**（軽量）:
  ```powershell
  # https://developer.android.com/tools/releases/cmdline-tools から zip を展開後
  sdkmanager "emulator" "platforms;android-35" "system-images;android-35;google_apis;x86_64"
  avdmanager create avd -n Pixel7_API35 -k "system-images;android-35;google_apis;x86_64" --device "pixel_7"
  ```

#### 手順

1. エミュレーターを起動（Android Studio の AVD Manager または CLI）：
   ```powershell
   emulator -avd Pixel7_API35
   ```

2. ホスト側で adb server を全インターフェースで起動（別ウィンドウ）：
   ```powershell
   adb kill-server
   adb -a -P 5037 nodaemon server start
   ```

3. ホスト側でエミュレーターが認識されていることを確認：
   ```powershell
   adb devices
   # emulator-5554   device
   ```

4. コンテナからも見えることを確認：
   ```powershell
   docker compose run --rm flutter flutter devices
   # 例: sdk gphone x86 64 (mobile) • emulator-5554 • android-x86_64 • Android 15 (API 35)
   ```

5. デバッグ実行：
   ```powershell
   docker compose run --rm --service-ports flutter flutter run -d emulator-5554
   ```

### C. Wi-Fi デバッグ（Android 11+）

USB ケーブル不要。同一 LAN 上で動作する。

1. スマホで **開発者オプション → ワイヤレスデバッグ** を ON
2. 「デバイスをペア設定コードでペア設定」を開き、IP:port とコードを表示
3. ホスト側でペアリング（初回のみ）：
   ```powershell
   adb pair 192.168.x.x:PAIRING_PORT
   # Enter pairing code: 123456
   ```
4. ワイヤレスデバッグ画面に表示されている **接続用** IP:port で接続：
   ```powershell
   adb connect 192.168.x.x:CONNECT_PORT
   ```
5. 確認：
   ```powershell
   adb devices
   # 192.168.x.x:CONNECT_PORT  device
   ```

ペアリングはデバイス毎に 1 回。次回からは `adb connect` だけで OK。
スマホを再起動すると CONNECT_PORT が変わるので注意。

---

## 2. デバイス確認（コンテナ内）

```powershell
docker compose run --rm flutter flutter devices
```

`(mobile)` 行にホストで認識したデバイスが出れば準備完了。

```
Pixel 7 (mobile) • ABCD1234 • android-arm64 • Android 14 (API 34)
```

---

## 3. ビルド

すべてコンテナ完結。ホストに成果物が出力される（`build/app/outputs/...`）が、
`build/` は named volume なので `docker compose cp` で取り出すと速い。

### デバッグ APK（手元検証用）

```powershell
docker compose run --rm flutter flutter build apk --debug
```

### リリース APK

```powershell
docker compose run --rm flutter flutter build apk --release
```
→ `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle（Google Play 提出用）

```powershell
docker compose run --rm flutter flutter build appbundle --release
```
→ `build/app/outputs/bundle/release/app-release.aab`

### 成果物をホストに取り出す

```powershell
docker compose cp flutter:/app/build/app/outputs/flutter-apk/app-release.apk .\app-release.apk
```

---

## 4. インストール

### 4-1. ビルド成果物をデバイスに install

```powershell
docker compose run --rm flutter flutter install
```

複数デバイス接続時は `-d <device-id>` で指定：

```powershell
docker compose run --rm flutter flutter install -d ABCD1234
```

### 4-2. 任意の APK を install

```powershell
docker compose run --rm flutter adb install build/app/outputs/flutter-apk/app-release.apk
# 既存上書き
docker compose run --rm flutter adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 4-3. アンインストール

```powershell
docker compose run --rm flutter adb uninstall com.ekusy.shopping_list_app
```

---

## 5. デバッグ実行（ホットリロード）

```powershell
docker compose run --rm --service-ports flutter `
  flutter run -d ABCD1234
```

`--service-ports` で DevTools / DDS のポート公開を有効化。
ターミナルに以下が出る：

```
A Dart VM Service ... is available at: http://127.0.0.1:8181/...
Flutter DevTools ... at: http://127.0.0.1:9100?uri=...
```

ホストのブラウザで `http://localhost:9100/...` を開けば DevTools が使える。

操作キー：
- `r` … ホットリロード
- `R` … フルリスタート
- `q` … 終了

> **VS Code attach**: コンテナ内で起動した DDS は host:8181 に転送済みなので、
> ホストの VS Code の Dart 拡張から attach 可能。`docs/DEBUGGING.md` 参照。

---

## 6. ログ確認

### Flutter ログ

`flutter run` の標準出力に出る。

### Android logcat（プロセス単位）

```powershell
docker compose run --rm flutter adb logcat --pid=$(docker compose run --rm flutter adb shell pidof -s com.ekusy.shopping_list_app)
```

簡易版：

```powershell
docker compose run --rm flutter adb logcat *:E
```

---

## 7. リリース署名（Play 配布時）

現状 `android/app/build.gradle.kts` の release ビルドはデバッグキーで署名される。
配布時は以下を行う：

1. キーストア作成（ホスト or コンテナどちらでも可。コンテナ例）：
   ```powershell
   docker compose run --rm flutter keytool -genkey -v `
     -keystore /app/android/upload-keystore.jks `
     -keyalg RSA -keysize 2048 -validity 10000 `
     -alias upload
   ```
   → 生成された `upload-keystore.jks` は **コミット禁止** (`.gitignore` 済み)

2. `android/key.properties` を作成（コミット禁止）：
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

3. `android/app/build.gradle.kts` の `signingConfigs` / `buildTypes.release.signingConfig`
   を更新（デバッグ署名から切り替え）。詳細は
   <https://docs.flutter.dev/deployment/android#signing-the-app> 参照。

4. リビルド：
   ```powershell
   docker compose run --rm flutter flutter build appbundle --release
   ```

---

## 8. トラブルシュート

| 症状 | 原因 | 対処 |
|---|---|---|
| `flutter devices` に出ない | ホスト adb が止まっている / loopback only で起動している | `adb kill-server` → `adb -a -P 5037 nodaemon server start` |
| `adb: cannot connect to daemon at tcp:host.docker.internal:5037` | ホスト側 firewall で 5037 がブロックされている | Windows Defender で TCP 5037 inbound を許可 |
| `could not install *smartsocket* listener: cannot bind to 0.0.0.0:5037 ... (10048)` | 別 adb プロセス（Android Studio バンドル / scrcpy / 旧 daemon 等）が 5037 を掴んでいる | 下記「ポート 5037 競合の解消」参照 |
| `adb` version mismatch エラー | ホスト adb がコンテナ adb より古い | ホストの platform-tools を最新化 |
| Gradle ビルドが毎回遅い | `gradle_cache` ボリュームがマウントされていない | `docker compose config` で `gradle_cache:/root/.gradle` を確認 |
| `Could not resolve all artifacts ... compileSdkVersion=NN` | プリインストール済みプラットフォームと不一致 | 初回ビルドは sdkmanager 経由で自動 DL される。失敗時は手動： `docker compose run --rm flutter sdkmanager "platforms;android-NN"` |
| `emulator` コマンドが見つからない | platform-tools のみでは emulator は含まれない | Android Studio または cmdline-tools + `sdkmanager "emulator"` を導入 |
| `flutter run` のホットリロードキーが効かない | `--service-ports` を付けていない / `stdin_open: true` が無効 | コマンドに `--service-ports` を付ける |
| Wi-Fi デバイスが切れる | スマホがスリープ / IP 変更 | スマホ画面を起こす → `adb connect ...` し直す |
| `keystore was tampered with, or password was incorrect` | `key.properties` のパスワード不一致 | 再生成 or パスワード確認 |

### ポート 5037 競合の解消（Windows）

`adb kill-server` は自分が話せる server しか止められない。別 adb.exe が掴んでいる場合は強制終了する：

```powershell
# 5037 を掴んでいるプロセスを 1 行で kill
Get-NetTCPConnection -LocalPort 5037 -State Listen |
  Select-Object -ExpandProperty OwningProcess |
  ForEach-Object { Stop-Process -Id $_ -Force }

# 念のため残り adb.exe も全部止める
Get-Process adb -ErrorAction SilentlyContinue | Stop-Process -Force

# 全インターフェースで再起動
adb -a -P 5037 nodaemon server start
```

それでも掴まれている場合は Android Studio を一旦終了する（バンドル adb が常駐している）。

### デバッグ手順

1. ホスト adb の到達確認：
   ```powershell
   adb devices                                       # ホストから OK か
   docker compose run --rm flutter adb devices       # コンテナ → ホスト OK か
   ```
2. Flutter のセルフ診断：
   ```powershell
   docker compose run --rm flutter flutter doctor -v
   ```
   `Android toolchain` の項目が ✓ になれば SDK 配置は OK。
3. Gradle 単体の確認：
   ```powershell
   docker compose run --rm flutter bash -c "cd android && ./gradlew --version"
   ```

---

## 9. 参考

- Flutter Android デプロイ公式: <https://docs.flutter.dev/deployment/android>
- Android command-line tools: <https://developer.android.com/tools/releases/cmdline-tools>
- adb 通信プロトコル: <https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/SERVICES.TXT>
