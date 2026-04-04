#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/lib}"
DEST="$INSTALL_DIR/program.sh"
BASE_URL="https://raw.githubusercontent.com/ggviana/program.sh/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$INSTALL_DIR"

get_file() {
    local local_path="$SCRIPT_DIR/$1"
    if [ -f "$local_path" ]; then
        cat "$local_path"
    else
        curl -fsSL "$BASE_URL/$1"
    fi
}

# Bundle into a single file: program.sh with lib files inlined
{
    get_file bin/program.sh | grep -v "# shellcheck source=lib/\|source.*\.\./lib/"
    get_file lib/trim.sh | grep -v "^#!"
    get_file lib/extract.sh | grep -v "^#!"
} >"$DEST"

chmod 644 "$DEST"

echo "Installed: $DEST"
echo "Source it in your scripts with:"
echo "  source \"$DEST\""
