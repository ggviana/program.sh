#!/usr/bin/env bash

# Extracts <token> names from an argument declaration string.
# Input:  "<public-key> <file>"
# Output: "public-key\nfile"
__extract_arg_names() {
	echo "$1" | grep -oP "(?<=<)[^>]+" || true
}

# Derives the option name from a flags string.
# Uses the first long flag (--flag → flag), falling back to short (-f → f).
# Input:  "-n, --num <amount>"
# Output: "num"
__extract_option_name() {
	local name
	name=$(echo "$1" | grep -oP "(?<=--)[a-zA-Z][a-zA-Z-]*" | head -1)
	if [ -z "$name" ]; then
		name=$(echo "$1" | grep -oP "(?<=-)[a-zA-Z]" | head -1)
	fi
	echo "$name"
}

# Extracts [token] names from a flags string, the optional-value form.
# Input:  "--cheese [type]"
# Output: "type"
__extract_optional_arg_names() {
	echo "$1" | grep -oP "(?<=\\[)[^\\]]+" || true
}

# Extracts all flag tokens from a flags string.
# Input:  "-n, --num <amount>"
# Output: "-n\n--num"
__extract_flags() {
	echo "$1" | grep -oP "(-{1,2}[a-zA-Z-]+)"
}
