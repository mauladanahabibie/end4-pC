#!/usr/bin/env python3
"""Simple image file picker using Zenity or QFileDialog.
Outputs the selected file path to stdout (one line).
If the user cancels, outputs nothing.
"""
import subprocess
import sys

def main():
    try:
        # Try Zenity first (most common on Linux desktops)
        result = subprocess.run(
            ["zenity", "--file-selection",
             "--title=Select Image",
             "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.avif *.bmp *.gif *.tiff *.tif"],
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
             ".", "Images (*.png *.jpg *.jpeg *.webp *.avif *.bmp *.gif *.tiff *.tif)"],
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
