#!/usr/bin/env bash
set -euo pipefail

# Android 実機へのビルド & 直接インストールスクリプト（adb 経由）
# flutter build apk → adb install → 起動（任意）
#
# 前提:
#   - macOS ホスト（docs/ANDROID_LOCAL.md の環境。Apple Silicon Mac は Docker 経由の
#     adb が動かないため、このスクリプトはホスト直接実行を前提とする）
#   - USB デバッグ有効化済み・「USB デバッグを許可」済みの Android 実機（docs/ANDROID_LOCAL.md §1）
#   - USB / Wi-Fi どちらの adb 接続でも可
#
# 使い方:
#   scripts/android-install.sh             # release ビルドしてインストール
#   scripts/android-install.sh --debug     # debug ビルドしてインストール
#   scripts/android-install.sh --no-build  # 既存ビルドをインストールのみ
#   scripts/android-install.sh --launch    # インストール後に起動も試みる
#
# 環境変数:
#   DEVICE_ID    対象デバイスの adb serial（省略時は adb devices の 1 台目を使用）
#   FLUTTER      flutter コマンドのパス（省略時: ~/development/flutter/bin/flutter）
#   ANDROID_HOME 省略時: /opt/homebrew/share/android-commandlinetools
#   JAVA_HOME    省略時: /opt/homebrew/opt/openjdk@21

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/development/flutter/bin/flutter}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
ADB="${ANDROID_HOME}/platform-tools/adb"

APPLICATION_ID="com.ekusy.shopping_list_app"
MAIN_ACTIVITY=".MainActivity"

BUILD_MODE="release"
DO_BUILD=1
DO_LAUNCH=0
for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    --debug)    BUILD_MODE="debug" ;;
    --launch)   DO_LAUNCH=1 ;;
    *) echo "不明なオプション: $arg" >&2; exit 1 ;;
  esac
done

if [[ "$BUILD_MODE" == "debug" ]]; then
  APK_PATH="$REPO_ROOT/build/app/outputs/flutter-apk/app-debug.apk"
else
  APK_PATH="$REPO_ROOT/build/app/outputs/flutter-apk/app-release.apk"
fi

# ---------------------------------------------------------------------------
# 対象デバイスの決定（DEVICE_ID 未指定なら adb devices の 1 台目を使用）
# ---------------------------------------------------------------------------
if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_ID="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -z "$DEVICE_ID" ]]; then
    echo "ERROR: adb で認識できる Android 実機が見つかりません。" >&2
    echo "  USB 接続し、端末側で「USB デバッグを許可」してから再実行してください。" >&2
    echo "  接続状態確認: $ADB devices" >&2
    exit 1
  fi
fi

VERSION="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "$REPO_ROOT/pubspec.yaml")"
BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

# ---------------------------------------------------------------------------
# ビルド
# ---------------------------------------------------------------------------
if [[ "$DO_BUILD" == 1 ]]; then
  echo "==> flutter build apk --${BUILD_MODE} (${BRANCH} @ ${COMMIT})"
  (cd "$REPO_ROOT" && "$FLUTTER" build apk --"$BUILD_MODE")
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "ERROR: $APK_PATH がありません（先にビルドしてください）" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# インストール
# ---------------------------------------------------------------------------
echo "==> adb install -r (device: ${DEVICE_ID})"
"$ADB" -s "$DEVICE_ID" install -r "$APK_PATH"

# ---------------------------------------------------------------------------
# 起動（--launch 時のみ）
# ---------------------------------------------------------------------------
if [[ "$DO_LAUNCH" == 1 ]]; then
  echo "==> アプリ起動"
  if ! "$ADB" -s "$DEVICE_ID" shell am start -n "${APPLICATION_ID}/${APPLICATION_ID}${MAIN_ACTIVITY}"; then
    echo "--- 起動失敗。手動でアイコンをタップしてください ---" >&2
  fi
fi

echo ""
echo "============================================================"
echo " インストール完了: ${BRANCH} @ ${COMMIT} (v${VERSION}, ${BUILD_MODE})"
echo " device: ${DEVICE_ID}"
echo "============================================================"
