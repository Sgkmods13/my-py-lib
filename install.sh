#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "=========================================="
echo "       My Py Lib - SpotDL Installer"
echo "       Termux + Debian + Python"
echo "=========================================="

# ------------------------------------------
# 1. Check Termux
# ------------------------------------------

if [ -z "$PREFIX" ]; then
    echo "ERROR: This installer must be run inside Termux."
    exit 1
fi

# ------------------------------------------
# 2. Update Termux
# ------------------------------------------

echo
echo "[1/8] Updating Termux..."
pkg update -y
pkg install -y proot-distro

# ------------------------------------------
# 3. Install Debian
# ------------------------------------------

echo
echo "[2/8] Checking Debian..."

if proot-distro list 2>/dev/null | grep -q "debian.*installed"; then
    echo "Debian is already installed."
else
    echo "Installing Debian..."
    proot-distro install debian
fi

# ------------------------------------------
# 4. Create Debian setup script
# ------------------------------------------

echo
echo "[3/8] Preparing Debian..."

cat > "$PREFIX/tmp_my_py_lib_debian.sh" <<'DEBIAN_SCRIPT'
#!/bin/bash

set -e

echo "=========================================="
echo "       Debian SpotDL Setup"
echo "=========================================="

echo "[1/5] Updating Debian..."
apt update
apt upgrade -y

echo
echo "[2/5] Installing required packages..."
apt install -y python3 python3-pip python3-venv ffmpeg curl

echo
echo "[3/5] Creating Python virtual environment..."

if [ ! -d "$HOME/spotdl-env" ]; then
    python3 -m venv "$HOME/spotdl-env"
fi

echo
echo "[4/5] Installing SpotDL..."

source "$HOME/spotdl-env/bin/activate"

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

echo
echo "[5/5] Checking SpotDL..."

spotdl --version

echo
echo "=========================================="
echo "       SpotDL installation complete!"
echo "=========================================="
DEBIAN_SCRIPT

chmod +x "$PREFIX/tmp_my_py_lib_debian.sh"

# ------------------------------------------
# 5. Run setup inside Debian
# ------------------------------------------

echo
echo "[4/8] Entering Debian..."
echo

proot-distro login debian -- bash -c "cp '$PREFIX/tmp_my_py_lib_debian.sh' /root/setup-spotdl.sh && chmod +x /root/setup-spotdl.sh && /root/setup-spotdl.sh"

# ------------------------------------------
# 6. Create launcher
# ------------------------------------------

echo
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
