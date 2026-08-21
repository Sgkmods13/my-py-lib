#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#                    My Py Lib - SpotDL
#          Universal Diagnose-First Installer
#
#   Every device is profiled first (arch, RAM, free storage,
#   Android version, network). Based on that diagnosis the
#   script picks the best install path for THIS device:
#
#     - DEBIAN mode  : proot-distro + Debian + venv (default,
#                       best isolation, used on capable devices)
#     - NATIVE mode   : installs directly inside Termux with no
#                       proot-distro/Debian layer at all (used on
#                       low-RAM / low-storage / unsupported-arch
#                       devices, or if Debian fails to start)
#
#   Every step is idempotent — safe to re-run any time to
#   repair, update, or switch modes.
#
#                    Credit: @Sgkmods13
# ============================================================

set -e

CREDIT="@Sgkmods13"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
MODE_FILE="$HOME/.spotdl-install-mode"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${RESET} $1"; }
fail() { echo -e "${RED}[ERROR]${RESET} $1"; }
step() { echo -e "\n${BOLD}$1${RESET}"; }

clear

echo "================================================"
echo "              My Py Lib - SpotDL"
echo "================================================"
echo "     Universal Diagnose-First Installer"
echo "              $CREDIT"
echo "================================================"
echo

# ------------------------------------------------------------
# Termux sanity check
# ------------------------------------------------------------

if [ ! -d "/data/data/com.termux" ]; then
    fail "This installer must be run inside Termux."
    exit 1
fi

if ! command -v pkg >/dev/null 2>&1; then
    fail "Termux package manager (pkg) was not found."
    fail "Make sure you're running the official Termux app (F-Droid or GitHub build)."
    exit 1
fi

pkg update -y >/dev/null 2>&1 || warn "Could not refresh package lists (offline?)."
pkg install -y coreutils curl ca-certificates >/dev/null 2>&1 || true

# ============================================================
#                     DIAGNOSTIC PHASE
# ============================================================

step "[DIAGNOSE] Scanning device..."

# --- Architecture -------------------------------------------------
ARCH="$(uname -m)"

# --- Android version (best effort) --------------------------------
ANDROID_VERSION="unknown"
if command -v getprop >/dev/null 2>&1; then
    ANDROID_VERSION="$(getprop ro.build.version.release 2>/dev/null || echo unknown)"
fi

# --- SDK / API level (helps flag very old Android builds) ---------
SDK_LEVEL="unknown"
if command -v getprop >/dev/null 2>&1; then
    SDK_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null || echo unknown)"
fi

# --- RAM ------------------------------------------------------------
TOTAL_RAM_MB=0
if [ -r /proc/meminfo ]; then
    TOTAL_RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
fi

# --- Free storage in Termux home ------------------------------------
FREE_STORAGE_MB=0
if command -v df >/dev/null 2>&1; then
    FREE_STORAGE_MB="$(df -m "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
    [ -z "$FREE_STORAGE_MB" ] && FREE_STORAGE_MB=0
fi

# --- CPU cores --------------------------------------------------------
CPU_CORES="$(nproc 2>/dev/null || echo 1)"

# --- Network reachability ----------------------------------------------
NETWORK_OK=0
if curl -fsSL --max-time 6 https://pypi.org >/dev/null 2>&1; then
    NETWORK_OK=1
fi

# --- proot-distro / Debian architecture support ------------------------
# proot-distro's Debian rootfs is only published for these arches.
DEBIAN_ARCH_OK=0
case "$ARCH" in
    aarch64|arm64|armv7l|armv8l|arm|x86_64|i686|i386|x86)
        DEBIAN_ARCH_OK=1
        ;;
    *)
        DEBIAN_ARCH_OK=0
        ;;
esac

# ------------------------------------------------------------
# Report
# ------------------------------------------------------------

echo
echo "------------------ DEVICE REPORT ------------------"
printf "%-22s %s\n" "Architecture:"     "$ARCH"
printf "%-22s %s\n" "Android version:"  "$ANDROID_VERSION (SDK $SDK_LEVEL)"
printf "%-22s %s MB\n" "Total RAM:"     "$TOTAL_RAM_MB"
printf "%-22s %s MB\n" "Free storage:"  "$FREE_STORAGE_MB"
printf "%-22s %s\n" "CPU cores:"        "$CPU_CORES"
if [ "$NETWORK_OK" -eq 1 ]; then
    printf "%-22s %s\n" "Network:" "OK"
else
    printf "%-22s %s\n" "Network:" "UNREACHABLE"
fi
echo "-----------------------------------------------------"
echo

if [ "$NETWORK_OK" -eq 0 ]; then
    fail "No internet connectivity detected. Connect to a network and re-run this installer."
    exit 1
fi

# ------------------------------------------------------------
# Decide install mode
#
# DEBIAN mode needs: supported arch, reasonable free storage
# (Debian rootfs + build toolchain + venv ≈ 900MB-1.2GB), and
# at least a little RAM headroom for compiling wheels.
#
# Anything below those thresholds — or an arch proot-distro's
# Debian doesn't ship for — falls back to NATIVE mode, which
# installs Python/ffmpeg/spotdl straight into Termux with no
# extra rootfs, using far less RAM and storage.
# ------------------------------------------------------------

INSTALL_MODE="debian"
REASONS=()

if [ "$DEBIAN_ARCH_OK" -eq 0 ]; then
    INSTALL_MODE="native"
    REASONS+=("architecture '$ARCH' has no proot-distro Debian build")
fi

if [ "$FREE_STORAGE_MB" -gt 0 ] && [ "$FREE_STORAGE_MB" -lt 1200 ]; then
    INSTALL_MODE="native"
    REASONS+=("free storage is low (${FREE_STORAGE_MB}MB, Debian needs ~1.2GB+)")
fi

if [ "$TOTAL_RAM_MB" -gt 0 ] && [ "$TOTAL_RAM_MB" -lt 1024 ]; then
    INSTALL_MODE="native"
    REASONS+=("device RAM is very low (${TOTAL_RAM_MB}MB)")
fi

# Respect an explicit override: ./install.sh --native or --debian
for arg in "$@"; do
    case "$arg" in
        --native) INSTALL_MODE="native"; REASONS=("forced by --native flag") ;;
        --debian)
            if [ "$DEBIAN_ARCH_OK" -eq 1 ]; then
                INSTALL_MODE="debian"; REASONS=("forced by --debian flag")
            else
                warn "--debian was requested but this architecture ($ARCH) has no Debian build. Staying on native mode."
            fi
            ;;
    esac
done

if [ "$INSTALL_MODE" = "native" ]; then
    warn "Selected install path: NATIVE (direct Termux install, no Debian)"
    for r in "${REASONS[@]:-}"; do
        [ -n "$r" ] && warn "  - $r"
    done
else
    ok "Selected install path: DEBIAN (proot-distro, full isolation)"
fi

# Build-thread tuning based on RAM (used by both modes)
if [ "$TOTAL_RAM_MB" -gt 0 ]; then
    if [ "$TOTAL_RAM_MB" -le 2048 ]; then
        BUILD_JOBS=1
    elif [ "$TOTAL_RAM_MB" -le 4096 ]; then
        BUILD_JOBS=2
    else
        BUILD_JOBS="$CPU_CORES"
    fi
else
    BUILD_JOBS=1
fi

echo "$INSTALL_MODE" > "$MODE_FILE"

# ------------------------------------------------------------
# Helper: install a Termux package only if missing
# ------------------------------------------------------------

ensure_termux_pkg() {
    local pkg_name="$1"
    if ! dpkg -s "$pkg_name" >/dev/null 2>&1; then
        info "Installing missing package: $pkg_name"
        pkg install -y "$pkg_name"
    else
        ok "$pkg_name already present, skipping."
    fi
}

# ------------------------------------------------------------
# Storage permission (both modes need it for saving music)
# ------------------------------------------------------------

step "[SETUP] Checking Android storage permission..."

if [ ! -d "$HOME/storage/shared" ]; then
    if command -v termux-setup-storage >/dev/null 2>&1; then
        echo "Android will ask for storage permission. Please press ALLOW."
        termux-setup-storage || true
        sleep 3
    fi
fi

if [ -d "$HOME/storage/shared" ]; then
    ok "Storage is available."
else
    warn "Storage is not available. Run: termux-setup-storage"
fi

MUSIC_DIR="$HOME/storage/shared/Music/SpotDL"
mkdir -p "$MUSIC_DIR" 2>/dev/null || true

# ============================================================
#                        DEBIAN MODE
# ============================================================

install_debian_mode() {
    step "[DEBIAN] Installing base Termux requirements..."

    for p in proot-distro coreutils curl wget grep sed ca-certificates; do
        ensure_termux_pkg "$p"
    done

    if ! command -v proot-distro >/dev/null 2>&1; then
        fail "proot-distro could not be installed."
        exit 1
    fi

    step "[DEBIAN] Checking Debian rootfs..."

    debian_works() {
        proot-distro login debian -- /bin/true >/dev/null 2>&1
    }

    if debian_works; then
        ok "Debian is already installed and working — skipping install."
    else
        if proot-distro list 2>/dev/null | grep -Eiq '^\s*debian'; then
            info "Debian rootfs entry exists but failed to start. Reinstalling..."
            proot-distro reset debian >/dev/null 2>&1 || true
            proot-distro install debian
        else
            info "Installing Debian..."
            proot-distro install debian
        fi

        if ! debian_works; then
            fail "Debian could not be started even after reinstalling."
            warn "Falling back to NATIVE mode instead."
            INSTALL_MODE="native"
            echo "native" > "$MODE_FILE"
            install_native_mode
            return
        fi
        ok "Debian is installed and working."
    fi

    step "[DEBIAN] Installing SpotDL inside Debian..."

    SETUP="$PREFIX/.spotdl-debian-setup"

    cat > "$SETUP" <<DEBIAN_SETUP
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Updating Debian package lists..."
apt-get update

echo "[2/6] Checking required system packages..."
NEEDED_PKGS=""
for p in python3 python3-pip python3-venv python3-dev ffmpeg curl wget \\
         ca-certificates build-essential pkg-config libjpeg-dev zlib1g-dev \\
         libpng-dev libtiff-dev libfreetype6-dev liblcms2-dev libwebp-dev; do
    if ! dpkg -s "\$p" >/dev/null 2>&1; then
        NEEDED_PKGS="\$NEEDED_PKGS \$p"
    fi
done
if [ -n "\$NEEDED_PKGS" ]; then
    echo "Installing missing packages:\$NEEDED_PKGS"
    apt-get install -y \$NEEDED_PKGS
else
    echo "All required system packages already installed."
fi

echo "[3/6] Setting up virtual environment..."
VENV="\$HOME/spotdl-env"
[ -d "\$VENV" ] || python3 -m venv "\$VENV"
source "\$VENV/bin/activate"

export MAKEFLAGS="-j$BUILD_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="$BUILD_JOBS"
export PIP_NO_CACHE_DIR="1"
export PYTHONDONTWRITEBYTECODE="1"

echo "[4/6] Updating pip tools..."
python -m pip install --no-cache-dir --upgrade pip setuptools wheel

echo "[5/6] Installing Pillow + SpotDL..."
python -m pip install --no-cache-dir --upgrade Pillow
python -m pip install --no-cache-dir --upgrade spotdl

echo "[6/6] Verifying..."
python --version
ffmpeg -version | head -n 1
spotdl --version
python -c "import PIL; print('Pillow', PIL.__version__)"
echo "SpotDL (Debian mode) installation successful."
DEBIAN_SETUP

    chmod +x "$SETUP"

    proot-distro login debian -- \
        bash -c "
            cp '$SETUP' /root/setup-spotdl.sh
            chmod +x /root/setup-spotdl.sh
            /root/setup-spotdl.sh
            rm -f /root/setup-spotdl.sh
        "

    rm -f "$SETUP"

    if ! proot-distro login debian -- bash -lc 'test -x "$HOME/spotdl-env/bin/spotdl"'; then
        fail "SpotDL executable was not found after install."
        exit 1
    fi

    ok "SpotDL is installed (Debian mode)."
}

# ============================================================
#                        NATIVE MODE
# ============================================================

install_native_mode() {
    step "[NATIVE] Installing directly inside Termux (no Debian layer)..."

    for p in python build-essential libjpeg-turbo zlib libpng libwebp \
             freetype ffmpeg curl wget ca-certificates; do
        ensure_termux_pkg "$p" || warn "Optional package '$p' unavailable on this Termux repo — continuing."
    done

    if ! command -v python3 >/dev/null 2>&1; then
        fail "Python could not be installed via pkg."
        exit 1
    fi

    VENV="$HOME/spotdl-env-native"
    if [ ! -d "$VENV" ]; then
        info "Creating native virtual environment..."
        python3 -m venv "$VENV"
    else
        ok "Native virtual environment already exists — reusing it."
    fi

    # shellcheck disable=SC1090
    source "$VENV/bin/activate"

    export MAKEFLAGS="-j$BUILD_JOBS"
    export PIP_NO_CACHE_DIR="1"
    export PYTHONDONTWRITEBYTECODE="1"

    info "Updating pip tools (using $BUILD_JOBS build thread(s))..."
    python -m pip install --no-cache-dir --upgrade pip setuptools wheel

    info "Installing Pillow..."
    python -m pip install --no-cache-dir --upgrade Pillow

    info "Installing SpotDL..."
    python -m pip install --no-cache-dir --upgrade spotdl

    deactivate 2>/dev/null || true

    if [ ! -x "$VENV/bin/spotdl" ]; then
        fail "SpotDL executable was not found after native install."
        exit 1
    fi

    ok "SpotDL is installed (Native mode)."
}

# ------------------------------------------------------------
# Run the selected mode
# ------------------------------------------------------------

if [ "$INSTALL_MODE" = "debian" ]; then
    install_debian_mode
else
    install_native_mode
fi

# ============================================================
#           UNIVERSAL LAUNCHER (mode-aware, single command)
# ============================================================

step "[LAUNCHER] Creating unified 'spotdl-debian' command..."

LAUNCHER_PATH="$PREFIX/bin/spotdl-debian"

cat > "$LAUNCHER_PATH" <<LAUNCHER
#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#                    SpotDL Launcher (universal)
#                    @Sgkmods13
# ============================================================

MODE_FILE="\$HOME/.spotdl-install-mode"
MODE="debian"
[ -f "\$MODE_FILE" ] && MODE="\$(cat "\$MODE_FILE")"

if [ "\$MODE" = "native" ]; then
    VENV="\$HOME/spotdl-env-native"
    if [ ! -x "\$VENV/bin/spotdl" ]; then
        echo "ERROR: Native SpotDL environment not found."
        echo "Re-run the installer to fix this."
        exit 1
    fi
    source "\$VENV/bin/activate"
    if [ "\$#" -eq 0 ]; then
        spotdl --help
    else
        spotdl "\$@"
    fi
else
    if ! command -v proot-distro >/dev/null 2>&1; then
        echo "ERROR: proot-distro is not installed."
        exit 1
    fi
    if ! proot-distro login debian -- /bin/true >/dev/null 2>&1; then
        echo "ERROR: Debian cannot be started."
        echo "Run: proot-distro list"
        exit 1
    fi
    proot-distro login debian -- \\
        bash -lc '
            if [ ! -f "\$HOME/spotdl-env/bin/activate" ]; then
                echo "ERROR: SpotDL environment not found."
                echo "Re-run the installer to fix this."
                exit 1
            fi
            source "\$HOME/spotdl-env/bin/activate"
            if [ "\$#" -eq 0 ]; then
                spotdl --help
            else
                spotdl "\$@"
            fi
        ' -- "\$@"
fi
LAUNCHER

chmod +x "$LAUNCHER_PATH"
ok "spotdl-debian command is ready (mode: $INSTALL_MODE)."

# ------------------------------------------------------------
# Widget
# ------------------------------------------------------------

step "[WIDGET] Creating Termux:Widget shortcut..."

mkdir -p "$HOME/.shortcuts" "$HOME/.shortcuts/tasks"

cat > "$HOME/.shortcuts/SpotDL" <<WIDGET
#!/data/data/com.termux/files/usr/bin/bash

CREDIT="@Sgkmods13"
clear
echo "================================================"
echo "              SPOTDL DOWNLOADER"
echo "              Credit: \$CREDIT"
echo "================================================"
echo

if [ ! -d "\$HOME/storage/shared" ]; then
    echo "Storage permission is required. Requesting..."
    termux-setup-storage || true
    sleep 3
fi

if [ ! -d "\$HOME/storage/shared" ]; then
    echo "ERROR: Android storage is unavailable."
    echo "Run this in Termux: termux-setup-storage"
    read -p "Press Enter to exit..."
    exit 1
fi

MODE_FILE="\$HOME/.spotdl-install-mode"
MODE="debian"
[ -f "\$MODE_FILE" ] && MODE="\$(cat "\$MODE_FILE")"

DOWNLOAD_DIR="\$HOME/storage/shared/Music/SpotDL"
mkdir -p "\$DOWNLOAD_DIR"

echo "Mode: \$MODE"
echo "Downloads will be saved to:"
echo "\$DOWNLOAD_DIR"
echo

read -p "Paste a Spotify/YouTube link (or search term): " QUERY

if [ -z "\$QUERY" ]; then
    echo "No input given. Exiting."
    read -p "Press Enter to exit..."
    exit 0
fi

echo
echo "Starting download..."
echo

if [ "\$MODE" = "native" ]; then
    VENV="\$HOME/spotdl-env-native"
    if [ ! -x "\$VENV/bin/spotdl" ]; then
        echo "ERROR: SpotDL not installed. Re-run the main installer."
        read -p "Press Enter to exit..."
        exit 1
    fi
    source "\$VENV/bin/activate"
    cd "\$DOWNLOAD_DIR"
    spotdl download "\$QUERY"
else
    if ! command -v proot-distro >/dev/null 2>&1 || ! proot-distro login debian -- /bin/true >/dev/null 2>&1; then
        echo "ERROR: Debian is not available. Re-run the main installer to repair it."
        read -p "Press Enter to exit..."
        exit 1
    fi
    proot-distro login debian -- \\
        bash -lc "
            source \\"\\\$HOME/spotdl-env/bin/activate\\"
            mkdir -p \\"\\\$HOME/spotdl-output\\"
            spotdl download '\$QUERY' --output '/root/spotdl-output/{title}.{output-ext}'
        "
    echo
    echo "Files were saved inside Debian at ~/spotdl-output"
    echo "Move them into \$DOWNLOAD_DIR to see them in your Music app."
fi

echo
read -p "Press Enter to exit..."
WIDGET

chmod +x "$HOME/.shortcuts/SpotDL"
ok "Widget shortcut created: SpotDL"

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "================================================"
echo "        INSTALLATION COMPLETE"
echo "================================================"
echo "Mode used:      $INSTALL_MODE"
echo "Architecture:   $ARCH"
echo "RAM:            ${TOTAL_RAM_MB}MB"
echo "Free storage:   ${FREE_STORAGE_MB}MB"
echo
echo "Run from Termux:"
echo "  spotdl-debian <spotify-url>"
echo
echo "Or add the 'SpotDL' Termux:Widget to your home screen"
echo "(long-press home screen -> Widgets -> Termux:Widget)."
echo
echo "Force a specific mode next time with:"
echo "  bash install.sh --native"
echo "  bash install.sh --debian"
echo
echo "This installer is safe to re-run any time to repair,"
echo "update, or switch install modes."
echo "================================================"
echo
