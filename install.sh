#!/data/data/com.termux/files/usr/bin/bash

set -e

# ==========================================
# My Py Lib - Termux Installer
# SpotDL + Deno + FFmpeg + Python
# ==========================================

PROJECT_NAME="My Py Lib"

echo
echo "=========================================="
echo "       $PROJECT_NAME Installer"
echo "=========================================="
echo

# ---------- Basic checks ----------

if [ -z "$PREFIX" ]; then
    echo "ERROR: This installer is designed for Termux."
    exit 1
fi

ARCH="$(uname -m)"
echo "[INFO] Device architecture: $ARCH"

# ---------- Update Termux ----------

echo
echo "[1/7] Updating Termux..."
pkg update -y

# ---------- Required packages ----------

echo
echo "[2/7] Installing required packages..."

pkg install -y \
    python \
    ffmpeg \
    git \
    curl \
    wget \
    unzip

# ---------- Python ----------

echo
echo "[3/7] Checking Python..."

if ! command -v python >/dev/null 2>&1; then
    echo "ERROR: Python installation failed."
    exit 1
fi

python --version

# ---------- SpotDL ----------

echo
echo "[4/7] Installing SpotDL..."

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

if ! command -v spotdl >/dev/null 2>&1; then
    echo "ERROR: SpotDL installation failed."
    exit 1
fi

echo "SpotDL: $(spotdl --version 2>&1 | head -n 1)"

# ---------- Deno ----------

echo
echo "[5/7] Installing Deno..."

if command -v deno >/dev/null 2>&1; then

    echo "Deno is already installed."
    deno --version | head -n 1

else

    # Try Termux package first
    if pkg search deno 2>/dev/null | grep -qE '^deno[[:space:]]'; then

        echo "Installing Deno from Termux repository..."
        pkg install -y deno

    else

        echo "Deno package is not available in the current Termux repository."
        echo "Installing Deno using the official installer..."

        curl -fsSL https://deno.land/install.sh | sh

        export DENO_INSTALL="$HOME/.deno"
        export PATH="$DENO_INSTALL/bin:$PATH"

    fi

fi

# Check Deno

if ! command -v deno >/dev/null 2>&1; then

    if [ -x "$HOME/.deno/bin/deno" ]; then
        export PATH="$HOME/.deno/bin:$PATH"
    fi

fi

if ! command -v deno >/dev/null 2>&1; then
    echo
    echo "ERROR: Deno installation failed."
    echo
    echo "Try:"
    echo "  pkg search deno"
    exit 1
fi

echo "Deno:"
deno --version | head -n 1

# ---------- FFmpeg ----------

echo
echo "[6/7] Checking FFmpeg..."

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ERROR: FFmpeg installation failed."
    exit 1
fi

echo "FFmpeg:"
ffmpeg -version | head -n 1

# ---------- Final verification ----------

echo
echo "[7/7] Final verification..."
echo

printf "Python : "
python --version 2>&1

printf "SpotDL : "
spotdl --version 2>&1 | head -n 1

printf "Deno   : "
deno --version 2>&1 | head -n 1

printf "FFmpeg : "
ffmpeg -version 2>&1 | head -n 1

printf "Git    : "
git --version

echo
echo "=========================================="
echo "       Installation successful!"
echo "=========================================="
echo
echo "You can now run:"
echo
echo "  spotdl --help"
echo
echo "Deno:"
echo "  deno --version"
echo
echo "FFmpeg:"
echo "  ffmpeg -version"
echo
echo "=========================================="
