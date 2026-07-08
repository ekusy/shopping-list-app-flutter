# iOS 開発手順（macOS ホスト直接実行）

iOS のビルド・デバッグ・実機インストールを macOS ホスト上で行うための手順。
Xcode / codesign / simctl が macOS 専用のため、iOS のみ Docker 化対象外
（`CLAUDE.md` の環境方針を参照）。

検証済み環境（2026-07-08）:

| 項目 | バージョン |
|---|---|
| macOS | 26.2（Apple Silicon） |
| Xcode | 26.6 |
| Flutter（ホスト） | 3.44.0（コンテナと同一） |
| シミュレータ | iPhone 17 Pro / iOS 26.5 |
| 実機 | iPhone 12 Pro / iOS 26.6 |

## アーキテクチャ / 方針

- **ホストにコンテナと同一バージョンの Flutter を導入**する（バージョンは
  `Dockerfile` の `ARG FLUTTER_VERSION` に合わせる）。iOS 作業時のみ使用し、
  Web / Android のビルド・テストは従来どおりコンテナで行う。
- iOS ネイティブ依存の解決は **Swift Package Manager（SPM）** で行われる
  （`Podfile` は存在しない）。CocoaPods のインストールは現状不要。
- Firebase の初期化は `lib/firebase_options.dart`（Dart 側設定）で完結するため、
  `GoogleService-Info.plist` が無くてもビルド・動作する。
  `google_sign_in` や `firebase_messaging` などネイティブ側設定が必要なプラグインを
  導入した時点で `flutterfire configure --platforms=ios` による plist 生成が必要になる
  （plist は `.gitignore` 済 / コミット禁止）。
- `IPHONEOS_DEPLOYMENT_TARGET` は **15.0**（Firebase iOS SDK の最低要件）。
  13.0 に戻すと SPM の解決でビルドが失敗する（§4 トラブルシューティング参照）。

---

## 0. 初回セットアップ（ホスト）

### 0-1. Xcode

App Store から Xcode をインストール後、CLI から使えるようにする:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

### 0-2. Flutter SDK（コンテナと同一バージョン）

```bash
mkdir -p ~/development && cd ~/development
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.44.0-stable.zip
unzip -q flutter_macos_arm64_3.44.0-stable.zip && rm flutter_macos_arm64_3.44.0-stable.zip
```

`~/.zshrc` に PATH を追加:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

> Flutter をアップグレードする際は Dockerfile の `FLUTTER_VERSION` と
> ホスト SDK を**同時に**更新し、バージョンずれを作らないこと。

### 0-3. iOS シミュレータランタイム（約 8 GB）

Xcode 本体とは別にダウンロードが必要:

```bash
xcodebuild -downloadPlatform iOS
```

### 0-4. 動作確認

```bash
flutter doctor
cd <リポジトリルート> && flutter pub get
```

> `flutter doctor` の Android toolchain / Chrome の ✗ は無視してよい
> （どちらもコンテナ側でカバーしている）。

---

## 1. シミュレータでの実行

```bash
# 利用可能なシミュレータの確認
xcrun simctl list devices available

# 起動（<udid> は上記一覧の UUID）
xcrun simctl boot <udid>
open -a Simulator

# ビルド & 実行（ホットリロード有効）
flutter run -d <udid>
```

- ターミナルで `r` ホットリロード / `R` フルリスタート / `q` 終了。
- スクリーンショット取得: `xcrun simctl io booted screenshot shot.png`

> **キーボード入力の注意**: Mac のハードウェアキーボード（JIS）から `@` を打つと
> `[` が入力されることがある（US レイアウトとして解釈されるため）。
> Simulator メニューの **I/O → Keyboard → Toggle Software Keyboard**（⌘K）で
> ソフトウェアキーボードから入力するか、ペーストで回避する。

---

## 2. 実機セットアップ（初回のみ）

### 2-1. 署名（Xcode GUI）

1. Xcode → **Settings...**（⌘,）→ **Accounts** → 「+」→ **Apple Account** でサインイン
2. `open ios/Runner.xcworkspace` でプロジェクトを開く
3. ナビゲータで **Runner** → **TARGETS Runner** → **Signing & Capabilities**
4. **Automatically manage signing** にチェック → **Team** を選択

これで開発用証明書が作成され、`project.pbxproj` に `DEVELOPMENT_TEAM` が書き込まれる。

> リポジトリにはオーナーのチーム ID（`6YGKUKP9GM`）がコミット済み。
> 別の開発者がビルドする場合は自分の Team に選び直す（pbxproj が書き換わる）。

> **無料 Personal Team の場合**: プロビジョニングプロファイルは **7 日で失効**する。
> 失効したら再ビルド（再インストール）すれば更新される。

### 2-2. iPhone 側の設定

1. USB で Mac に接続 → 「このコンピュータを信頼しますか?」→ **信頼**
2. **設定 → プライバシーとセキュリティ → デベロッパモード** を ON（再起動が入る）
3. 再起動後のダイアログで **有効にする** をタップ

### 2-3. 開発者プロファイルの信頼（初回インストール後）

初回はアプリを起動できず「信頼されていないデベロッパ」と表示される。iPhone の

**設定 → 一般 → VPNとデバイス管理 → デベロッパApp → 「Apple Development: …」→ 信頼**

を実行してから再度起動する。

---

## 3. 実機での実行

デバイス ID の確認:

```bash
flutter devices                  # flutter 用 ID（例: 00008101-XXXXXXXXXXXXXXXX）
xcrun devicectl list devices     # devicectl 用 ID（UUID 形式。上とは別物）
```

### 3-1. debug モード（ホットリロード付き）

```bash
flutter run -d <device-id>
```

- **USB 接続を推奨**。iOS 17 以降の debug 起動は Flutter が Xcode を自動操作する
  仕組みのため、初回に macOS が「ターミナルから Xcode を制御することを許可しますか?」
  と確認してきたら**許可**する（後から変更: システム設定 → プライバシーとセキュリティ
  → オートメーション）。
- **Wi-Fi 接続では `Timed out waiting for CONFIGURATION_BUILD_DIR to update` で
  失敗しやすい**。その場合は USB に切り替えるか §3-2 の方法を使う。

### 3-2. release モード（動作確認・インストール目的）

ホットリロードは無いが Xcode の自動操作を使わないため安定して動く:

```bash
flutter run --release -d <device-id>
```

`Installing and launching...` で失敗する場合は、ビルドと起動を分けて devicectl で直接行う:

```bash
flutter build ios --release
xcrun devicectl device install app --device <devicectl-id> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <devicectl-id> com.ekusy.shoppingListApp
```

---

## 4. トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `The package product 'firebase-core' requires minimum platform version 15.0` | deployment target が 15.0 未満 | `project.pbxproj` の `IPHONEOS_DEPLOYMENT_TARGET` を 15.0 に（対応済み。戻さないこと） |
| `Command CodeSign failed with a nonzero exit code` | キーチェーンの秘密鍵アクセスが未許可 | 署名時のダイアログで「常に許可」。ダイアログが出ない場合は `security unlock-keychain ~/Library/Keychains/login.keychain-db` 後に再実行 |
| `... has not been explicitly trusted by the user` / 「信頼されていないデベロッパ」 | 開発者プロファイル未信頼 | §2-3 を実施 |
| `enable Developer Mode in Settings` | デベロッパモード無効（または再起動直後で未反映） | §2-2 を実施。実施済みなら数十秒待って再実行 |
| `Timed out waiting for CONFIGURATION_BUILD_DIR to update` | Wi-Fi 接続 + Xcode 自動操作の不安定さ | USB 接続 + オートメーション許可、または §3-2 の release + devicectl |
| シミュレータ一覧が空 / `Unable to get list of installed Simulator runtimes` | iOS ランタイム未ダウンロード | §0-3 を実施 |

---

## 5. 配布用ビルド（未検証）

App Store 提出は有料の Apple Developer Program 加入と配布用署名の整備が別途必要。

```bash
flutter build ios --release        # Xcode で archive する前段
flutter build ipa --release        # App Store 提出用 .ipa
```
