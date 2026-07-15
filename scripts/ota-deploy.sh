#!/usr/bin/env bash
set -euo pipefail

# iPhone への OTA (Over-The-Air) 配布スクリプト
# flutter build ios --release → .ipa 化 → manifest.plist 生成 → tailscale serve で配信
#
# 前提:
#   - macOS ホスト + Xcode（docs/IOS_LOCAL.md の環境）
#   - Mac / iPhone が同一 tailnet に参加済みで、tailnet の HTTPS 証明書が有効
#   - iPhone の UDID が開発用プロビジョニングプロファイルに登録済み
#     （一度 USB で flutter run していれば登録されている）
#
# 使い方:
#   scripts/ota-deploy.sh            # フルビルドして配信
#   scripts/ota-deploy.sh --no-build # 既存ビルドを再パッケージ・再配信のみ
#   scripts/ota-deploy.sh --stop     # 配信停止

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/development/flutter/bin/flutter}"
TAILSCALE="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"

BUNDLE_ID="com.ekusy.shoppingListApp"
TITLE="Shopping List App"
APP_PATH="$REPO_ROOT/build/ios/iphoneos/Runner.app"
OTA_DIR="$REPO_ROOT/build/ota"
# App Store 版 Tailscale はサンドボックス制限でパス直接配信が不可のため、
# 127.0.0.1 のみに bind したローカル HTTP サーバーへのリバースプロキシで配信する
PORT=8787

if [[ "${1:-}" == "--stop" ]]; then
  "$TAILSCALE" serve reset
  pkill -f "http.server ${PORT}" 2>/dev/null || true
  echo "OTA 配信を停止しました"
  exit 0
fi

HOST="$("$TAILSCALE" status --json | python3 -c \
  "import json,sys; print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))")"
VERSION="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "$REPO_ROOT/pubspec.yaml")"
BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
BUILT_AT="$(date '+%Y-%m-%d %H:%M')"

if [[ "${1:-}" != "--no-build" ]]; then
  echo "==> flutter build ios --release"
  (cd "$REPO_ROOT" && "$FLUTTER" build ios --release)
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: $APP_PATH がありません（先にビルドしてください）" >&2
  exit 1
fi

echo "==> .ipa パッケージング"
rm -rf "$OTA_DIR"
mkdir -p "$OTA_DIR/Payload"
cp -R "$APP_PATH" "$OTA_DIR/Payload/"
(cd "$OTA_DIR" && zip -qry app.ipa Payload && rm -rf Payload)

BASE_URL="https://${HOST}"
# インストール毎に manifest を再取得させるためのキャッシュバスター
STAMP="$(date +%s)"
ITMS_URL="itms-services://?action=download-manifest&url=${BASE_URL}/manifest.plist%3Fv%3D${STAMP}"

cat > "$OTA_DIR/manifest.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${BASE_URL}/app.ipa</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${BUNDLE_ID}</string>
        <key>bundle-version</key>
        <string>${VERSION}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${TITLE}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF

cat > "$OTA_DIR/index.html" <<EOF
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${TITLE} — インストール</title>
<style>
  body { font-family: -apple-system, sans-serif; margin: 0; padding: 2rem 1.5rem;
         display: flex; flex-direction: column; align-items: center; gap: 1rem;
         background: #f5f5f7; color: #1d1d1f; }
  h1 { font-size: 1.3rem; margin: 0; }
  .meta { color: #6e6e73; font-size: 0.85rem; text-align: center; line-height: 1.6; }
  a.install { display: block; width: 100%; max-width: 320px; padding: 1rem;
              text-align: center; background: #0071e3; color: #fff; border-radius: 12px;
              font-size: 1.1rem; font-weight: 600; text-decoration: none; }
  .note { color: #6e6e73; font-size: 0.75rem; max-width: 320px; }
</style>
</head>
<body>
  <h1>${TITLE}</h1>
  <p class="meta">
    v${VERSION}<br>
    ${BRANCH} @ ${COMMIT}<br>
    ${BUILT_AT} ビルド
  </p>
  <a class="install" href="${ITMS_URL}">インストール</a>
  <p class="note">インストール後、ホーム画面にアイコンが出るまで数十秒かかることがあります。
  開発署名のため 7 日で起動できなくなります（再インストールで更新）。</p>
</body>
</html>
EOF

echo "==> ローカル HTTP サーバー + tailscale serve 起動"
pkill -f "http.server ${PORT}" 2>/dev/null || true
nohup python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$OTA_DIR" \
  > /dev/null 2>&1 &
"$TAILSCALE" serve --bg "$PORT" > /dev/null

echo ""
echo "============================================================"
echo " ビルド: ${BRANCH} @ ${COMMIT} (v${VERSION}, ${BUILT_AT})"
echo " iPhone の Safari で開く:"
echo "   ${BASE_URL}/index.html"
echo "============================================================"
