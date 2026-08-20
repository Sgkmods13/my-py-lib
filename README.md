My Py Lib

A simple Termux installer for Python, SpotDL, FFmpeg, Deno, and Git.

Requirements

- Android
- Termux
- Internet connection

One-command installation

Open Termux and run:

curl -fsSL https://raw.githubusercontent.com/Sgkmods13/my-py-lib/main/install.sh | bash

The installer will:

1. Update Termux packages
2. Install Python
3. Install FFmpeg
4. Install Git
5. Install Deno
6. Install SpotDL

Check installation

After installation, check:

python --version

deno --version

ffmpeg -version

spotdl --version

Use SpotDL

Show help:

spotdl --help

Search for a song:

spotdl "SONG NAME ARTIST"

Or use a URL:

spotdl "SPOTIFY_URL"

Update SpotDL

python -m pip install --upgrade spotdl

Download the repository

GitHub:

https://github.com/Sgkmods13/my-py-lib

ZIP:

https://github.com/Sgkmods13/my-py-lib/archive/refs/heads/main.zip

Troubleshooting

If "curl" is not installed:

pkg install curl

Then run the installation command again.

If Deno cannot be installed:

pkg update
pkg search deno

If SpotDL is already installed:

python -m pip install --upgrade spotdl

License

MIT License

Copyright (c) 2026 Sgkmods13
