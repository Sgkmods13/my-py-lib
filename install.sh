#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "=========================================="
echo "       My Py Lib - Termux Installer"
echo "=========================================="

echo "[1/6] Updating Termux packages..."
pkg update -y
pkg upgrade -y

echo "[2/6] Installing required packages..."
pkg install -y python ffmpeg git

echo "[3/6] Installing Deno..."

if command -v deno >/dev/null 2>&1; then
    echo "Deno is already installed."
else
    if pkg search deno 2>/dev/null | grep -q "^deno"; then
        pkg install -y deno
    else
        echo "ERROR: Deno package is not available."
        echo "Update your Termux installation and try again."
        exit 1
    fi
fi

echo "[4/6] Installing SpotDL..."

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

echo "[5/6] Installing My Py Lib..."

mkdir -p "$HOME/bin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cp "$SCRIPT_DIR/bin/my-py-lib" "$HOME/bin/my-py-lib"
chmod +x "$HOME/bin/my-py-lib"

echo "[6/6] Checking installation..."

echo
echo "Python:"
python --version

echo
echo "Deno:"
deno --version | head -n 1

echo
echo "FFmpeg:"
ffmpeg -version | head -n 1

echo
echo "SpotDL:"
spotdl --version

echo
echo "=========================================="
echo "       Installation completed!"
echo "=========================================="
echo
echo "Run:"
echo "    my-py-lib --help"
echo