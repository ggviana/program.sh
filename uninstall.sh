#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/lib}"
DEST="$INSTALL_DIR/program.sh"

if [ ! -f "$DEST" ]; then
    echo "Not installed: $DEST" >&2
    exit 1
fi

rm "$DEST"
rm -f "$INSTALL_DIR/trim.sh" "$INSTALL_DIR/extract.sh"
echo "Removed: $DEST"
