#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "Updating My Py Lib dependencies..."

pkg update -y

python -m pip install --upgrade pip
python -m pip install --upgrade spotdl

echo
echo "Checking versions..."

python --version
deno --version | head -n 1
ffmpeg -version | head -n 1
spotdl --version

echo
echo "Update complete."