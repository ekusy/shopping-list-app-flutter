#!/bin/bash
# VS Code + 拡張機能 セットアップ
# 対象: Ubuntu 26.04+ (x86_64) / WSL2
# スタンドアロン実行可: ./setup_vscode.sh
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
# WSL2 判定
# ============================================================
is_wsl2() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# ============================================================
# インストールする拡張機能リスト
# 追加する場合はこの配列に ID を追記するだけでよい
# ============================================================
VSCODE_EXTENSIONS=(
    # 日本語化パック
    "MS-CEINTL.vscode-language-pack-ja"
    # GitHub 連携強化
    "eamodio.gitlens"
    "GitHub.vscode-pull-request-github"
    # Flutter 開発支援（デバッグ・コード整形など）
    "Dart-Code.flutter"
    "Dart-Code.dart-code"
    # Claude 利用支援
    "anthropics.claude-code"
    # Docker 利用支援
    "ms-azuretools.vscode-docker"
)

# ============================================================
# 1. VS Code インストール（ネイティブ Linux のみ）
# ============================================================
install_vscode() {
    if is_wsl2; then
        log_warn "WSL2 環境を検出しました。VS Code 本体のインストールをスキップします。"
        log_warn "Windows 側で VS Code がインストール済みであることを確認してください。"
        log_warn "Remote - WSL 拡張機能が必要です: ms-vscode-remote.remote-wsl"
        return
    fi

    log_info "VS Code をインストール中..."
    if which code &>/dev/null; then
        log_success "VS Code は既にインストール済みです ($(code --version | head -1))"
        return
    fi

    # Microsoft GPG キーの登録
    log_info "Microsoft GPG キーを登録中..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/microsoft-archive-keyring.gpg > /dev/null

    # APT リポジトリの追加
    log_info "VS Code APT リポジトリを追加中..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    sudo apt-get update -qq
    sudo apt-get install -y code
    log_success "VS Code インストール完了 ($(code --version | head -1))"
}

# ============================================================
# 2. VS Code 拡張機能インストール
# ============================================================
install_vscode_extensions() {
    log_info "VS Code 拡張機能をインストール中..."

    if ! which code &>/dev/null; then
        log_warn "'code' コマンドが見つかりません。VS Code 拡張機能のインストールをスキップします。"
        if is_wsl2; then
            log_warn "WSL2 の場合: Windows 側で VS Code を起動し Remote - WSL で接続後、"
            log_warn "再度このスクリプトを実行するか手動でインストールしてください。"
        fi
        return 0
    fi

    # 既インストール済み拡張機能一覧を取得（大文字小文字を無視した比較用）
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
    if is_wsl2; then
        echo "WSL2 環境での注意:"
        echo "  - VS Code は Windows 側から起動してください"
        echo "  - Remote - WSL 拡張機能 (ms-vscode-remote.remote-wsl) をインストールしてください"
        echo "  - WSL 上のプロジェクトを開くには: code ."
    else
        echo "次のステップ:"
        echo "  - VS Code を起動: code ."
        echo "  - 日本語UIの適用にはVS Codeの再起動が必要な場合があります"
    fi
    echo ""
}

# スタンドアロン実行時のみ main を呼び出す
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! is_wsl2 && [ "$EUID" -eq 0 ]; then
        log_error "rootで実行しないでください。sudoは内部で使用します。"
        exit 1
    fi
    if ! is_wsl2; then
        sudo -v || { log_error "sudo 権限が必要です"; exit 1; }
        while true; do sudo -n true; sleep 50; done &
        SUDO_KEEPALIVE_PID=$!
        trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
    fi
    vscode_main
fi
