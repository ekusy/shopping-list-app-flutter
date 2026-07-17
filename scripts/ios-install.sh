#!/usr/bin/env bash
set -euo pipefail

# iPhone 実機へのビルド & 直接インストールスクリプト（devicectl 経由）
# flutter build ios --release → xcrun devicectl でインストール → 起動（任意）
#
# 前提:
#   - macOS ホスト + Xcode（docs/IOS_LOCAL.md の環境）
#   - iPhone がペアリング済み（一度 USB で flutter run していれば OK）
#   - USB / Wi-Fi どちらの接続でも可（Wi-Fi は接続リセットが起きやすいためリトライする）
#
# 使い方:
#   scripts/ios-install.sh             # フルビルドしてインストール
#   scripts/ios-install.sh --no-build  # 既存ビルドをインストールのみ
#   scripts/ios-install.sh --launch    # インストール後に起動も試みる（要ロック解除）
#
# 環境変数:
#   DEVICE_ID  対象デバイスの devicectl identifier（省略時はペアリング済み iPhone を自動検出）
#   FLUTTER    flutter コマンドのパス（省略時: ~/development/flutter/bin/flutter）

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/development/flutter/bin/flutter}"

BUNDLE_ID="com.ekusy.shoppingListApp"
APP_PATH="$REPO_ROOT/build/ios/iphoneos/Runner.app"

DO_BUILD=1
DO_LAUNCH=0
for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    --launch)   DO_LAUNCH=1 ;;
    *) echo "不明なオプション: $arg" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# 対象デバイスの決定（DEVICE_ID 未指定ならペアリング済み iPhone を自動検出）
# ---------------------------------------------------------------------------
if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICES_JSON="$(mktemp)"
  trap 'rm -f "$DEVICES_JSON"' EXIT
  xcrun devicectl list devices --json-output "$DEVICES_JSON" > /dev/null
  DEVICE_ID="$(python3 - "$DEVICES_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for d in data.get("result", {}).get("devices", []):
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    if hw.get("deviceType") == "iPhone" and conn.get("pairingState") == "paired":
        print(d["identifier"])
        break
PY
)"
  if [[ -z "$DEVICE_ID" ]]; then
    echo "ERROR: ペアリング済みの iPhone が見つかりません。" >&2
    echo "  USB 接続するか、iPhone と Mac が同一 Wi-Fi にいるか確認してください。" >&2
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
  echo "==> flutter build ios --release (${BRANCH} @ ${COMMIT})"
  (cd "$REPO_ROOT" && "$FLUTTER" build ios --release)
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: $APP_PATH がありません（先にビルドしてください）" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# インストール（Wi-Fi 接続は "Connection reset by peer" が出やすいためリトライ）
# ---------------------------------------------------------------------------
echo "==> devicectl install (device: ${DEVICE_ID})"
INSTALLED=0
for attempt in 1 2 3; do
  if xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"; then
    INSTALLED=1
    break
  fi
  echo "--- インストール失敗（試行 ${attempt}/3）。5 秒後にリトライします ---" >&2
  sleep 5
done
if [[ "$INSTALLED" != 1 ]]; then
  echo "ERROR: インストールに 3 回失敗しました。" >&2
  echo "  iPhone のロックを解除する・USB 接続に切り替える等を試してください。" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 起動（--launch 時のみ。ロック中は失敗するが致命的ではない）
# ---------------------------------------------------------------------------
if [[ "$DO_LAUNCH" == 1 ]]; then
  echo "==> アプリ起動"
  if ! xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"; then
    echo "--- 起動失敗（iPhone がロック中の可能性）。手動でアイコンをタップしてください ---" >&2
  fi
fi

echo ""
echo "============================================================"
echo " インストール完了: ${BRANCH} @ ${COMMIT} (v${VERSION})"
echo " 開発署名（Personal Team）のため 7 日で起動不可になります。"
echo " 期限切れの際は本スクリプトで再インストールしてください。"
echo "============================================================"
