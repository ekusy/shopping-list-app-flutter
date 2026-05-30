#!/bin/bash
# Flutter 開発環境セットアップ
# 対象: Ubuntu 26.04+ (x86_64)
# スタンドアロン実行可: ./setup_flutter.sh
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
# sudo keepalive（スタンドアロン時のみ実行）
# ============================================================
_flutter_standalone() {
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
# 1. Flutter (snap)
# ============================================================
install_flutter() {
    log_info "Flutter をインストール中..."
    # /snap/bin を PATH の先頭に置き、Windows版(CRLF)より優先させる
    export PATH="/snap/bin:$PATH"
    if snap list flutter &>/dev/null; then
        log_success "Flutter は既にインストール済みです"
        /snap/bin/flutter --version
        return
    fi
    sudo snap install flutter --classic
    log_success "Flutter インストール完了"
    /snap/bin/flutter --version
}

# ============================================================
# 2. Android Studio (snap)
# ============================================================
install_android_studio() {
    log_info "Android Studio をインストール中..."
    if snap list android-studio &>/dev/null; then
        log_success "Android Studio は既にインストール済みです"
        return
    fi
    sudo snap install android-studio --classic
    log_success "Android Studio インストール完了"
}

# ============================================================
# 3. Web 開発用ブラウザ (Chromium)
# ============================================================
install_chromium() {
    log_info "Chromium (Web 開発用) を確認中..."
    if which google-chrome &>/dev/null || which chromium &>/dev/null || which chromium-browser &>/dev/null; then
        log_success "Chrome/Chromium は既にインストール済みです"
        return
    fi
    log_info "Chromium をインストール中..."
    sudo snap install chromium
    log_success "Chromium インストール完了"
}

# ============================================================
# 4. Linux Desktop ビルドに必要な依存パッケージ
# ============================================================
install_linux_deps() {
    log_info "Linux Desktop ビルド用パッケージをインストール中..."
    sudo apt-get update -qq

    # Ubuntu バージョンによって利用可能な libstdc++ のメジャー番号が異なるため動的に選択
    local stdcpp_pkg
    stdcpp_pkg=$(apt-cache search '^libstdc\+\+-[0-9]+-dev$' 2>/dev/null \
        | awk '{print $1}' | sort -t'-' -k3 -n | tail -1)
    if [ -z "$stdcpp_pkg" ]; then
        log_warn "libstdc++-dev パッケージが見つかりません。スキップします。"
        stdcpp_pkg=""
    fi

    sudo apt-get install -y --no-install-recommends \
        clang cmake ninja-build pkg-config \
        libgtk-3-dev liblzma-dev \
        ${stdcpp_pkg:+"$stdcpp_pkg"} \
        curl git unzip xz-utils zip
    log_success "依存パッケージのインストール完了"
}

# ============================================================
# 5. Android SDK ライセンス承認
# ============================================================
accept_android_licenses() {
    log_info "Android SDK ライセンスを確認中..."
    if [ -z "$ANDROID_HOME" ]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
    fi

    if [ ! -d "$ANDROID_HOME" ]; then
        log_warn "Android SDK が見つかりません。"
        log_warn "Android Studio を起動して SDK を初期セットアップ後、"
        log_warn "このスクリプトを再実行するか、以下のコマンドを手動で実行してください:"
        echo ""
        echo "    flutter doctor --android-licenses"
        echo ""
        return
    fi

    log_info "Android ライセンスを承認中 (すべてに y を入力)..."
    yes | /snap/bin/flutter doctor --android-licenses 2>/dev/null || true
    log_success "Android ライセンス承認完了"
}

# ============================================================
# 6. シェル設定への PATH 追記
# ============================================================
configure_shell() {
    local SHELL_RC=""
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi

    # /snap/bin を先頭に置いてWindowsのflutter(CRLF版)より優先させる
    local LINE='export PATH="/snap/bin:$HOME/Android/Sdk/platform-tools:$PATH"'
    if ! grep -qF '/snap/bin' "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Flutter / Android SDK" >> "$SHELL_RC"
        echo "$LINE" >> "$SHELL_RC"
        log_success "PATH を $SHELL_RC に追加しました"
    else
        log_success "PATH は既に設定済みです ($SHELL_RC)"
    fi
}

# ============================================================
# 7. flutter doctor で環境チェック
# ============================================================
run_flutter_doctor() {
    log_info "flutter doctor を実行中..."
    echo ""
    /snap/bin/flutter doctor -v
    echo ""
}

# ============================================================
# メイン
# ============================================================
flutter_main() {
    echo ""
    echo "========================================"
    echo "  Flutter 開発環境 セットアップ"
    echo "========================================"
    echo ""

    install_flutter
    install_android_studio
    install_chromium
    install_linux_deps
    accept_android_licenses
    configure_shell
    run_flutter_doctor

    log_success "Flutter 環境セットアップ完了"
    echo ""
    echo "次のステップ:"
    echo "  1. Android Studio を起動し、SDK Manager から"
    echo "     Android SDK (API 34+) と Build-Tools をインストール"
    echo "  2. 'flutter doctor --android-licenses' でライセンス承認"
    echo "  3. シェルを再起動: source ~/.bashrc (または ~/.zshrc)"
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
    flutter_main
fi
