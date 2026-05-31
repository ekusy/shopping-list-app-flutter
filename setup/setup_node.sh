#!/bin/bash
# Node.js セットアップ
# 対象: Linux / macOS（x86_64 / arm64）
# スタンドアロン実行可: ./setup_node.sh
# setup.sh からの呼び出しも可
set -e

# ============================================================
# ロギング（スタンドアロン時のみ定義）
# ============================================================
if ! declare -f log_info > /dev/null 2>&1; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
    log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
    log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
fi

# ============================================================
# 1. Node.js LTS（NodeSource 経由）
# ============================================================
install_nodejs() {
    log_info "Node.js を確認中..."

    if command -v node &>/dev/null; then
        local ver
        ver=$(node --version)
        log_success "Node.js は既にインストール済みです ($ver)"
        return
    fi

    log_info "Node.js LTS を NodeSource APT リポジトリからインストール中..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    log_success "Node.js インストール完了 ($(node --version))"
}

# ============================================================
# メイン
# ============================================================
node_main() {
    echo ""
    echo "========================================"
    echo "  Node.js セットアップ"
    echo "========================================"
    echo ""

    install_nodejs

    log_success "Node.js セットアップ完了"
    echo ""
}

# スタンドアロン実行時のみ main を呼び出す
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "$EUID" -eq 0 ]; then
        log_error "rootで実行しないでください。sudoは内部で使用します。"
        exit 1
    fi
    sudo -v || { log_error "sudo 権限が必要です"; exit 1; }
    while true; do sudo -n true; sleep 50; done &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
    node_main
fi
