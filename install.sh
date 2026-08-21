#!/data/data/com.termux/files/usr/bin/bash

set -e

CREDIT="@Sgkmods13"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

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

banner

# ------------------------------------------------------------
# Check Termux (real detection, not just a PREFIX default check)
# ------------------------------------------------------------
# The old check `[ -z "$PREFIX" ]` could never fail, because PREFIX is
# given a default value on the line above it. We need to test for
# something that is only true when actually running inside Termux.

is_termux() {
    # 1) Termux sets this env var itself
    [ -n "$TERMUX_VERSION" ] && return 0

    # 2) The Termux prefix path is distinctive
    case "$PREFIX" in
        */com.termux/*) : ;;
        *) return 1 ;;
    esac

    # 3) A Termux-only binary should be on PATH
    command -v termux-info >/dev/null 2>&1 || command -v termux-setup-storage >/dev/null 2>&1 || return 1

    return 0
}

if ! is_termux; then
    echo "ERROR: This installer must be run inside Termux on Android."
    echo "       (Termux environment / com.termux prefix not detected.)"
    exit 1
fi

# Also bail early with a clear message if this Android device's arch
# isn't one proot-distro/Debian actually supports.
case "$(uname -m)" in
    aarch64|arm64|armv7l|armv8l|x86_64|i686) ;;
    *)
        echo "ERROR: Unsupported device architecture: $(uname -m)"
        exit 1
        ;;
esac

# ------------------------------------------------------------
# Install required Termux packages
# ------------------------------------------------------------

echo "[1/10] Updating Termux..."
pkg update -y

echo
echo "[2/10] Installing required Termux packages..."

pkg install -y \
    proot-distro \
    coreutils \
    grep \
    sed \
    curl

if ! command -v proot-distro >/dev/null 2>&1; then
    echo "ERROR: proot-distro failed to install. Aborting."
    exit 1
fi

# ------------------------------------------------------------
# Storage permission
# ------------------------------------------------------------

echo
echo "[3/10] Requesting Termux storage permission..."

if [ ! -d "$HOME/storage/shared" ]; then
    termux-setup-storage || true
    sleep 3
fi

# ------------------------------------------------------------
# Debian
# ------------------------------------------------------------
# proot-distro's `list` output format has changed across versions
# (spacing, "installed" wording, added color codes, etc.), so grepping
# its text is unreliable. Checking the actual installed-rootfs
# directory is a stable signal that works regardless of CLI output
# formatting.

debian_installed() {
    # Preferred: ask proot-distro itself, ignoring formatting differences
    if proot-distro list 2>/dev/null | grep -Eiq '(^|[^a-z])debian([^a-z]|$).*(installed|\*)'; then
        return 0
    fi
    # Fallback: check on-disk rootfs directly
    [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ] && return 0
    return 1
}

echo
echo "[4/10] Checking Debian..."

if debian_installed; then
    echo "Debian already installed."
else
    echo "Installing Debian..."
    proot-distro install debian
fi

# ------------------------------------------------------------
# Debian SpotDL setup
# ------------------------------------------------------------

echo
echo "[5/10] Installing SpotDL inside Debian..."

cat > "$PREFIX/.spotdl_debian_setup.sh" <<'DEBIAN_SETUP'
#!/bin/bash

set -e

echo "================================================"
echo "             Debian SpotDL Setup"
echo "                @Sgkmods13"
echo "================================================"
echo

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y

apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    curl \
    ca-certificates

if [ ! -d "$HOME/spotdl-env" ]; then
    python3 -m venv "$HOME/spotdl-env"
fi

source "$HOME/spotdl-env/bin/activate"

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

echo
echo "Checking SpotDL..."
spotdl --version

echo
echo "================================================"
echo "        SpotDL installation complete"
echo "                @Sgkmods13"
echo "================================================"
DEBIAN_SETUP

chmod +x "$PREFIX/.spotdl_debian_setup.sh"

proot-distro login debian -- \
    bash -c "
        cp '$PREFIX/.spotdl_debian_setup.sh' /root/setup-spotdl.sh
        chmod +x /root/setup-spotdl.sh
        /root/setup-spotdl.sh
        rm -f /root/setup-spotdl.sh
    "

rm -f "$PREFIX/.spotdl_debian_setup.sh"

# ------------------------------------------------------------
# Create Termux command
# ------------------------------------------------------------

echo
echo "[6/10] Creating spotdl-debian command..."

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
# Create Widget directories
# ------------------------------------------------------------

echo
echo "[7/10] Creating Termux:Widget directories..."

mkdir -p "$HOME/.shortcuts"
mkdir -p "$HOME/.shortcuts/tasks"

# ------------------------------------------------------------
# Create complete Widget
# ------------------------------------------------------------

echo
echo "[8/10] Creating SpotDL Widget..."

cat > "$HOME/.shortcuts/SpotDL" <<'WIDGET'
#!/data/data/com.termux/files/usr/bin/bash

CREDIT="@Sgkmods13"

# ============================================================
#                    SPOTDL WIDGET
#                    @Sgkmods13
# ============================================================

clear

echo "================================================"
echo "                SPOTDL DOWNLOADER"
echo "                Credit: $CREDIT"
echo "================================================"
echo

# ------------------------------------------------------------
# Storage
# ------------------------------------------------------------

if [ ! -d "$HOME/storage/shared" ]; then
    echo "Requesting storage permission..."
    termux-setup-storage || true
    sleep 3
fi

if [ ! -d "$HOME/storage/shared" ]; then
    echo
    echo "Storage permission is required."
    echo "Please allow Termux storage access."
    echo
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Debian check (rootfs-directory check, not fragile text grep)
# ------------------------------------------------------------

DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

if [ ! -d "$DEBIAN_ROOTFS" ] && ! proot-distro list 2>/dev/null | grep -Eiq '(^|[^a-z])debian([^a-z]|$).*(installed|\*)'; then
    echo "Debian is not installed."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# SpotDL check
# ------------------------------------------------------------

if ! proot-distro login debian -- \
    bash -lc 'test -f "$HOME/spotdl-env/bin/activate"'
then
    echo "SpotDL environment not found."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Select storage
# ------------------------------------------------------------

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

        1)
            OUT="$HOME/storage/shared/Download/Spotube"
            break
            ;;

        2)
            OUT="$HOME/storage/shared/Music"
            break
            ;;

        3)
            OUT="$HOME/storage/shared/Download"
            break
            ;;

        4)
            OUT="$HOME/storage/shared/DCIM"
            break
            ;;

        5)
            echo
            echo "Example:"
            echo "$HOME/storage/shared/MyMusic"
            echo
            read -p "Folder path: " OUT

            if [ -z "$OUT" ]; then
                echo "Invalid folder."
                sleep 2
            else
                break
            fi
            ;;

        6)
            echo
            echo "Example:"
            echo "/storage/emulated/0/Music/SpotDL"
            echo
            read -p "Android path: " OUT

            if [ -z "$OUT" ]; then
                echo "Invalid path."
                sleep 2
            else
                break
            fi
            ;;

        7)
            exit 0
            ;;

        *)
            echo "Invalid choice."
            sleep 2
            ;;
    esac
done

# ------------------------------------------------------------
# Create folder
# ------------------------------------------------------------

mkdir -p "$OUT"

if [ ! -d "$OUT" ]; then
    echo
    echo "Unable to create:"
    echo "$OUT"
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Spotify URL
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Download M4A
# ------------------------------------------------------------

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

echo
echo "================================================"
echo "                 DOWNLOAD DONE"
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
echo "[9/10] Creating permission helper..."

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
    1)
        am start \
        -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
        -d package:com.termux
        ;;
    2)
        am start \
        -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
        -d package:com.termux.widget
        ;;
    3)
        am start \
        -a android.settings.MANAGE_UNKNOWN_APP_SOURCES \
        -d package:com.termux
        ;;
    4)
        am start \
        -a android.settings.MANAGE_UNKNOWN_APP_SOURCES \
        -d package:com.termux.widget
        ;;
    5)
        termux-setup-storage
        ;;
    6)
        exit 0
        ;;
esac
PERMISSIONS

chmod +x "$PREFIX/bin/spotdl-permissions"

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

echo
echo "[10/10] Finalizing..."

echo
echo "================================================"
echo "                    SUCCESS"
echo "================================================"
echo
echo "                 Credit: @Sgkmods13"
echo
echo "SpotDL installed successfully."
echo
echo "Termux command:"
echo "  spotdl-debian"
echo
echo "Widget:"
echo "  SpotDL"
echo
echo "The Widget supports:"
echo "  - M4A output"
echo "  - Custom download location"
echo "  - Storage permission"
echo "  - Debian + SpotDL automatically"
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
    ca-certificates

if [ ! -d "$HOME/spotdl-env" ]; then
    python3 -m venv "$HOME/spotdl-env"
fi

source "$HOME/spotdl-env/bin/activate"

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

echo
echo "Checking SpotDL..."
spotdl --version

echo
echo "================================================"
echo "        SpotDL installation complete"
echo "                @Sgkmods13"
echo "================================================"
DEBIAN_SETUP

chmod +x "$PREFIX/.spotdl_debian_setup.sh"

proot-distro login debian -- \
    bash -c "
        cp '$PREFIX/.spotdl_debian_setup.sh' /root/setup-spotdl.sh
        chmod +x /root/setup-spotdl.sh
        /root/setup-spotdl.sh
        rm -f /root/setup-spotdl.sh
    "

rm -f "$PREFIX/.spotdl_debian_setup.sh"

# ------------------------------------------------------------
# Create Termux command
# ------------------------------------------------------------

echo
echo "[6/10] Creating spotdl-debian command..."

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
# Create Widget directories
# ------------------------------------------------------------

echo
echo "[7/10] Creating Termux:Widget directories..."

mkdir -p "$HOME/.shortcuts"
mkdir -p "$HOME/.shortcuts/tasks"

# ------------------------------------------------------------
# Create complete Widget
# ------------------------------------------------------------

echo
echo "[8/10] Creating SpotDL Widget..."

cat > "$HOME/.shortcuts/SpotDL" <<'WIDGET'
#!/data/data/com.termux/files/usr/bin/bash

CREDIT="@Sgkmods13"

# ============================================================
#                    SPOTDL WIDGET
#                    @Sgkmods13
# ============================================================

clear

echo "================================================"
echo "                SPOTDL DOWNLOADER"
echo "                Credit: $CREDIT"
echo "================================================"
echo

# ------------------------------------------------------------
# Storage
# ------------------------------------------------------------

if [ ! -d "$HOME/storage/shared" ]; then
    echo "Requesting storage permission..."
    termux-setup-storage || true
    sleep 3
fi

if [ ! -d "$HOME/storage/shared" ]; then
    echo
    echo "Storage permission is required."
    echo "Please allow Termux storage access."
    echo
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Debian check
# ------------------------------------------------------------

if ! proot-distro list 2>/dev/null | grep -qi "debian.*installed"; then
    echo "Debian is not installed."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# SpotDL check
# ------------------------------------------------------------

if ! proot-distro login debian -- \
    bash -lc 'test -f "$HOME/spotdl-env/bin/activate"'
then
    echo "SpotDL environment not found."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Select storage
# ------------------------------------------------------------

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

        1)
            OUT="$HOME/storage/shared/Download/Spotube"
            break
            ;;

        2)
            OUT="$HOME/storage/shared/Music"
            break
            ;;

        3)
            OUT="$HOME/storage/shared/Download"
            break
            ;;

        4)
            OUT="$HOME/storage/shared/DCIM"
            break
            ;;

        5)
            echo
            echo "Example:"
            echo "$HOME/storage/shared/MyMusic"
            echo
            read -p "Folder path: " OUT

            if [ -z "$OUT" ]; then
                echo "Invalid folder."
                sleep 2
            else
                break
            fi
            ;;

        6)
            echo
            echo "Example:"
            echo "/storage/emulated/0/Music/SpotDL"
            echo
            read -p "Android path: " OUT

            if [ -z "$OUT" ]; then
                echo "Invalid path."
                sleep 2
            else
                break
            fi
            ;;

        7)
            exit 0
            ;;

        *)
            echo "Invalid choice."
            sleep 2
            ;;
    esac
done

# ------------------------------------------------------------
# Create folder
# ------------------------------------------------------------

mkdir -p "$OUT"

if [ ! -d "$OUT" ]; then
    echo
    echo "Unable to create:"
    echo "$OUT"
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Spotify URL
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Download M4A
# ------------------------------------------------------------

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

echo
echo "================================================"
echo "                 DOWNLOAD DONE"
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
echo "[9/10] Creating permission helper..."

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
    1)
        am start \
        -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
        -d package:com.termux
        ;;
    2)
        am start \
        -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
        -d package:com.termux.widget
        ;;
    3)
        am start \
        -a android.settings.MANAGE_UNKNOWN_APP_SOURCES \
        -d package:com.termux
        ;;
    4)
        am start \
        -a android.settings.MANAGE_UNKNOWN_APP_SOURCES \
        -d package:com.termux.widget
        ;;
    5)
        termux-setup-storage
        ;;
    6)
        exit 0
        ;;
esac
PERMISSIONS

chmod +x "$PREFIX/bin/spotdl-permissions"

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

echo
echo "[10/10] Finalizing..."

echo
echo "================================================"
echo "                    SUCCESS"
echo "================================================"
echo
echo "                 Credit: @Sgkmods13"
echo
echo "SpotDL installed successfully."
echo
echo "Termux command:"
echo "  spotdl-debian"
echo
echo "Widget:"
echo "  SpotDL"
echo
echo "The Widget supports:"
echo "  - M4A output"
echo "  - Custom download location"
echo "  - Storage permission"
echo "  - Debian + SpotDL automatically"
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
echo "================================================"#!/data/data/com.termux/files/usr/bin/bash

set -e

CREDIT="@Sgkmods13"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

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

banner

# ------------------------------------------------------------
# Check Termux
# ------------------------------------------------------------

if [ -z "$PREFIX" ]; then
    echo "ERROR: Run this installer inside Termux."
    exit 1
fi

# ------------------------------------------------------------
# Install required Termux packages
# ------------------------------------------------------------

echo "[1/10] Updating Termux..."
pkg update -y

echo
echo "[2/10] Installing required Termux packages..."

pkg install -y \
    proot-distro \
    coreutils \
    grep \
    sed \
    curl

# ------------------------------------------------------------
# Storage permission
# ------------------------------------------------------------

echo
echo "[3/10] Requesting Termux storage permission..."

if [ ! -d "$HOME/storage/shared" ]; then
    termux-setup-storage || true
    sleep 3
fi

# ------------------------------------------------------------
# Debian
# ------------------------------------------------------------

echo
echo "[4/10] Checking Debian..."

if proot-distro list 2>/dev/null | grep -qi "debian.*installed"; then
    echo "Debian already installed."
else
    echo "Installing Debian..."
    proot-distro install debian
fi

# ------------------------------------------------------------
# Debian SpotDL setup
# ------------------------------------------------------------

echo
echo "[5/10] Installing SpotDL inside Debian..."

cat > "$PREFIX/.spotdl_debian_setup.sh" <<'DEBIAN_SETUP'
#!/bin/bash

set -e

echo "================================================"
echo "             Debian SpotDL Setup"
echo "                @Sgkmods13"
echo "================================================"
echo

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y

apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    curl \
    ca-certificates

if [ ! -d "$HOME/spotdl-env" ]; then
    python3 -m venv "$HOME/spotdl-env"
fi

source "$HOME/spotdl-env/bin/activate"

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

echo
echo "Checking SpotDL..."
spotdl --version

echo
echo "================================================"
echo "        SpotDL installation complete"
echo "                @Sgkmods13"
echo "================================================"
DEBIAN_SETUP

chmod +x "$PREFIX/.spotdl_debian_setup.sh"

proot-distro login debian -- \
    bash -c "
        cp '$PREFIX/.spotdl_debian_setup.sh' /root/setup-spotdl.sh
        chmod +x /root/setup-spotdl.sh
        /root/setup-spotdl.sh
        rm -f /root/setup-spotdl.sh
    "

rm -f "$PREFIX/.spotdl_debian_setup.sh"

# ------------------------------------------------------------
# Create Termux command
# ------------------------------------------------------------

echo
echo "[6/10] Creating spotdl-debian command..."

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
# Create Widget directories
# ------------------------------------------------------------

echo
echo "[7/10] Creating Termux:Widget directories..."

mkdir -p "$HOME/.shortcuts"
mkdir -p "$HOME/.shortcuts/tasks"

# ------------------------------------------------------------
# Create complete Widget
# ------------------------------------------------------------

echo
echo "[8/10] Creating SpotDL Widget..."

cat > "$HOME/.shortcuts/SpotDL" <<'WIDGET'
#!/data/data/com.termux/files/usr/bin/bash

CREDIT="@Sgkmods13"

# ============================================================
#                    SPOTDL WIDGET
#                    @Sgkmods13
# ============================================================

clear

echo "================================================"
echo "                SPOTDL DOWNLOADER"
echo "                Credit: $CREDIT"
echo "================================================"
echo

# ------------------------------------------------------------
# Storage
# ------------------------------------------------------------

if [ ! -d "$HOME/storage/shared" ]; then
    echo "Requesting storage permission..."
    termux-setup-storage || true
    sleep 3
fi

if [ ! -d "$HOME/storage/shared" ]; then
    echo
    echo "Storage permission is required."
    echo "Please allow Termux storage access."
    echo
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Debian check
# ------------------------------------------------------------

if ! proot-distro list 2>/dev/null | grep -qi "debian.*installed"; then
    echo "Debian is not installed."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# SpotDL check
# ------------------------------------------------------------

if ! proot-distro login debian -- \
    bash -lc 'test -f "$HOME/spotdl-env/bin/activate"'
then
    echo "SpotDL environment not found."
    echo "Please run the main installer again."
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Select storage
# ------------------------------------------------------------

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

        1)
            OUT="$HOME/storage/shared/Download/Spotube"
            break
            ;;

        2)
            OUT="$HOME/storage/shared/Music"
            break
            ;;

        3)
            OUT="$HOME/storage/shared/Download"
            break
            ;;

        4)
            OUT="$HOME/storage/shared/DCIM"
            break
            ;;

        5)
            echo
            echo "Example:"
            echo "$HOME/storage/shared/MyMusic"
            echo
            read -p "Folder path: " OUT

            if [ -z "$OUT" ]; then
                echo "Invalid folder."
                sleep 2
            else
                break
            fi
            ;;

        6)
            echo
            echo "Example:"
            echo "/storage/emulated/0/Music/SpotDL"
            echo
            read -p "Android path: " OUT

            if [ -z "$OUT" ]; then
                echo "Invalid path."
                sleep 2
            else
                break
            fi
            ;;

        7)
            exit 0
            ;;

        *)
            echo "Invalid choice."
            sleep 2
            ;;
    esac
done

# ------------------------------------------------------------
# Create folder
# ------------------------------------------------------------

mkdir -p "$OUT"

if [ ! -d "$OUT" ]; then
    echo
    echo "Unable to create:"
    echo "$OUT"
    read -p "Press Enter to close..."
    exit 1
fi

# ------------------------------------------------------------
# Spotify URL
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Download M4A
# ------------------------------------------------------------

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

echo
echo "================================================"
echo "                 DOWNLOAD DONE"
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
echo "[9/10] Creating permission helper..."

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
    1)
        am start \
        -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
        -d package:com.termux
        ;;
    2)
        am start \
        -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
        -d package:com.termux.widget
        ;;
    3)
        am start \
        -a android.settings.MANAGE_UNKNOWN_APP_SOURCES \
        -d package:com.termux
        ;;
    4)
        am start \
        -a android.settings.MANAGE_UNKNOWN_APP_SOURCES \
        -d package:com.termux.widget
        ;;
    5)
        termux-setup-storage
        ;;
    6)
        exit 0
        ;;
esac
PERMISSIONS

chmod +x "$PREFIX/bin/spotdl-permissions"

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

echo
echo "[10/10] Finalizing..."

echo
echo "================================================"
echo "                    SUCCESS"
echo "================================================"
echo
echo "                 Credit: @Sgkmods13"
echo
echo "SpotDL installed successfully."
echo
echo "Termux command:"
echo "  spotdl-debian"
echo
echo "Widget:"
echo "  SpotDL"
echo
echo "The Widget supports:"
echo "  - M4A output"
echo "  - Custom download location"
echo "  - Storage permission"
echo "  - Debian + SpotDL automatically"
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
echo "================================================"echo
echo "[5/8] Creating SpotDL launcher..."

cat > "$PREFIX/bin/spotdl-debian" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

proot-distro login debian -- bash -c '
if [ ! -f "$HOME/spotdl-env/bin/activate" ]; then
    echo "SpotDL environment not found."
    echo "Run the installer again."
    exit 1
fi

source "$HOME/spotdl-env/bin/activate"
spotdl "$@"
' -- "$@"
EOF

chmod +x "$PREFIX/bin/spotdl-debian"

# ------------------------------------------
# 7. Clean temporary file
# ------------------------------------------

rm -f "$PREFIX/tmp_my_py_lib_debian.sh"

echo
echo "[6/8] Installation finished."

# ------------------------------------------
# 8. Final instructions
# ------------------------------------------

echo
echo "=========================================="
echo "              SUCCESS!"
echo "=========================================="
echo
echo "SpotDL is installed inside Debian."
echo
echo "To enter Debian:"
echo
echo "  proot-distro login debian"
echo
echo "Then:"
echo
echo "  source ~/spotdl-env/bin/activate"
echo "  spotdl --version"
echo
echo "Or from normal Termux:"
echo
echo "  spotdl-debian --version"
echo
echo "=========================================="
