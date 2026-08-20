import subprocess
import sys


def main():
    if len(sys.argv) == 1:
        print("My Py Lib")
        print("SpotDL Termux launcher")
        print()
        print("Usage:")
        print("  my-py-lib <song or Spotify URL>")
        print()
        print("Examples:")
        print('  my-py-lib "Believer Imagine Dragons"')
        print("  my-py-lib https://open.spotify.com/track/...")
        return

    command = ["spotdl"] + sys.argv[1:]

    try:
        subprocess.run(command, check=True)
    except FileNotFoundError:
        print("SpotDL is not installed.")
        print("Run install.sh first.")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(130)


if __name__ == "__main__":
    main()
