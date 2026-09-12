#!/usr/bin/env bash

# Extracts <token> names from an argument declaration string.
# Input:  "<public-key> <file>"
# Output: "public-key\nfile"
program::extract_arg_names() {
	echo "$1" | grep -oP "(?<=<)[^>]+" || true
}

# Derives the option name from a flags string.
# Uses the first long flag (--flag → flag), falling back to short (-f → f).
# Input:  "-n, --num <amount>"
# Output: "num"
program::extract_option_name() {
	local name
	name=$(echo "$1" | grep -oP "(?<=--)[a-zA-Z][a-zA-Z-]*" | head -1)
	if [ -z "$name" ]; then
		name=$(echo "$1" | grep -oP "(?<=-)[a-zA-Z]" | head -1)
	fi
	echo "$name"
}

# Extracts all flag tokens from a flags string.
# Input:  "-n, --num <amount>"
# Output: "-n\n--num"
program::extract_flags() {
	echo "$1" | grep -oP "(-{1,2}[a-zA-Z-]+)"
}
