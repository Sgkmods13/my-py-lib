My Py Lib

A simple Termux + Debian setup for installing and running SpotDL.

The installer creates a Debian environment inside Termux and installs SpotDL inside a Python virtual environment.

What it installs

- Termux "proot-distro"
- Debian
- Python 3
- Python pip
- Python virtual environment
- FFmpeg
- curl
- SpotDL

Requirements

- Android device
- Termux
- Internet connection
- Enough free storage for Debian and Python packages

One-command installation

Open Termux and run:

curl -fsSL https://raw.githubusercontent.com/Sgkmods13/my-py-lib/main/install.sh | bash

The installer automatically:

1. Updates Termux
2. Installs "proot-distro"
3. Installs Debian
4. Enters Debian
5. Updates Debian
6. Installs Python, pip, venv, FFmpeg and curl
7. Creates the "spotdl-env" Python virtual environment
8. Installs SpotDL
9. Checks SpotDL
10. Creates the "spotdl-debian" launcher

Check installation

From normal Termux:

spotdl-debian --version

Or enter Debian:

proot-distro login debian

Then:

source ~/spotdl-env/bin/activate
spotdl --version

Use SpotDL

Directly from Termux

spotdl-debian "SONG NAME ARTIST"

Spotify URL

spotdl-debian "https://open.spotify.com/track/..."

Show help

spotdl-debian --help

Enter Debian manually

proot-distro login debian

Activate SpotDL:

source ~/spotdl-env/bin/activate

Exit Debian:

exit

Update SpotDL

Enter Debian:

proot-distro login debian

Activate the environment:

source ~/spotdl-env/bin/activate

Update SpotDL:

python -m pip install --upgrade spotdl

Check:

spotdl --version

Troubleshooting

proot-distro not found

pkg update
pkg install proot-distro -y

Debian is not installed

proot-distro install debian

Then:

proot-distro login debian

SpotDL not found

proot-distro login debian

Then:

source ~/spotdl-env/bin/activate
spotdl --version

FFmpeg not found

Inside Debian:

apt update
apt install ffmpeg -y

Then:

ffmpeg -version

Repository

https://github.com/Sgkmods13/my-py-lib

Download ZIP

https://github.com/Sgkmods13/my-py-lib/archive/refs/heads/main.zip

Important

SpotDL is installed inside Debian's Python virtual environment, not directly into the Termux Python environment.

License

MIT License

Copyright (c) 2026 Sgkmods13
