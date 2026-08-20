#!/usr/bin/env bash
#
# My Py Lib - Universal Installer
# Supports: Termux (Android), Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, macOS
#
set -e

echo "======================================"
echo "         My Py Lib - Installer"
echo "======================================"
echo

# ---------------------------------------
# 1. Detect platform / package manager
# ---------------------------------------
PLATFORM=""
PKG_INSTALL=""
PKG_UPDATE=""

if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
    PLATFORM="termux"
    PKG_UPDATE="pkg update -y"
    PKG_INSTALL="pkg install -y"

elif [ "$(uname -s)" = "Darwin" ]; then
    PLATFORM="macos"
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    PKG_UPDATE="brew update"
    PKG_INSTALL="brew install"

elif command -v apt >/dev/null 2>&1; then
    PLATFORM="debian"
    PKG_UPDATE="sudo apt update -y"
    PKG_INSTALL="sudo apt install -y"

elif command -v dnf >/dev/null 2>&1; then
    PLATFORM="fedora"
    PKG_UPDATE="sudo dnf check-update -y || true"
    PKG_INSTALL="sudo dnf install -y"

elif command -v pacman >/dev/null 2>&1; then
    PLATFORM="arch"
    PKG_UPDATE="sudo pacman -Sy"
    PKG_INSTALL="sudo pacman -S --noconfirm"

elif command -v zypper >/dev/null 2>&1; then
    PLATFORM="opensuse"
    PKG_UPDATE="sudo zypper refresh"
    PKG_INSTALL="sudo zypper install -y"

else
    echo "ERROR: Unsupported platform. Could not detect a known package manager"
    echo "(pkg, apt, dnf, pacman, zypper, or brew)."
    echo "Please install python, ffmpeg, git, curl and wget manually, then re-run"
    echo "with SKIP_SYSTEM_DEPS=1 to skip this step."
    exit 1
fi

echo "Detected platform: $PLATFORM"
echo

# ---------------------------------------
# 2. Update package index
# ---------------------------------------
if [ -z "$SKIP_SYSTEM_DEPS" ]; then
    echo "[1/5] Updating package index..."
    eval "$PKG_UPDATE"
else
    echo "[1/5] Skipping system update (SKIP_SYSTEM_DEPS set)."
fi

# ---------------------------------------
# 3. Install required system packages
# ---------------------------------------
echo
echo "[2/5] Installing required packages..."
if [ -z "$SKIP_SYSTEM_DEPS" ]; then
    case "$PLATFORM" in
        termux)
            eval "$PKG_INSTALL python ffmpeg git curl wget"
            ;;
        macos)
            eval "$PKG_INSTALL python ffmpeg git curl wget"
            ;;
        debian)
            eval "$PKG_INSTALL python3 python3-pip python3-venv ffmpeg git curl wget"
            ;;
        fedora)
            eval "$PKG_INSTALL python3 python3-pip ffmpeg git curl wget"
            ;;
        arch)
            eval "$PKG_INSTALL python python-pip ffmpeg git curl wget"
            ;;
        opensuse)
            eval "$PKG_INSTALL python3 python3-pip ffmpeg git curl wget"
            ;;
    esac
else
    echo "Skipping (SKIP_SYSTEM_DEPS set)."
fi

# ---------------------------------------
# 4. Pick python binary
# ---------------------------------------
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    echo "ERROR: No python interpreter found after installation."
    exit 1
fi

# ---------------------------------------
# 5. Install SpotDL
# ---------------------------------------
echo
echo "[3/5] Installing SpotDL..."
"$PYTHON_BIN" -m pip install --upgrade pip
"$PYTHON_BIN" -m pip install --upgrade spotdl

if ! command -v spotdl >/dev/null 2>&1; then
    # Fall back to python -m spotdl if the entry point isn't on PATH
    if ! "$PYTHON_BIN" -m spotdl --version >/dev/null 2>&1; then
        echo "ERROR: SpotDL installation failed."
        exit 1
    fi
    SPOTDL_CMD="$PYTHON_BIN -m spotdl"
else
    SPOTDL_CMD="spotdl"
fi

# ---------------------------------------
# 6. Optional Deno installation
# ---------------------------------------
echo
echo "[4/5] Optional Deno installation"
echo
echo "Deno is optional."
printf "Do you want to install Deno? [Y/n]: "
read -r DENO_CHOICE

if [[ "$DENO_CHOICE" =~ ^[Yy]$ || -z "$DENO_CHOICE" ]]; then
    if command -v deno >/dev/null 2>&1; then
        echo "Deno is already installed."
    else
        case "$PLATFORM" in
            termux)
                if apt-cache show deno >/dev/null 2>&1; then
                    pkg install -y deno
                else
                    echo "Deno is not available in this Termux repository. Skipping."
                fi
                ;;
            macos)
                brew install deno
                ;;
            debian|fedora|arch|opensuse)
                echo "Installing Deno via official install script..."
                curl -fsSL https://deno.land/install.sh | sh
                export PATH="$HOME/.deno/bin:$PATH"
                echo "NOTE: add \"$HOME/.deno/bin\" to your PATH permanently (e.g. in ~/.bashrc)."
                ;;
        esac
    fi
else
    echo "Deno installation skipped."
fi

# ---------------------------------------
# 7. Verify installation
# ---------------------------------------
echo
echo "[5/5] Checking installation..."
echo

echo "Python:"
"$PYTHON_BIN" --version

echo
echo "SpotDL:"
$SPOTDL_CMD --version

echo
echo "FFmpeg:"
ffmpeg -version | head -n 1

echo
if command -v deno >/dev/null 2>&1; then
    echo "Deno:"
    deno --version | head -n 1
else
    echo "Deno: Not installed (optional)"
fi

echo
echo "======================================"
echo "       Installation completed!"
echo "======================================"
echo
echo "Run SpotDL:"
echo "  $SPOTDL_CMD --help"
echo
