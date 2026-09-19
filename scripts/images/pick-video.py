#!/usr/bin/env python3
"""Simple video file picker using Zenity or QFileDialog.
Outputs the selected file path to stdout (one line).
If the user cancels, outputs nothing.
"""
import subprocess
import sys

VIDEO_FILTER = "Videos | *.mp4 *.webm *.mkv *.mov *.avi *.m4v *.ogv"

def main():
    # Try Zenity first (most common on Linux desktops)
    try:
        result = subprocess.run(
            ["zenity", "--file-selection",
             "--title=Select Video",
             f"--file-filter={VIDEO_FILTER}"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            print(result.stdout.strip())
            return
    except FileNotFoundError:
        pass
    except subprocess.TimeoutExpired:
        pass

    # Fallback: try kdialog (KDE)
    try:
        result = subprocess.run(
            ["kdialog", "--getopenfilename",
             ".", "Videos (*.mp4 *.webm *.mkv *.mov *.avi *.m4v *.ogv)"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            print(result.stdout.strip())
            return
    except FileNotFoundError:
        pass
    except subprocess.TimeoutExpired:
        pass

    # No dialog available — output nothing (the QML side handles empty)
    sys.stderr.write("No file picker available (install zenity or kdialog)\n")

if __name__ == "__main__":
    main()
