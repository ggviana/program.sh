#!/usr/bin/env bash
# Demonstrates: option_type between — value must be a float within a range
# shellcheck source=../bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "sleep-for"
description "Sleep for a given number of seconds"
option "-s, --seconds <n>" "Seconds to sleep" "1"
option_type "--seconds" between 0.1 60
parse "$@"

echo "Sleeping for ${program_option["seconds"]}s..."
sleep "${program_option["seconds"]}"
echo "Done"
