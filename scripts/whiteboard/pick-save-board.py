#!/usr/bin/env python3
"""File picker for saving Whiteboard JSON documents."""
import subprocess
import sys
import os

def main():
    default_name = os.path.expanduser("~/whiteboard.json")
    # Try Zenity
    try:
        result = subprocess.run(
            ["zenity", "--file-selection", "--save", "--confirm-overwrite",
             "--title=Save Whiteboard As",
             f"--filename={default_name}",
             "--file-filter=Whiteboard Documents (*.json) | *.json"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            path = result.stdout.strip()
            if not path.endswith(".json"):
                path += ".json"
            print(path)
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Try KDialog
    try:
        result = subprocess.run(
            ["kdialog", "--getsavefilename", default_name, "*.json|Whiteboard Documents (*.json)"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            path = result.stdout.strip()
            if not path.endswith(".json"):
                path += ".json"
            print(path)
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

if __name__ == "__main__":
    main()
