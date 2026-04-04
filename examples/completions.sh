#!/usr/bin/env bash
# Demonstrates: --generate-completions to produce a bash tab completion script
# shellcheck source=../bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "completions"
description "Show how to generate and install tab completions"
option "--shell <shell>" "Target shell" "bash"
option_type "--shell" choice "bash" "zsh"
parse "$@"

# Running this script with --generate-completions outputs a ready-to-source
# completion script. Wire it up by adding to your shell profile:
#
#   source <(completions --generate-completions)
#
# Or save it to a completions directory:
#
#   completions --generate-completions > ~/.local/share/bash-completion/completions/completions

echo "Run with --generate-completions to output a tab completion script."
echo "Example: $0 --generate-completions"
