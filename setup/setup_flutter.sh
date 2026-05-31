#!/bin/bash
# Flutter 開発環境確認スクリプト
# Flutter 本体は Docker コンテナ内で管理するため、
# このスクリプトは Docker イメージのビルド確認のみを行う。
# 対象: Linux / macOS（x86_64 / arm64）
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! declare -f log_info > /dev/null 2>&1; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
    log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
    log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
fi

flutter_main() {
    echo ""
    echo "========================================"
    echo "  Flutter 環境（Docker）"
    echo "========================================"
    echo ""

    if ! command -v docker &>/dev/null; then
        log_error "Docker が見つかりません。先に Docker をインストールしてください。"
        exit 1
    fi

    log_info "Flutter Docker イメージをビルド中..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" build
    log_success "Flutter イメージビルド完了"

    log_info "Flutter バージョン確認..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" \
        run --rm flutter flutter --version

    echo ""
    log_success "Flutter 環境セットアップ完了（Docker）"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    flutter_main
fi
