#!/usr/bin/env bash
# Demonstrates: option_type integer — value must be a valid integer
# shellcheck source=../bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "repeat"
description "Print a message multiple times"
argument "<message>" "Message to print"
option "-n, --times <n>" "Number of times to repeat" "3"
option_type "--times" integer
parse "$@"

for ((i = 0; i < program_option["times"]; i++)); do
	echo "${program_arg["message"]}"
done
