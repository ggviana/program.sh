#!/usr/bin/env bash
# Demonstrates: depends_of — checking required external commands before running
# shellcheck source=bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "depends-of"
description "Show how to require external commands before running"
depends_of "curl, jq"
depends_of "docker -v"
parse "$@"

echo "All dependencies found — running..."
