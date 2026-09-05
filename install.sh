#!/usr/bin/env bash
set -e

PANEL_URL="https://github.com/ytmcnet-byte/AA-project/raw/refs/heads/main/panel.zip"
DAEMON_URL="https://github.com/ytmcnet-byte/AA-project/raw/refs/heads/main/daemon.zip"

INSTALL_DIR="/opt/jtg"

log() {
    echo -e "\033[1;32m[JTG]\033[0m $1"
}

die() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    log "Installing required packages..."

    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y curl wget unzip git ca-certificates util-linux
    elif command_exists apk; then
        sudo apk add curl wget unzip git ca-certificates util-linux
    elif command_exists dnf; then
        sudo dnf install -y curl wget unzip git ca-certificates util-linux
    elif command_exists yum; then
        sudo yum install -y curl wget unzip git ca-certificates util-linux
    else
        die "Unsupported Linux distribution"
    fi
}

install_node() {
    if command_exists node && command_exists npm; then
        log "Node.js already installed: $(node -v)"
        return
    fi

    log "Installing Node.js 20..."

    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
}

install_panel() {
    log "Installing JTG Panel..."

    mkdir -p "$INSTALL_DIR/panel"
    cd "$INSTALL_DIR/panel"

    wget -q --show-progress "$PANEL_URL" -O panel.zip
    unzip -o panel.zip
    rm -f panel.zip

    # Handle ZIPs containing a single directory
    if [ -d "panel" ]; then
        shopt -s dotglob
        cp -a panel/. .
        rm -rf panel
        shopt -u dotglob
    fi

    if [ -f package.json ]; then
        npm install
    else
        die "package.json not found in panel.zip"
    fi

    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
        cp .env.example .env
    fi

    log "Panel installed in $INSTALL_DIR/panel"
}

install_daemon() {
    log "Installing JTG Daemon..."

    mkdir -p "$INSTALL_DIR/daemon"
    cd "$INSTALL_DIR/daemon"

    wget -q --show-progress "$DAEMON_URL" -O daemon.zip
    unzip -o daemon.zip
    rm -f daemon.zip

    if [ -d "daemon" ]; then
        shopt -s dotglob
        cp -a daemon/. .
        rm -rf daemon
        shopt -u dotglob
    fi

    if [ -f package.json ]; then
        npm install
    else
        die "package.json not found in daemon.zip"
    fi

    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
        cp .env.example .env
    fi

    chmod +x ./*.sh 2>/dev/null || true

    log "Daemon installed in $INSTALL_DIR/daemon"
}

show_info() {
    echo
    echo "========================================"
    echo "       JTG LOCAL PROCESS HOSTING"
    echo "========================================"
    echo
    echo "Panel : $INSTALL_DIR/panel"
    echo "Daemon: $INSTALL_DIR/daemon"
    echo
    echo "Docker: NOT USED"
    echo "Runtime: Local Process"
    echo "CPU: taskset"
    echo
}

install_packages

if command_exists apt-get; then
    install_node
else
    if ! command_exists node; then
        die "Node.js is required. Install Node.js 20 first."
    fi
fi

case "${1:-}" in
    panel)
        install_panel
        show_info
        echo "Start the panel according to its package.json scripts."
        ;;

    daemon)
        install_daemon
        show_info
        echo "Start the daemon according to its package.json scripts."
        ;;

    all)
        install_panel
        install_daemon
        show_info
        ;;

    *)
        echo
        echo "Usage:"
        echo "  $0 panel"
        echo "  $0 daemon"
        echo "  $0 all"
        echo
        echo "Panel VPS:"
        echo "  ./install.sh panel"
        echo
        echo "Node VPS:"
        echo "  ./install.sh daemon"
        echo
        echo "Both:"
        echo "  ./install.sh all"
        exit 1
        ;;
esac
