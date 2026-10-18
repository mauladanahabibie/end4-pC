#!/usr/bin/env python3
"""File picker for exporting Whiteboard as PNG image."""
import subprocess
import sys
import os

def main():
    default_name = os.path.expanduser(f"~/whiteboard-{os.getpid()}.png")
    # Try Zenity
    try:
        result = subprocess.run(
            ["zenity", "--file-selection", "--save", "--confirm-overwrite",
             "--title=Export Whiteboard as Image",
             f"--filename={default_name}",
             "--file-filter=PNG Images (*.png) | *.png"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            path = result.stdout.strip()
            if not path.endswith(".png"):
                path += ".png"
            print(path)
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Try KDialog
    try:
        result = subprocess.run(
            ["kdialog", "--getsavefilename", default_name, "*.png|PNG Images (*.png)"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            path = result.stdout.strip()
            if not path.endswith(".png"):
                path += ".png"
            print(path)
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

if __name__ == "__main__":
    main()
