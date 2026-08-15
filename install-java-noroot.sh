#!/bin/bash
# ================================================
# Non-Root Multi-Java Installer for MCPanel
# ================================================
# Installs Java 8, 11, 17, 21, 22 into $HOME/java/<version> WITHOUT root/sudo,
# using prebuilt Eclipse Temurin (Adoptium) binaries. Also creates named
# wrapper commands (java8, java11, java17, java21, java22) on your PATH so
# MCPanel's javaManager.js auto-detects every one of them.
#
# Usage:
#   chmod +x install-java-noroot.sh
#   ./install-java-noroot.sh              # installs all versions
#   ./install-java-noroot.sh 17 21        # installs only specific versions
#
# After running, restart your shell (or `source ~/.bashrc`) and run:
#   java8 -version
#   java21 -version
# to confirm.

set -e

JAVA_BASE="$HOME/java"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$JAVA_BASE" "$BIN_DIR"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) JVM_ARCH="x64" ;;
    aarch64|arm64) JVM_ARCH="aarch64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS="linux"

# Eclipse Temurin API gives us a direct download link for any (version, os, arch)
temurin_url() {
    local major=$1
    echo "https://api.adoptium.net/v3/binary/latest/${major}/ga/${OS}/${JVM_ARCH}/jdk/hotspot/normal/eclipse"
}

install_version() {
    local major=$1
    local target="$JAVA_BASE/java${major}"

    if [ -x "$target/bin/java" ]; then
        echo "✅ Java $major already installed at $target — skipping (delete the folder to reinstall)"
    else
        echo "⬇️  Downloading Java $major (Temurin, $JVM_ARCH)..."
        mkdir -p "$target"
        local tmp_tar="/tmp/jdk${major}-$$.tar.gz"

        if ! curl -fsSL -o "$tmp_tar" "$(temurin_url "$major")"; then
            echo "❌ Download failed for Java $major. It may not exist for this arch/OS, or you're offline."
            rm -rf "$target"
            return 1
        fi

        echo "📦 Extracting Java $major..."
        tar -xzf "$tmp_tar" -C "$target" --strip-components=1
        rm -f "$tmp_tar"

        if [ ! -x "$target/bin/java" ]; then
            echo "❌ Extraction did not produce a working java binary for $major"
            rm -rf "$target"
            return 1
        fi
        echo "✅ Java $major installed to $target"
    fi

    # Named wrapper on PATH: java8, java11, java17, java21, java22...
    ln -sf "$target/bin/java" "$BIN_DIR/java${major}"
    echo "🔗 Linked $BIN_DIR/java${major} -> $target/bin/java"
}

VERSIONS=("$@")
if [ ${#VERSIONS[@]} -eq 0 ]; then
    VERSIONS=(8 11 17 21 22)
fi

echo "================================================"
echo " MCPanel Non-Root Java Installer"
echo " Installing versions: ${VERSIONS[*]}"
echo " Target directory:    $JAVA_BASE"
echo " Wrapper commands in: $BIN_DIR"
echo "================================================"
echo ""

FAILED=()
for v in "${VERSIONS[@]}"; do
    install_version "$v" || FAILED+=("$v")
    echo ""
done

# Make sure ~/.local/bin is on PATH permanently
SHELL_RC="$HOME/.bashrc"
[ -n "$ZSH_VERSION" ] && SHELL_RC="$HOME/.zshrc"

if ! grep -q '.local/bin' "$SHELL_RC" 2>/dev/null; then
    echo '' >> "$SHELL_RC"
    echo '# Added by MCPanel non-root Java installer' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo "📝 Added \$HOME/.local/bin to PATH in $SHELL_RC"
fi
export PATH="$BIN_DIR:$PATH"

echo "================================================"
echo " Done."
echo "================================================"
for v in "${VERSIONS[@]}"; do
    if [ -x "$BIN_DIR/java${v}" ]; then
        echo -n "java${v}: "
        "$BIN_DIR/java${v}" -version 2>&1 | head -1
    fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Failed to install: ${FAILED[*]}"
    echo "   Check your internet connection / try again, or install manually."
fi

echo ""
echo "👉 Run:  source $SHELL_RC"
echo "👉 Then restart the MCPanel daemon/panel so it picks up the new Java versions."
echo "   (javaManager.js checks 'java8', 'java11', 'java17', 'java21', 'java22' on PATH automatically)"
