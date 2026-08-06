#!/usr/bin/env bash
# Demonstrates: boolean flag — action gated behind --force
# shellcheck source=bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "publish"
description "Publish the current package"
option "--force" "Overwrite an existing published version"
parse "$@"

if [ "${program_option["force"]}" != "true" ]; then
	echo "Error: use --force to overwrite an existing published version" >&2
	exit 1
fi

echo "Publishing package..."
