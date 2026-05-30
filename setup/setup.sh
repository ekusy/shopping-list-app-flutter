#!/bin/bash
# ============================================================
# 開発環境 セットアップスクリプト（メインエントリーポイント）
# 対象: Ubuntu 26.04+ (x86_64) / WSL2
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
# 実行環境チェック
# ============================================================
require_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_error "rootで実行しないでください。sudoは内部で使用します。"
        exit 1
    fi
    sudo -v || { log_error "sudo 権限が必要です"; exit 1; }
    while true; do sudo -n true; sleep 50; done &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
}

# ============================================================
# CRLF 除去（Windows ファイルシステム上での実行対策）
# ============================================================
strip_crlf() {
    for _sh in "$SCRIPT_DIR"/*.sh; do
        sed -i 's/\r//' "$_sh" 2>/dev/null || true
    done
    unset _sh
}

# ============================================================
# サブスクリプトの存在確認
# ============================================================
check_subscripts() {
    local missing=0
    for script in setup_flutter.sh setup_vscode.sh setup_node.sh; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            log_error "サブスクリプトが見つかりません: $SCRIPT_DIR/$script"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || exit 1
}

# ============================================================
# メイン
# ============================================================
main() {
    echo ""
    echo "========================================"
    echo "  開発環境 セットアップ"
    echo "  Flutter + VS Code + Node.js / Skills (Ubuntu 26.04 / WSL2)"
    echo "========================================"
    echo ""

    require_sudo
    strip_crlf
    check_subscripts

    # --- Flutter 開発環境 ---
    log_info "Flutter 開発環境のセットアップを開始します..."
    # shellcheck source=setup_flutter.sh
    source "$SCRIPT_DIR/setup_flutter.sh"
    flutter_main

    # --- VS Code 環境 ---
    log_info "VS Code 環境のセットアップを開始します..."
    # shellcheck source=setup_vscode.sh
    source "$SCRIPT_DIR/setup_vscode.sh"
    vscode_main

    # --- Node.js + Dart/Flutter Agent Skills ---
    log_info "Node.js / Dart・Flutter Agent Skills のセットアップを開始します..."
    # shellcheck source=setup_node.sh
    source "$SCRIPT_DIR/setup_node.sh"
    node_main

    echo "========================================"
    echo ""
    log_success "全セットアップ完了！"
    echo ""
    echo "次のステップ:"
    echo "  1. Android Studio を起動し、SDK Manager から"
    echo "     Android SDK (API 34+) と Build-Tools をインストール"
    echo "  2. 'flutter doctor --android-licenses' でライセンス承認"
    echo "  3. シェルを再起動: source ~/.bashrc (または ~/.zshrc)"
    echo ""
    echo "  iOS/Windows ビルドは Codemagic を利用してください。"
    echo ""
}

main "$@"
