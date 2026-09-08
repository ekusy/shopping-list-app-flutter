# Android 実機インストール手順（Apple Silicon Mac ホスト直接実行）

Android の実機ビルド・インストール・デバッグを **macOS（Apple Silicon）ホスト上で直接**行うための手順。

`docs/ANDROID_DOCKER.md` の Docker 経由の手順は Windows / Intel Mac を主対象としており、
Apple Silicon（arm64）Mac では使えない（詳細は下記アーキテクチャ節）。本ドキュメントは
[`docs/IOS_LOCAL.md`](./IOS_LOCAL.md) と同じ「ホストに Flutter を直接導入する」方式を Android にも適用する。

検証済み環境（2026-07-14 時点でホスト側セットアップ確認済み。実機インストールは端末接続時に検証）:

| 項目 | バージョン |
|---|---|
| macOS | Apple Silicon（arm64） |
| Flutter（ホスト） | 3.44.0（コンテナと同一） |
| Android SDK | Android SDK 35.0.0 / platform android-36 / build-tools 35.0.0 |
| JDK | Homebrew openjdk@21 |
| エミュレータ | Pixel7_API35（android-35 google_apis arm64-v8a）動作確認済み（2026-07-08） |

## なぜ Docker 経由の adb が使えないか

`docs/ANDROID_DOCKER.md` の方式は「ビルドはコンテナ内、adb はホスト側 → コンテナの adb クライアントが
`ADB_SERVER_SOCKET=tcp:host.docker.internal:5037` 経由でホストの adb server と通信する」設計になっている。
この方式ではコンテナ内でも adb バイナリ自体を実行する必要があるが、Google が配布する Linux 版
platform-tools は **x86_64 のみ**であり、arm64 ネイティブビルドの flutter コンテナ内では qemu 経由の
エミュレーションになる。この環境では adb 実行時に

```
qemu-x86_64: Could not open '/lib64/ld-linux-x86-64.so.2'
```

のようなエラーで失敗し、コンテナ側から一切 adb を実行できない。Firebase CLI の arm64 問題（コミット
`a1cc184`）と同種の原因のため、Apple Silicon Mac ではビルドも含めてホスト側で完結させる。

> Web / iOS 以外の環境（Windows / Intel Mac ホスト）では引き続き `docs/ANDROID_DOCKER.md` の
> Docker 経由の手順を使う。

---

## 0. 初回セットアップ（ホスト）

### 0-1. Flutter SDK（コンテナと同一バージョン）

`docs/IOS_LOCAL.md` §0-2 と共用。すでに iOS 用にホスト Flutter を導入済みならこの手順は不要。

```bash
mkdir -p ~/development && cd ~/development
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.44.0-stable.zip
unzip -q flutter_macos_arm64_3.44.0-stable.zip && rm flutter_macos_arm64_3.44.0-stable.zip
```

`~/.zshrc` に PATH を追加:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

> Flutter をアップグレードする際は `Dockerfile` の `FLUTTER_VERSION` とホスト SDK を
> **同時に**更新し、コンテナとのバージョンずれを作らないこと。

### 0-2. Android SDK

Android Studio を導入していない場合は Homebrew の cmdline-tools が軽量:

```bash
brew install --cask android-commandlinetools
```

`ANDROID_HOME=/opt/homebrew/share/android-commandlinetools` にプラットフォーム / ビルドツールを導入:

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
sdkmanager --licenses   # すべて y で許諾
```

### 0-3. adb（ホスト実機通信用）

```bash
brew install --cask android-platform-tools
adb version
```

Homebrew cask 版は arm64 ネイティブビルドのため、上記の qemu 問題は発生しない。

### 0-4. JDK 21

Gradle 9.1 系は新しすぎる JDK（Homebrew の openjdk 26 等）では動かないことがある。
`openjdk@21` を明示的に指定する:

```bash
brew install openjdk@21
```

### 0-5. 環境変数（`~/.zshrc` に追加）

```bash
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
export PATH="$HOME/development/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"
```

### 0-6. `google-services.json` の配置

`android/app/google-services.json` は `.gitignore` 対象（クローン直後は存在しない）。
`flutterfire configure` は不要で、`lib/firebase_options.dart` の android 値から
以下の形で手書き生成すれば動作する（Firebase Console からダウンロードしても可）:

```json
{
  "project_info": {
    "project_number": "<firebase_options.dart の androidClientId 等から>",
    "project_id": "household-shopping-list-f7c12",
    "storage_bucket": "<firebase_options.dart の storageBucket>"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "<firebase_options.dart の appId>",
        "android_client_info": { "package_name": "com.ekusy.shopping_list_app" }
      },
      "api_key": [{ "current_key": "<firebase_options.dart の apiKey>" }]
    }
  ],
  "configuration_version": "1"
}
```

### 0-7. 動作確認

```bash
flutter doctor -v
```

`Android toolchain` が ✓ になれば OK。`Chrome` の ✗ は無視してよい（コンテナ側でカバー）。

---

## 1. 実機セットアップ（初回のみ）

1. スマホで **設定 → 端末情報 → ビルド番号を7回タップ** して開発者向けオプションを有効化
2. **設定 → システム → 開発者向けオプション → USB デバッグ** を ON
3. USB で Mac に接続 → 「USB デバッグを許可しますか?」ダイアログで **許可**
   （「この端末からは常に許可する」にチェック推奨）
4. 確認:
   ```bash
   adb devices
   # List of devices attached
   # ABCD1234        device
   ```
   `unauthorized` と出る場合はスマホ側のダイアログを確認・再許可する。

Wi-Fi 接続（Android 11+）にしたい場合は `docs/ANDROID_DOCKER.md` §1-C の手順がそのまま使える
（`adb pair` / `adb connect` はホスト adb に対してそのまま実行すればよく、Docker は関与しない）。

---

## 2. 実機での実行・インストール

デバイス ID の確認:

```bash
flutter devices
```

### 2-1. debug モード（ホットリロード付き）

```bash
flutter run -d <device-id>
```

`r` でホットリロード、`R` でフルリスタート、`q` で終了。

### 2-2. release モード（動作確認・インストール目的）

```bash
flutter run --release -d <device-id>
```

### 2-3. APK ビルド → adb install

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

複数端末接続時は `adb -s <device-id> install -r ...` で対象を指定する。

### 2-4. 便利スクリプト

`scripts/android-install.sh` でビルド〜インストールを一括実行できる（`docs/IOS_LOCAL.md` の
`ios-install.sh` の Android 版）:

```bash
scripts/android-install.sh              # release ビルド + インストール
scripts/android-install.sh --no-build   # 既存ビルドをインストールのみ
scripts/android-install.sh --launch     # インストール後にアプリを起動
scripts/android-install.sh --debug      # debug ビルドでインストール
```

対象端末が複数ある場合は `DEVICE_ID=<serial>` を環境変数で指定する。

---

## 3. エミュレータでの実行

Apple Silicon Mac のエミュレータはホスト側で直接動かせる（Docker Desktop の KVM 制約は関係ない）。

```bash
# AVD 作成（初回のみ。system image は arm64-v8a を指定すること）
sdkmanager "system-images;android-35;google_apis;arm64-v8a"
avdmanager create avd -n Pixel7_API35 \
  -k "system-images;android-35;google_apis;arm64-v8a" --device "pixel_7"

# config.ini の hw.keyboard=yes を確認（Mac のハードウェアキーボード入力に必要。
# avdmanager 作成直後のデフォルトは no）

# 起動
$ANDROID_HOME/emulator/emulator -avd Pixel7_API35

# 別ターミナルでビルド & 実行
flutter run -d emulator-5554
```

---

## 4. デバッグ・ログ確認

```bash
# Flutter ログは flutter run の標準出力に出る

# logcat（プロセス単位）
adb logcat --pid=$(adb shell pidof -s com.ekusy.shopping_list_app)

# 簡易版（エラーのみ）
adb logcat *:E
```

---

## 5. トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `flutter devices` に実機が出ない | USB デバッグ未許可 / ケーブル不良 | §1 を実施。`adb devices` で `unauthorized`/`offline` を確認 |
| `Could not locate aapt` | 初回ビルド時に Gradle が build-tools を自動導入した直後 | **再実行すれば通る**（既知の一過性エラー） |
| `Unable to locate a Java Runtime`（`avdmanager`/`sdkmanager`実行時） | `JAVA_HOME` 未設定のままコマンド単体実行 | `JAVA_HOME=/opt/homebrew/opt/openjdk@21` を付けて実行 |
| Gradle ビルドが JDK バージョンで失敗 | Homebrew の新しい openjdk（26 等）を掴んでいる | `JAVA_HOME` を openjdk@21 に固定 |
| `keystore was tampered with, or password was incorrect` | release 署名設定の `key.properties` 不一致 | `docs/ANDROID_DOCKER.md` §7 を参照して再設定 |
| コンテナ内で `qemu-x86_64: Could not open ...` | Apple Silicon で Docker 経由 adb を使おうとしている | 本ドキュメントのホスト直接実行に切り替える（Docker 経由は arm64 非対応） |

---

## 6. 参考

- Flutter Android デプロイ公式: <https://docs.flutter.dev/deployment/android>
- Docker 経由の詳細手順（Windows / Intel Mac 向け）: `docs/ANDROID_DOCKER.md`
- iOS のホスト直接実行（同方式）: `docs/IOS_LOCAL.md`
