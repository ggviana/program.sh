#!/usr/bin/env bash
# Demonstrates: option_type choice — value must be one of a fixed set
# shellcheck source=../bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "convert"
description "Convert a data file to another format"
argument "<file>" "File to convert"
option "-f, --format <fmt>" "Output format" "json"
option_type "--format" choice "json" "yaml" "toml"
parse "$@"

echo "Converting ${program_arg["file"]} to ${program_option["format"]}..."
