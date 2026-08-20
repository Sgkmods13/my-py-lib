#!/usr/bin/env bash
#
# My Py Lib - Universal Installer
# Supports: Termux (Android), proot-distro Debian/Ubuntu inside Termux,
#           native Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, macOS.
#
# Permanent fixes included:
#   - Full upgrade BEFORE installing ffmpeg (prevents libc++/libplacebo
#     link mismatches on Termux)
#   - Auto self-heal if ffmpeg still fails to run/link after install
#   - Works with or without sudo (proot-distro Debian runs as root, often
#     without sudo installed at all)
#   - Handles Debian 12+ "externally-managed-environment" pip error
#     automatically (PEP 668)
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
PKG_UPGRADE=""
PKG_FIX=""

# Work out sudo prefix: use sudo only if it exists AND we're not already root
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    SUDO=""
fi

if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
    PLATFORM="termux"
    PKG_UPDATE="pkg update -y"
    PKG_UPGRADE="pkg upgrade -y"
    PKG_INSTALL="pkg install -y"
    PKG_FIX="dpkg --configure -a"

elif [ "$(uname -s)" = "Darwin" ]; then
    PLATFORM="macos"
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    PKG_UPDATE="brew update"
    PKG_UPGRADE="brew upgrade"
    PKG_INSTALL="brew install"

elif command -v apt >/dev/null 2>&1; then
    PLATFORM="debian"
    PKG_UPDATE="$SUDO apt update -y"
    PKG_UPGRADE="$SUDO apt full-upgrade -y"
    PKG_INSTALL="$SUDO apt install -y"
    PKG_FIX="$SUDO dpkg --configure -a && $SUDO apt --fix-broken install -y"

elif command -v dnf >/dev/null 2>&1; then
    PLATFORM="fedora"
    PKG_UPDATE="$SUDO dnf check-update -y || true"
    PKG_UPGRADE="$SUDO dnf upgrade -y"
    PKG_INSTALL="$SUDO dnf install -y"

elif command -v pacman >/dev/null 2>&1; then
    PLATFORM="arch"
    PKG_UPDATE="$SUDO pacman -Sy"
    PKG_UPGRADE="$SUDO pacman -Su --noconfirm"
    PKG_INSTALL="$SUDO pacman -S --noconfirm"

elif command -v zypper >/dev/null 2>&1; then
    PLATFORM="opensuse"
    PKG_UPDATE="$SUDO zypper refresh"
    PKG_UPGRADE="$SUDO zypper update -y"
    PKG_INSTALL="$SUDO zypper install -y"

else
    echo "ERROR: Unsupported platform. Could not detect a known package manager"
    echo "(pkg, apt, dnf, pacman, zypper, or brew)."
    echo "Please install python, ffmpeg, git, curl and wget manually, then re-run"
    echo "with SKIP_SYSTEM_DEPS=1 to skip this step."
    exit 1
fi

# Detect proot-distro (no $PREFIX, but Termux-style sandboxing underneath)
IS_PROOT=0
if [ "$PLATFORM" = "debian" ] && [ -f /etc/os-release ] && [ ! -d /data/data/com.termux ]; then
    if [ -f /.dockerenv ] || grep -qi proot /proc/1/comm 2>/dev/null || [ -d /run/proot ]; then
        IS_PROOT=1
    fi
fi

echo "Detected platform: $PLATFORM$( [ "$IS_PROOT" = "1" ] && echo " (proot-distro chroot)" )"
[ "$(id -u)" -eq 0 ] && echo "Running as root (no sudo needed)."
echo

# ---------------------------------------
# 2. Update + FULL upgrade package index
#
#    Upgrading everything (not just refreshing the index) BEFORE installing
#    ffmpeg is what prevents library-version mismatches (e.g. the Termux
#    libc++/libplacebo "CANNOT LINK EXECUTABLE" crash): ffmpeg is built
#    against whatever runtime libs are current in the repo, so if your
#    installed libc++ is older, the fresh ffmpeg binary won't link.
# ---------------------------------------
if [ -z "$SKIP_SYSTEM_DEPS" ]; then
    echo "[1/6] Updating package index..."
    eval "$PKG_UPDATE"
    echo
    echo "[2/6] Upgrading all installed packages (prevents library mismatches)..."
    eval "$PKG_UPGRADE"
else
    echo "[1/6] Skipping system update (SKIP_SYSTEM_DEPS set)."
    echo "[2/6] Skipping system upgrade (SKIP_SYSTEM_DEPS set)."
fi

# ---------------------------------------
# 3. Install required system packages
# ---------------------------------------
echo
echo "[3/6] Installing required packages..."
if [ -z "$SKIP_SYSTEM_DEPS" ]; then
    case "$PLATFORM" in
        termux)
            eval "$PKG_INSTALL python ffmpeg git curl wget"
            ;;
        macos)
            eval "$PKG_INSTALL python ffmpeg git curl wget"
            ;;
        debian)
            eval "$PKG_INSTALL python3 python3-pip python3-venv ffmpeg git curl wget sudo"
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
# 4. Verify / self-heal ffmpeg
#
#    If ffmpeg still fails to run (stale shared libs, a stuck dpkg state
#    from a previous failed install, etc.) this automatically runs the
#    recovery sequence instead of leaving the user stuck.
# ---------------------------------------
verify_ffmpeg() {
    ffmpeg -version >/dev/null 2>&1
}

if [ -z "$SKIP_SYSTEM_DEPS" ] && [ -n "$PKG_FIX" ]; then
    echo
    echo "Verifying ffmpeg..."
    if ! verify_ffmpeg; then
        echo "ffmpeg failed to run — applying automatic repair..."
        echo

        eval "$PKG_FIX" || true

        case "$PLATFORM" in
            termux)
                pkg install -y libc++ >/dev/null 2>&1 || true
                ;;
            debian)
                $SUDO apt install -y --reinstall libc6 >/dev/null 2>&1 || true
                ;;
        esac

        eval "$PKG_UPDATE"
        eval "$PKG_UPGRADE"

        case "$PLATFORM" in
            termux) pkg reinstall -y ffmpeg 2>/dev/null || pkg install -y ffmpeg ;;
            debian) $SUDO apt install -y --reinstall ffmpeg ;;
            *) eval "$PKG_INSTALL ffmpeg" ;;
        esac

        if ! verify_ffmpeg && [ "$PLATFORM" = "termux" ]; then
            echo "Still broken — retrying with a fresh mirror..."
            termux-change-repo || true
            pkg update -y && pkg upgrade -y
            pkg reinstall -y ffmpeg 2>/dev/null || pkg install -y ffmpeg
        fi

        if verify_ffmpeg; then
            echo "ffmpeg repaired successfully."
        else
            echo "WARNING: ffmpeg is still not working after automatic repair."
            if [ "$PLATFORM" = "termux" ]; then
                echo "Manually run: pkg upgrade -y && pkg reinstall ffmpeg"
                echo "If that fails: https://github.com/termux/termux-packages/issues"
            else
                echo "Manually run: $SUDO apt --fix-broken install -y && $SUDO apt install --reinstall -y ffmpeg"
            fi
        fi
    else
        echo "ffmpeg OK."
    fi
fi

# ---------------------------------------
# 5. Pick python binary
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
# 6. Install SpotDL
#
#    Debian 12+ (what proot-distro installs) blocks system-wide pip
#    installs by default (PEP 668, "externally-managed-environment").
#    Try normally first, and only fall back to --break-system-packages
#    if that specific error occurs.
# ---------------------------------------
echo
echo "[4/6] Installing SpotDL..."

pip_install() {
    if ! "$PYTHON_BIN" -m pip install --upgrade "$@" 2>/tmp/pip_err.log; then
        if grep -qi "externally-managed-environment" /tmp/pip_err.log; then
            echo "Debian's pip is externally managed — retrying with --break-system-packages..."
            "$PYTHON_BIN" -m pip install --upgrade --break-system-packages "$@"
        else
            cat /tmp/pip_err.log
            return 1
        fi
    fi
}

pip_install pip
pip_install spotdl

if ! command -v spotdl >/dev/null 2>&1; then
    if ! "$PYTHON_BIN" -m spotdl --version >/dev/null 2>&1; then
        echo "ERROR: SpotDL installation failed."
        exit 1
    fi
    SPOTDL_CMD="$PYTHON_BIN -m spotdl"
else
    SPOTDL_CMD="spotdl"
fi

# ---------------------------------------
# 7. Optional Deno installation
# ---------------------------------------
echo
echo "[5/6] Optional Deno installation"
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
# 8. Verify installation
# ---------------------------------------
echo
echo "[6/6] Checking installation..."
echo

echo "Python:"
"$PYTHON_BIN" --version

echo
echo "SpotDL:"
$SPOTDL_CMD --version

echo
echo "FFmpeg:"
if verify_ffmpeg; then
    ffmpeg -version | head -n 1
else
    echo "NOT WORKING - see warning above."
fi

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
