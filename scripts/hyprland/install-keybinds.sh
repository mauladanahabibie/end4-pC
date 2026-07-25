#!/usr/bin/env bash
# install-keybinds.sh — copy keybinds.lua with full cheatsheet descriptions
# to ~/.config/hypr/hyprland/ (replaces existing keybinds.lua)
#
# Usage: bash scripts/hyprland/install-keybinds.sh
#
# Safe to run multiple times. Backs up existing file to keybinds.lua.bak

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC="$REPO_DIR/defaults/hypr/hyprland/keybinds.lua"
DEST="$HOME/.config/hypr/hyprland/keybinds.lua"

if [ ! -f "$SRC" ]; then
    echo "Error: source file not found: $SRC" >&2
    exit 1
fi

mkdir -p "$(dirname "$DEST")"

# Backup existing if different
if [ -f "$DEST" ] && ! cmp -s "$SRC" "$DEST"; then
    cp "$DEST" "$DEST.bak"
    echo "Backed up existing keybinds.lua to keybinds.lua.bak"
fi

cp "$SRC" "$DEST"
echo "Installed keybinds.lua with full cheatsheet descriptions to $DEST"
echo "Run 'hyprctl reload' to apply changes."
