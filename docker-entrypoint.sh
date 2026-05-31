#!/bin/sh
set -e

# build/ がホスト側シンボリックリンクの場合、named volume のマウント先と
# 競合しないよう削除する（初回のみ発生）
if [ -L /app/build ]; then
  rm /app/build
fi

# .dart_tool/package_config.json が存在しない、または
# ホストの pub-cache パス（/home/...）を参照している場合は pub get を実行する。
# docker-compose.yml で dart_tool_vol を named volume にしているため、
# 通常は初回コンテナ起動時のみここで pub get が走る。
if [ -f /app/pubspec.yaml ]; then
  pkg_config="/app/.dart_tool/package_config.json"
  need_pub_get=0

  if [ ! -f "$pkg_config" ]; then
    need_pub_get=1
  elif grep -q '"/home/' "$pkg_config" 2>/dev/null; then
    echo "package_config.json contains host paths — regenerating..."
    need_pub_get=1
  fi

  if [ "$need_pub_get" -eq 1 ]; then
    echo "Running flutter pub get..."
    cd /app && flutter pub get
  fi
fi

exec "$@"
