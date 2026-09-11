#!/usr/bin/env bash
# Demonstrates: value-accepting option with a default, plus option_env fallback
# shellcheck source=bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "serve"
description "Serve the current directory over HTTP"
option "-p, --port <port>" "Port to listen on" "8080"
option_env "--port" "PORT"
option_type "--port" integer
parse "$@"

echo "Serving on http://localhost:${program_option["port"]}"
python3 -m http.server "${program_option["port"]}"
