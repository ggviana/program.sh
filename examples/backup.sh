#!/usr/bin/env bash
# Demonstrates: --no-* flag convention (defaults to true, flag disables the behaviour)
# shellcheck source=../bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "backup"
description "Back up a directory to an archive"
argument "<path>" "Directory to back up"
option "--no-compress" "Skip gzip compression"
parse "$@"

src="${program_arg["path"]}"
dest="backup-$(date +%Y%m%d%H%M%S).tar"

if [ "${program_option["compress"]}" = "true" ]; then
	tar -czf "${dest}.gz" "$src"
	echo "Created ${dest}.gz"
else
	tar -cf "$dest" "$src"
	echo "Created $dest (uncompressed)"
fi
