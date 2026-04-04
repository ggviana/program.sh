#!/usr/bin/env bash
# Demonstrates: positional argument with named token access
# shellcheck source=../bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "greet"
description "Greet someone by name"
argument "<name>" "The name to greet"
parse "$@"

echo "Hello, ${program_arg["name"]}!"
