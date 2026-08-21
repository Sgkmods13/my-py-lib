#!/data/data/com.termux/files/usr/bin/bash

# Not `set -e` globally — a hard-crash on the first transient failure
# (flaky mirror, one bad package) is exactly what makes this installer
# feel "incompatible" on some devices when the real issue is recoverable.
# Each step below checks its own exit status explicitly instead.
set -uo pipefail

CREDIT="@Sgkmods13"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
LOGFILE="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/spotdl-install.log"

# ============================================================
#                 My Py Lib - SpotDL
#          Complete Termux + Debian Installer
#                 Termux:Widget Support
#                 Credit: @Sgkmods13
# ============================================================

banner() {
    clear
    echo "================================================"
    echo "              My Py Lib - SpotDL"
    echo "          Termux + Debian + Python"
    echo "              Termux:Widget"
    echo "              Credit: $CREDIT"
    echo "================================================"
    echo
}

log() {
    echo "$(date '+%H:%M:%S') $*" >> "$LOGFILE" 2>/dev/null || true
}

die() {
    echo
    echo "ERROR: $*"
    echo "       See log for details: $LOGFILE"
    exit 1
}

# Retry a flaky command a few times before giving up (mobile networks /
# mirror hiccups are the #1 cause of installs failing halfway through).
retry() {
    local tries=3 n=1 delay=3
    until "$@"; do
        if [ "$n" -ge "$tries" ]; then
            return 1
        fi
        echo "  (attempt $n failed, retrying in ${delay}s...)"
        sleep "$delay"
        n=$((n + 1))
    done
    return 0
}

banner
: > "$LOGFILE" 2>/dev/null || true

# ------------------------------------------------------------
# Check Termux (real detection, not just a PREFIX default check)
# ------------------------------------------------------------

is_termux() {
    [ -n "${TERMUX_VERSION:-}" ] && return 0
    case "$PREFIX" in
        */com.termux/*) : ;;
        *) return 1 ;;
    esac
    command -v termux-info >/dev/null 2>&1 || command -v termux-setup-storage >/dev/null 2>&1 || return 1
    return 0
}

if ! is_termux; then
    die "This installer must be run inside Termux on Android (com.termux prefix / TERMUX_VERSION not detected)."
fi

# ------------------------------------------------------------
# Architecture detection
# ------------------------------------------------------------
# proot-distro maps these to the right Debian rootfs itself, but we
# still want to fail with a clear message on genuinely unsupported
# architectures rather than an opaque proot-distro error later.

ARCH="$(uname -m)"
case "$ARCH" in
    aarch64|arm64|armv7l|armv8l|armv7*|x86_64|i686|i386) : ;;
    *)
        die "Unsupported device architecture: $ARCH"
        ;;
esac
log "Detected architecture: $ARCH"

# ------------------------------------------------------------
# proot / kernel capability check
# ------------------------------------------------------------
# Some vendor Android kernels (MIUI, certain Samsung/OnePlus/OEM builds)
# restrict unshare()/ptrace via seccomp, which breaks proot-distro even
# though the package installs fine. Detect this early with a clear
# message instead of letting the user hit a confusing crash mid-install.

check_proot_capability() {
    command -v proot >/dev/null 2>&1 || return 0   # not installed yet, check later
    if ! proot --help >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# ------------------------------------------------------------
# Disk space check
# ------------------------------------------------------------
# A Debian rootfs + Python venv + spotdl/ffmpeg is roughly 600MB-1GB.
# Low-storage devices are a very common source of "it doesn't work on
# my phone" reports, so check up front instead of failing halfway in.

check_disk_space() {
    local min_kb=1500000  # ~1.5GB safety margin
    local avail_kb
    avail_kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
    if [ -z "$avail_kb" ]; then
        echo "  (could not determine free space, skipping check)"
        return 0
    fi
    log "Available space: ${avail_kb}KB"
    if [ "$avail_kb" -lt "$min_kb" ]; then
        echo
        echo "WARNING: Low storage detected (~$((avail_kb / 1024))MB free)."
        echo "         Debian + Python + spotdl needs roughly 1-1.5GB free."
        echo "         The install may fail partway through."
        read -p "Continue anyway? [y/N]: " CONT
        case "$CONT" in
            y|Y) : ;;
            *) die "Aborted due to low storage." ;;
        esac
    fi
}

check_disk_space

# ------------------------------------------------------------
# Install required Termux packages
# ------------------------------------------------------------

echo "[1/11] Updating Termux..."
if ! retry pkg update -y >> "$LOGFILE" 2>&1; then
    echo "  WARNING: pkg update failed after retries — continuing anyway,"
    echo "           but package installs below may fail too."
fi

echo
echo "[2/11] Installing required Termux packages..."
if ! retry pkg install -y proot-distro coreutils grep sed curl >> "$LOGFILE" 2>&1; then
    die "Failed to install required Termux packages after retries. Check: $LOGFILE"
fi

command -v proot-distro >/dev/null 2>&1 || die "proot-distro failed to install."

if ! check_proot_capability; then
    echo
    echo "WARNING: proot appears to be blocked by this device's kernel"
    echo "         (common on some MIUI / OEM ROMs with seccomp restrictions)."
    echo "         Debian install below will likely fail. If it does, this"
    echo "         is a device/kernel limitation, not a bug in this script —"
    echo "         there is no userspace fix for a kernel-level block."
fi

# ------------------------------------------------------------
# Storage permission (with a real write test, not just dir existence)
# ------------------------------------------------------------

echo
echo "[3/11] Requesting Termux storage permission..."

if [ ! -d "$HOME/storage/shared" ]; then
    termux-setup-storage || true
    sleep 3
fi

storage_writable() {
    [ -d "$HOME/storage/shared" ] || return 1
    local testfile="$HOME/storage/shared/.spotdl_write_test"
    ( : > "$testfile" ) 2>/dev/null && rm -f "$testfile" 2>/dev/null
}

if ! storage_writable; then
    echo
    echo "WARNING: Storage permission was granted but shared storage isn't"
    echo "         writable yet (common on Android 11+ with scoped storage"
    echo "         restrictions, or if permission was denied in a dialog)."
    echo "         Open Android Settings > Apps > Termux > Permissions and"
    echo "         enable Storage manually, then re-run this installer."
fi

# ------------------------------------------------------------
# Debian
# ------------------------------------------------------------

debian_installed() {
    if proot-distro list 2>/dev/null | grep -Eiq '(^|[^a-z])debian([^a-z]|$).*(installed|\*)'; then
        return 0
    fi
    [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ] && return 0
    return 1
}

echo
echo "[4/11] Checking Debian..."

if debian_installed; then
    echo "Debian already installed."
else
    echo "Installing Debian..."
    if ! retry proot-distro install debian >> "$LOGFILE" 2>&1; then
        die "Debian install failed after retries. This is often a proot/kernel"$'\n'"       compatibility issue (see warning above) or insufficient storage."$'\n'"       Log: $LOGFILE"
    fi
fi

# ------------------------------------------------------------
# Debian SpotDL setup
# ------------------------------------------------------------

echo
echo "[5/11] Installing SpotDL inside Debian..."

cat > "$PREFIX/.spotdl_debian_setup.sh" <<'DEBIAN_SETUP'
#!/bin/bash
set -uo pipefail

echo "================================================"
echo "             Debian SpotDL Setup"
echo "                @Sgkmods13"
echo "================================================"
echo

export DEBIAN_FRONTEND=noninteractive

retry() {
    local tries=3 n=1 delay=3
    until "$@"; do
        if [ "$n" -ge "$tries" ]; then return 1; fi
        echo "  (attempt $n failed, retrying in ${delay}s...)"
        sleep "$delay"
        n=$((n + 1))
    done
}

retry apt update || { echo "ERROR: apt update failed repeatedly."; exit 1; }
retry apt upgrade -y || echo "WARNING: apt upgrade had issues, continuing."

retry apt install -y python3 python3-pip python3-venv ffmpeg curl ca-certificates \
    || { echo "ERROR: apt install of core packages failed."; exit 1; }

if [ ! -d "$HOME/spotdl-env" ]; then
    python3 -m venv "$HOME/spotdl-env" || { echo "ERROR: failed to create venv."; exit 1; }
fi

# shellcheck disable=SC1091
source "$HOME/spotdl-env/bin/activate"

python -m pip install --upgrade pip
retry python -m pip install --upgrade spotdl \
    || { echo "ERROR: pip install of spotdl failed after retries."; exit 1; }

echo
echo "Checking SpotDL..."
spotdl --version || { echo "ERROR: spotdl did not report a version."; exit 1; }

echo
echo "================================================"
echo "        SpotDL installation complete"
echo "                @Sgkmods13"
echo "================================================"
DEBIAN_SETUP

chmod +x "$PREFIX/.spotdl_debian_setup.sh"

if ! proot-distro login debian -- bash -c "
        cp '$PREFIX/.spotdl_debian_setup.sh' /root/setup-spotdl.sh
        chmod +x /root/setup-spotdl.sh
        /root/setup-spotdl.sh
        rc=\$?
        rm -f /root/setup-spotdl.sh
        exit \$rc
    " >> "$LOGFILE" 2>&1
then
    rm -f "$PREFIX/.spotdl_debian_setup.sh"
    die "SpotDL setup inside Debian failed. Check: $LOGFILE"$'\n'"       Common causes: no network inside proot, or apt mirror down."
fi

rm -f "$PREFIX/.spotdl_debian_setup.sh"

# ------------------------------------------------------------
# Create Termux command
# ------------------------------------------------------------

echo
echo "[6/11] Creating spotdl-debian command..."

cat > "$PREFIX/bin/spotdl-debian" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash

echo "================================================"
echo "             SpotDL - @Sgkmods13"
echo "================================================"
echo

proot-distro login debian -- \
bash -lc '
if [ ! -f "$HOME/spotdl-env/bin/activate" ]; then
    echo "ERROR: SpotDL environment not found."
    exit 1
fi

source "$HOME/spotdl-env/bin/activate"

if [ "$#" -eq 0 ]; then
    spotdl --help
else
    spotdl "$@"
fi
' -- "$@"
LAUNCHER

chmod +x "$PREFIX/bin/spotdl-debian"

# ------------------------------------------------------------
# Diagnostics command — run this on any device that fails, and
# paste its output when reporting an issue.
# ------------------------------------------------------------

echo
echo "[7/11] Creating spotdl-doctor diagnostics command..."

cat > "$PREFIX/bin/spotdl-doctor" <<'DOCTOR'
#!/data/data/com.termux/files/usr/bin/bash

echo "================================================"
echo "          SpotDL Doctor - @Sgkmods13"
echo "================================================"
echo

echo "-- Environment --"
echo "TERMUX_VERSION : ${TERMUX_VERSION:-unknown}"
echo "PREFIX         : $PREFIX"
echo "Architecture   : $(uname -m)"
echo "Kernel         : $(uname -r 2>/dev/null || echo unknown)"
echo "Android SDK    : $(getprop ro.build.version.sdk 2>/dev/null || echo unknown)"
echo "Android ver.   : $(getprop ro.build.version.release 2>/dev/null || echo unknown)"
echo "Device model   : $(getprop ro.product.model 2>/dev/null || echo unknown)"
echo

echo "-- Storage --"
if [ -d "$HOME/storage/shared" ]; then
    echo "storage/shared : present"
    if ( : > "$HOME/storage/shared/.doctor_test" ) 2>/dev/null; then
        echo "writable       : yes"
        rm -f "$HOME/storage/shared/.doctor_test"
    else
        echo "writable       : NO (check Android app storage permission)"
    fi
else
    echo "storage/shared : MISSING (run termux-setup-storage)"
fi
df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {printf "free space     : %.1f GB\n", $4/1024/1024}'
echo

echo "-- proot-distro / Debian --"
if command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro   : installed"
else
    echo "proot-distro   : NOT installed"
fi
if command -v proot >/dev/null 2>&1; then
    if proot --help >/dev/null 2>&1; then
        echo "proot capable  : yes"
    else
        echo "proot capable  : NO (likely kernel/seccomp restriction on this device)"
    fi
fi
if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
    echo "Debian rootfs  : present"
else
    echo "Debian rootfs  : NOT installed"
fi
echo

echo "-- SpotDL --"
if proot-distro login debian -- bash -lc 'test -f "$HOME/spotdl-env/bin/activate"' 2>/dev/null; then
    echo "spotdl venv    : present"
    proot-distro login debian -- bash -lc 'source "$HOME/spotdl-env/bin/activate" && spotdl --version' 2>/dev/null
else
    echo "spotdl venv    : NOT found"
fi
echo

echo "================================================"
echo "Paste the output above when reporting an issue."
echo "================================================"
DOCTOR

chmod +x "$PREFIX/bin/spotdl-doctor"

# ------------------------------------------------------------
# Create Widget directories
# ------------------------------------------------------------

echo
echo "[8/11] Creating Termux:Widget directories..."

mkdir -p "$HOME/.shortcuts"
mkdir -p "$HOME/.shortcuts/tasks"

# ------------------------------------------------------------
# Create complete Widget
# ------------------------------------------------------------

echo
echo "[9/11] Creating SpotDL Widget..."

cat > "$HOME/.shortcuts/SpotDL" <<'WIDGET'
#!/data/data/com.termux/files/usr/bin/bash

CREDIT="@Sgkmods13"

clear

echo "================================================"
echo "                SPOTDL DOWNLOADER"
echo "                Credit: $CREDIT"
echo "================================================"
echo

if [ ! -d "$HOME/storage/shared" ]; then
    echo "Requesting storage permission..."
    termux-setup-storage || true
    sleep 3
fi

if [ ! -d "$HOME/storage/shared" ] || ! ( : > "$HOME/storage/shared/.wtest" ) 2>/dev/null; then
    echo
    echo "Storage permission is required and must be writable."
    echo "Run 'spotdl-doctor' in Termux for details, or grant"
    echo "storage access in Android Settings > Apps > Termux."
    echo
    read -p "Press Enter to close..."
    exit 1
fi
rm -f "$HOME/storage/shared/.wtest" 2>/dev/null

DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
if [ ! -d "$DEBIAN_ROOTFS" ] && ! proot-distro list 2>/dev/null | grep -Eiq '(^|[^a-z])debian([^a-z]|$).*(installed|\*)'; then
    echo "Debian is not installed."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

if ! proot-distro login debian -- \
    bash -lc 'test -f "$HOME/spotdl-env/bin/activate"'
then
    echo "SpotDL environment not found."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

while true
do
    clear
    echo "================================================"
    echo "          SPOTDL - DOWNLOAD LOCATION"
    echo "                 $CREDIT"
    echo "================================================"
    echo
    echo "1) Download/Spotube"
    echo "2) Music"
    echo "3) Download"
    echo "4) DCIM"
    echo "5) Custom folder"
    echo "6) Enter full Android path"
    echo "7) Exit"
    echo
    read -p "Select [1-7]: " CHOICE
    case "$CHOICE" in
        1) OUT="$HOME/storage/shared/Download/Spotube"; break ;;
        2) OUT="$HOME/storage/shared/Music"; break ;;
        3) OUT="$HOME/storage/shared/Download"; break ;;
        4) OUT="$HOME/storage/shared/DCIM"; break ;;
        5)
            echo
            echo "Example:"
            echo "$HOME/storage/shared/MyMusic"
            echo
            read -p "Folder path: " OUT
            [ -z "$OUT" ] && { echo "Invalid folder."; sleep 2; } || break
            ;;
        6)
            echo
            echo "Example:"
            echo "/storage/emulated/0/Music/SpotDL"
            echo
            read -p "Android path: " OUT
            [ -z "$OUT" ] && { echo "Invalid path."; sleep 2; } || break
            ;;
        7) exit 0 ;;
        *) echo "Invalid choice."; sleep 2 ;;
    esac
done

mkdir -p "$OUT"
if [ ! -d "$OUT" ]; then
    echo
    echo "Unable to create:"
    echo "$OUT"
    read -p "Press Enter to close..."
    exit 1
fi

clear
echo "================================================"
echo "                SPOTDL DOWNLOADER"
echo "                Credit: $CREDIT"
echo "================================================"
echo
echo "Save location:"
echo "$OUT"
echo
read -p "Enter Spotify URL: " URL

if [ -z "$URL" ]; then
    echo
    echo "No URL entered."
    read -p "Press Enter to close..."
    exit 1
fi

echo
echo "Starting SpotDL..."
echo

proot-distro login debian -- \
bash -lc '
source "$HOME/spotdl-env/bin/activate"
spotdl \
    --output "'"$OUT"'/{artist} - {title}.{output-ext}" \
    --format m4a \
    "'"$URL"'"
'
STATUS=$?

echo
echo "================================================"
if [ "$STATUS" -eq 0 ]; then
    echo "                 DOWNLOAD DONE"
else
    echo "            DOWNLOAD FINISHED WITH ERRORS"
    echo "        Run 'spotdl-doctor' in Termux to check setup"
fi
echo "================================================"
echo
echo "Location:"
echo "$OUT"
echo
echo "Credit: $CREDIT"
echo
read -p "Press Enter to close..."
WIDGET

chmod 700 "$HOME/.shortcuts/SpotDL"

# ------------------------------------------------------------
# Permissions/settings helper
# ------------------------------------------------------------

echo
echo "[10/11] Creating permission helper..."

cat > "$PREFIX/bin/spotdl-permissions" <<'PERMISSIONS'
#!/data/data/com.termux/files/usr/bin/bash

echo "=========================================="
echo "       SpotDL Android Permissions"
echo "              @Sgkmods13"
echo "=========================================="
echo
echo "1) Termux overlay"
echo "2) Termux:Widget overlay"
echo "3) Termux unknown-app sources"
echo "4) Termux:Widget unknown-app sources"
echo "5) Storage permission"
echo "6) Exit"
echo

read -p "Select: " P

case "$P" in
    1) am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION -d package:com.termux ;;
    2) am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION -d package:com.termux.widget ;;
    3) am start -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d package:com.termux ;;
    4) am start -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d package:com.termux.widget ;;
    5) termux-setup-storage ;;
    6) exit 0 ;;
esac
PERMISSIONS

chmod +x "$PREFIX/bin/spotdl-permissions"

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

echo
echo "[11/11] Finalizing..."

echo
echo "================================================"
echo "                    SUCCESS"
echo "================================================"
echo
echo "                 Credit: @Sgkmods13"
echo
echo "SpotDL installed successfully."
echo
echo "Termux commands:"
echo "  spotdl-debian    - run spotdl directly"
echo "  spotdl-doctor    - diagnose problems on this device"
echo
echo "Widget:"
echo "  SpotDL"
echo
echo "If something doesn't work on this device, run:"
echo "  spotdl-doctor"
echo "and use its output to see what's actually failing."
echo
echo "================================================"
echo "       IMPORTANT: Termux:Widget APK"
echo "       must be installed separately."
echo "================================================"
echo
echo "If Widget is installed, add it to your"
echo "Android home screen and refresh it."
echo
echo "                 @Sgkmods13"
echo "================================================"
