#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "======================================"
echo "       My Py Lib - Termux Installer"
echo "======================================"

# Check Termux
if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
    echo "ERROR: This installer must be run inside Termux."
    exit 1
fi

echo
echo "[1/5] Updating Termux..."
pkg update -y

echo
echo "[2/5] Installing required packages..."
pkg install -y python ffmpeg git curl wget

echo
echo "[3/5] Installing SpotDL..."
python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

if ! command -v spotdl >/dev/null 2>&1; then
    echo "ERROR: SpotDL installation failed."
    exit 1
fi

echo
echo "[4/5] Optional Deno installation"
echo
echo "Deno is optional."
printf "Do you want to install Deno? [Y/n]: "
read -r DENO_CHOICE

if [[ "$DENO_CHOICE" =~ ^[Yy]$ || -z "$DENO_CHOICE" ]]; then

    if command -v deno >/dev/null 2>&1; then
        echo "Deno is already installed."

    elif apt-cache show deno >/dev/null 2>&1; then
        echo "Installing Deno from Termux..."
        pkg install -y deno

    else
        echo "Deno is not available in this Termux repository."
        echo "Skipping Deno."
    fi

else
    echo "Deno installation skipped."
fi

echo
echo "[5/5] Checking installation..."
echo

echo "Python:"
python --version

echo
echo "SpotDL:"
spotdl --version

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
echo "  spotdl --help"
echo
