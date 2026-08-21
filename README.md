My Py Lib

A simple Termux + Debian setup for installing and running SpotDL.

The installer creates a Debian environment inside Termux and installs SpotDL inside a Python virtual environment.

It also creates a Termux:Widget shortcut for easier SpotDL downloads.

What it installs

- Termux "proot-distro"
- Debian
- Python 3
- Python pip
- Python virtual environment
- FFmpeg
- curl
- SpotDL
- SpotDL Termux launcher
- Termux:Widget shortcut

Features

- One-command installation
- Debian-based SpotDL environment
- Python virtual environment
- Direct SpotDL launcher from Termux
- Termux:Widget support
- M4A downloads
- Custom download location
- Default "Download/Spotube" folder
- Storage permission setup
- Android permission helper
- Automatic Debian and SpotDL checks

Requirements

- Android device
- Termux
- Internet connection
- Enough free storage for Debian and Python packages
- Termux:Widget for the home-screen shortcut

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
11. Creates the Termux:Widget "SpotDL" shortcut
12. Configures Termux storage access

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

You don't need to manually run:

proot-distro login debian

or:

source ~/spotdl-env/bin/activate

when using "spotdl-debian".

Termux:Widget

The installer creates:

~/.shortcuts/SpotDL

Add Termux:Widget to your Android home screen and refresh the widget.

Tap SpotDL to start the downloader.

The widget automatically:

1. Checks Termux storage
2. Checks Debian
3. Checks the SpotDL environment
4. Lets you choose a download location
5. Asks for the Spotify URL
6. Runs SpotDL inside Debian
7. Downloads in M4A format
8. Shows the final download location

Download location

The widget provides several options:

1. Download/Spotube
2. Music
3. Download
4. DCIM
5. Custom folder
6. Full Android path

The default location is:

Internal storage/Download/Spotube

You can also enter a custom Android path, for example:

/storage/emulated/0/Music/SpotDL

M4A Downloads

The Widget uses M4A output by default.

Files are saved as:

Artist - Title.m4a

Android Permissions

The installer requests Termux storage access using:

termux-setup-storage

A permission helper is also available:

spotdl-permissions

Android permissions must be approved manually when Android displays the permission screen.

«Note: Termux scripts cannot silently grant Android permissions or install Termux:Widget. Termux:Widget must be installed separately.»

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

"proot-distro" not found

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

Widget doesn't appear

Make sure Termux:Widget is installed.

The shortcut should exist at:

~/.shortcuts/SpotDL

Check:

ls -l ~/.shortcuts/SpotDL

It should have executable permissions.

Repository

https://github.com/Sgkmods13/my-py-lib

Download ZIP

https://github.com/Sgkmods13/my-py-lib/archive/refs/heads/main.zip

Credits

My Py Lib — SpotDL for Termux

Created by @Sgkmods13

If you redistribute or modify this project, please keep the original credit.

Disclaimer

This is an unofficial Termux/Debian setup for SpotDL.

Use SpotDL only for content you are authorized to download and in accordance with applicable copyright laws and service terms.
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
