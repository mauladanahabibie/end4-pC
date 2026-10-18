#!/usr/bin/env python3
"""File picker for opening Whiteboard JSON documents."""
import subprocess
import sys
import os

def main():
    initial_dir = os.path.expanduser("~")
    # Try Zenity
    try:
        result = subprocess.run(
            ["zenity", "--file-selection",
             "--title=Open Whiteboard",
             f"--filename={initial_dir}/",
             "--file-filter=Whiteboard Documents (*.json) | *.json",
             "--file-filter=All Files | *"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            print(result.stdout.strip())
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Try KDialog
    try:
        result = subprocess.run(
            ["kdialog", "--getopenfilename", initial_dir, "*.json|Whiteboard Documents (*.json)"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            print(result.stdout.strip())
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

if __name__ == "__main__":
    main()
