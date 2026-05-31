#!/bin/bash
# VS Code + 拡張機能 セットアップ
# 対象: Linux / macOS（x86_64 / arm64）
# スタンドアロン実行可: ./setup_vscode.sh
# setup.sh からの呼び出しも可
set -e

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

VSCODE_EXTENSIONS=(
    "MS-CEINTL.vscode-language-pack-ja"
    "eamodio.gitlens"
    "GitHub.vscode-pull-request-github"
    "Dart-Code.flutter"
    "Dart-Code.dart-code"
    "anthropics.claude-code"
    "ms-azuretools.vscode-docker"
)

# ============================================================
# 1. VS Code インストール（Linux のみ。macOS / Windows は手動）
# ============================================================
install_vscode() {
    log_info "VS Code を確認中..."

    if command -v code &>/dev/null; then
        log_success "VS Code は既にインストール済みです ($(code --version | head -1))"
        return
    fi

    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_warn "VS Code の自動インストールは Linux のみ対応しています。"
        log_warn "https://code.visualstudio.com/ から手動でインストールしてください。"
        return
    fi

    log_info "VS Code をインストール中（Linux）..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/microsoft-archive-keyring.gpg > /dev/null

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] \
https://packages.microsoft.com/repos/vscode stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    sudo apt-get update -qq
    sudo apt-get install -y code
    log_success "VS Code インストール完了 ($(code --version | head -1))"
}

# ============================================================
# 2. 拡張機能インストール
# ============================================================
install_vscode_extensions() {
    log_info "VS Code 拡張機能をインストール中..."

    if ! command -v code &>/dev/null; then
        log_warn "'code' コマンドが見つかりません。拡張機能のインストールをスキップします。"
        return
    fi

    local installed_list
    installed_list=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

    local installed_count=0
    local skipped_count=0

    for ext in "${VSCODE_EXTENSIONS[@]}"; do
        local ext_lower
        ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        if echo "$installed_list" | grep -qF "$ext_lower"; then
            log_success "スキップ（インストール済み）: $ext"
            (( skipped_count++ )) || true
        else
            log_info "インストール中: $ext"
            if code --install-extension "$ext" --force 2>/dev/null; then
                log_success "インストール完了: $ext"
                (( installed_count++ )) || true
            else
                log_warn "インストール失敗（後で手動インストールしてください）: $ext"
            fi
        fi
    done

    echo ""
    log_success "拡張機能: ${installed_count}個インストール、${skipped_count}個スキップ（インストール済み）"
}

# ============================================================
# メイン
# ============================================================
vscode_main() {
    echo ""
    echo "========================================"
    echo "  VS Code 環境 セットアップ"
    echo "========================================"
    echo ""

    install_vscode
    install_vscode_extensions

    log_success "VS Code 環境セットアップ完了"
    echo ""
    echo "次のステップ:"
    echo "  - VS Code を起動: code ."
    echo "  - 日本語 UI の適用には VS Code の再起動が必要な場合があります"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$OSTYPE" == "linux-gnu"* ]] && [ "$EUID" -ne 0 ]; then
        sudo -v || { log_error "sudo 権限が必要です"; exit 1; }
        while true; do sudo -n true; sleep 50; done &
        SUDO_KEEPALIVE_PID=$!
        trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
    fi
    vscode_main
fi
