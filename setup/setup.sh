#!/bin/bash
# ============================================================
# 開発環境 セットアップスクリプト（メインエントリーポイント）
# 対象: Linux / macOS（x86_64 / arm64）
# 使い方: ./setup/setup.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

export -f log_info log_success log_warn log_error

# ============================================================
# 1. Docker 確認
# ============================================================
check_docker() {
    log_info "Docker を確認中..."
    if ! command -v docker &>/dev/null; then
        log_error "Docker が見つかりません。https://docs.docker.com/get-docker/ からインストールしてください。"
        exit 1
    fi
    if ! docker compose version &>/dev/null; then
        log_error "Docker Compose (V2) が見つかりません。Docker Desktop または docker-compose-plugin をインストールしてください。"
        exit 1
    fi
    log_success "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
    log_success "Docker Compose $(docker compose version --short)"
}

# ============================================================
# 2. Docker イメージビルド
# ============================================================
build_image() {
    log_info "Flutter Docker イメージをビルド中（初回は数分かかります）..."
    docker compose -f "${SCRIPT_DIR}/../docker-compose.yml" build
    log_success "イメージビルド完了"
}

# ============================================================
# 3. VS Code 拡張機能（オプション）
# ============================================================
install_vscode_extensions() {
    if ! command -v code &>/dev/null; then
        log_warn "'code' コマンドが見つかりません。VS Code 拡張機能のインストールをスキップします。"
        return
    fi

    log_info "VS Code 拡張機能をインストール中..."
    source "${SCRIPT_DIR}/setup_vscode.sh"
    vscode_main
}

# ============================================================
# メイン
# ============================================================
main() {
    echo ""
    echo "========================================"
    echo "  開発環境 セットアップ（Docker）"
    echo "========================================"
    echo ""

    check_docker
    build_image
    install_vscode_extensions

    echo ""
    echo "========================================"
    log_success "セットアップ完了！"
    echo ""
    echo "開発サーバー起動:"
    echo "  docker compose run --rm --service-ports flutter \\"
    echo "    flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5000"
    echo ""
    echo "ブラウザで http://localhost:5000 にアクセスしてください。"
    echo "========================================"
    echo ""
}

main "$@"
