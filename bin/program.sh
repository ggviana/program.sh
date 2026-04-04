#!/usr/bin/env bash

program_name=""
program_description=""
program_has_args=false
program_has_options=false
program_options=""
program_args_name=""
program_args_description=""
# shellcheck disable=SC2034
declare -A program_arg
declare -a program_args
declare -A program_args_default
declare -i program_args_count=0
declare -A program_option
declare -A program_option_type
declare -A program_option_choices

# Sets the program name shown in the usage line.
# Sets $program_name.
#
# Usage: name "<name>"
#
# Example:
#   name "port-kill"
name() {
	program_name="$1"
}

# Sets the one-line description shown below the usage line.
# Sets $program_description.
#
# Usage: description "<text>"
#
# Example:
#   description "Kills the process listening on the given port"
description() {
	program_description="$1"
}

# Declares a single positional argument. Only one declaration is supported per script.
# Sets $program_args_name, $program_args_description, and $program_args_default.
# After parse(), named tokens are accessible via $program_arg["name"].
# If no default is given, the argument is mandatory — parse() exits 1 when it is missing.
#
# Usage: argument "<name>" "<description>" "<default>"
#
# Example:
#   argument "<port>" "Port number to kill"
#   argument "<public-key> <file>" "Key and file to encrypt"
#   argument "<path>" "Directory to scan" "./"
argument() {
	program_has_args=true
	program_args_name="$1"
	program_args_description="$2"
	program_args_default["$1"]="$3"
}

# Declares a named option. Multiple options can be declared.
# The option name is derived from the first long flag (--flag → flag),
# falling back to the short flag (-f → f).
# --no-* flags strip the no- prefix from the key, default to true, and set to false when passed.
# Initialises $program_option["name"] (and all aliases) with the default value.
#
# Usage: option "<flags>" "<description>" "<default>"
#
# Flag forms: -f | --flag | -f, --flag | -f <val> | --flag <val> | --no-feature
# A flag is value-accepting when the flags string contains <...>.
#
# Example:
#   option "-n, --num <amount>" "Number of results" "10"
#   option "--force" "Skip confirmation"
#   option "--no-cheese" "Omit cheese"  → program_option["cheese"]
option() {
	local option_flags=$1
	local option_description
	local option_default_value
	option_description=$(__trim "$2")
	option_default_value=$(__trim "$3")

	# Derive name from the first long flag (--flag → flag), falling back to short (-f → f)
	local option_name
	option_name=$(__extract_option_name "$option_flags")

	# --no-* flags: strip the no- prefix from the key and default to true
	if [[ "$option_flags" =~ (^|,\ )--no- ]]; then
		option_name="${option_name#no-}"
		if [ -z "$option_default_value" ]; then
			option_default_value=true
		fi
	fi

	program_has_options=true
	program_options+="$option_name:$option_flags:$option_description:$option_default_value;"

	# Initialize the canonical name and every stripped flag alias with the default
	program_option["$option_name"]="$option_default_value"
	local _flags
	IFS=$'\n' read -r -d ' ' -a _flags <<<"$(__extract_flags "$option_flags")"
	for _flag in "${_flags[@]}"; do
		local _alias="${_flag#-}"
		_alias="${_alias#-}"
		program_option["$_alias"]="$option_default_value"
	done
}

# Declares the type of value an option accepts, enabling runtime validation and
# (later) completion generation. Must be called after option() and before parse().
# Validation is skipped when the option value is empty.
#
# Types:
#   choice  <v1> <v2> ...   value must be one of the listed values
#   integer                 value must be a valid integer (negative allowed)
#   path                    value is a path/glob string — no runtime validation
#   between <min> <max>     value must be a float in [min, max] (inclusive)
#
# Usage: option_type "<flag>" <type> [<args>...]
#
# Example:
#   option_type "--to"    choice  "480" "720" "1080"
#   option_type "--num"   integer
#   option_type "--key"   path
#   option_type "--scale" between 0.0 1.0
option_type() {
	local flag="$1"
	local type="$2"
	shift 2
	local option_name="${flag#-}"
	option_name="${option_name#-}"
	program_option_type["$option_name"]="$type"
	if [ "$type" = "choice" ] || [ "$type" = "between" ]; then
		program_option_choices["$option_name"]="$*"
	fi
}

# Outputs a bash completion script for the current program to stdout.
# Re-derives all metadata from program_options and program_option_type —
# safe to call before or after parse().
# Triggered automatically via --generate-completions (same pattern as --help).
#
# Completion behavior per option type:
#   choice  → compgen -W "<choices>"
#   path    → compgen -f  (file/directory names)
#   integer / between / (none) → COMPREPLY=(); return 0
#   boolean (no <value>) → no case branch; appears in opts only
#
# Usage: generate_completions > completions/<name>.bash
generate_completions() {
	local func_name="_${program_name//-/_}_complete"
	local all_opts=""
	local -a case_lines=()

	IFS=';' read -ra _gc_opts <<<"$program_options"
	for _gc_opt in "${_gc_opts[@]}"; do
		IFS=':' read -r _gc_name _gc_flags _ _ <<<"$_gc_opt"
		[ -z "$_gc_name" ] && continue

		local _gc_has_value=false
		[[ "$_gc_flags" =~ \<.*\> ]] && _gc_has_value=true

		local _gc_flag_tokens=()
		while IFS= read -r _gc_f; do
			[ -z "$_gc_f" ] && continue
			_gc_flag_tokens+=("$_gc_f")
			all_opts+=" $_gc_f"
		done <<<"$(__extract_flags "$_gc_flags")"

		if [ "$_gc_has_value" = true ] && [ "${#_gc_flag_tokens[@]}" -gt 0 ]; then
			local _gc_pattern=""
			for _gc_f in "${_gc_flag_tokens[@]}"; do
				_gc_pattern+="${_gc_pattern:+|}${_gc_f}"
			done

			case "${program_option_type["$_gc_name"]}" in
			choice)
				local _gc_choices="${program_option_choices["$_gc_name"]}"
				case_lines+=("        ${_gc_pattern})")
				case_lines+=("            COMPREPLY=( \$(compgen -W \"${_gc_choices}\" -- \"\$cur\") )")
				case_lines+=("            return 0")
				case_lines+=("            ;;")
				;;
			path)
				case_lines+=("        ${_gc_pattern})")
				case_lines+=("            COMPREPLY=( \$(compgen -f -- \"\$cur\") )")
				case_lines+=("            return 0")
				case_lines+=("            ;;")
				;;
			*)
				case_lines+=("        ${_gc_pattern})")
				case_lines+=("            COMPREPLY=(); return 0")
				case_lines+=("            ;;")
				;;
			esac
		fi
	done

	all_opts="${all_opts# }"

	echo "${func_name}() {"
	echo "    local cur prev"
	echo "    COMPREPLY=()"
	echo "    cur=\"\${COMP_WORDS[COMP_CWORD]}\""
	echo "    prev=\"\${COMP_WORDS[COMP_CWORD-1]}\""
	echo "    local opts=\"${all_opts}\""
	echo ""
	echo "    case \"\$prev\" in"
	for _gc_line in "${case_lines[@]}"; do
		echo "$_gc_line"
	done
	echo "    esac"
	echo ""
	echo "    if [[ \"\$cur\" == -* ]]; then"
	echo "        COMPREPLY=( \$(compgen -W \"\${opts}\" -- \"\$cur\") )"
	echo "    else"
	echo "        COMPREPLY=( \$(compgen -f -- \"\$cur\") )"
	echo "    fi"
	echo "    return 0"
	echo "}"
	echo ""
	echo "complete -F ${func_name} ${program_name}"
}

# Prints the formatted help text to stdout.
# Called automatically by parse() when --help or -h is passed.
# Sections printed (only when applicable):
#   1. Usage line
#   2. Description
#   3. Arguments block
#   4. Options block (with defaults and choices when set)
#
# Usage: usage
usage() {
	local usage_text="Usage: $program_name"

	usage_text="$usage_text [options]"

	if [ "$program_has_args" = true ]; then
		usage_text="$usage_text $program_args_name"
	fi

	# Prints usage
	echo "$usage_text"

	# Prints description
	echo -e "\n$program_description"

	# Prints arguments
	if [ "$program_has_args" = true ]; then
		echo -e "\nArguments:"
		printf "  %-20s %s\n" "$program_args_name" "$program_args_description"
	fi

	# Prints options
	echo -e "\nOptions:"
	if [ "$program_has_options" = true ]; then
		IFS=';' read -ra options <<<"$program_options"
		for option in "${options[@]}"; do
			IFS=':' read -r option_name option_flags option_description option_default_value <<<"$option"
			local suffix=""
			if [ -n "$option_default_value" ]; then
				suffix=" (default: $option_default_value)"
			fi
			if [ -n "${program_option_choices["$option_name"]}" ]; then
				local choices_display
				choices_display="${program_option_choices["$option_name"]// /, }"
				suffix="$suffix (choices: $choices_display)"
			fi
			printf "  %-20s %s%s\n" "$option_flags" "$option_description" "$suffix"
		done
	fi
	printf "  %-20s %s\n" "--help, -h" "Show this help message"
	printf "  %-20s %s\n" "--generate-completions" "Output a bash completion script"
}

# Parses the script's arguments. Must be called after all option() and argument() declarations.
# - Handles --help / -h: prints usage and exits 0.
# - Matched flags store their value in $program_option["name"] and all aliases.
#   Value-accepting flags consume the next token; boolean flags store "true".
# - Unrecognised tokens are appended to $program_args (indexed) and $program_arg (named).
# - Validates option_choices constraints; exits 1 on invalid value.
# - If a mandatory argument is missing, prints an error and exits 1.
#
# Usage: parse "$@"
parse() {
	declare -a all_flags
	declare -A option_aliases # option_name → space-separated stripped flag names
	declare -A program_flag_has_arg
	declare -A program_flag_option_name
	IFS=';' read -ra options <<<"$program_options"
	for option in "${options[@]}"; do
		IFS=':' read -r option_name option_flags option_description option_default_value <<<"$option"

		IFS=$'\n' read -r -d ' ' -a flags <<<"$(__extract_flags "$option_flags")"

		for flag in "${flags[@]}"; do
			all_flags+=("$flag")
			program_flag_option_name["$flag"]="$option_name"
			program_flag_has_arg["$flag"]=false
			if [ -n "$(__extract_arg_names "$option_flags")" ]; then
				program_flag_has_arg["$flag"]=true
			fi
			local alias="${flag#-}"
			alias="${alias#-}"
			option_aliases["$option_name"]+="$alias "
		done
	done

	while [[ $# -gt 0 ]]; do
		arg="$1"
		shift
		case "$arg" in
		--help | -h)
			usage
			exit 0
			;;
		--generate-completions)
			generate_completions
			exit 0
			;;
		*)
			local matched=false
			for flag in "${all_flags[@]}"; do
				if [ "$flag" == "$arg" ]; then
					local option_name="${program_flag_option_name["$flag"]}"
					local value
					if [ "${program_flag_has_arg["$flag"]}" = "true" ]; then
						value="$1"
						shift
					else
						if [[ "$flag" =~ ^--no- ]]; then
							value=false
						else
							value=true
						fi
					fi
					program_option["$option_name"]="$value"
					for alias in ${option_aliases["$option_name"]}; do
						program_option["$alias"]="$value"
					done
					matched=true
				fi
			done
			if [ "$matched" = false ]; then
				program_args+=("$arg")
				((program_args_count++))
			fi
			;;
		esac
	done

	# Populate named keys from declared argument names
	if [ "$program_has_args" = true ]; then
		local _i=0
		while IFS= read -r _name; do
			[ -n "$_name" ] || continue
			# shellcheck disable=SC2034
			program_arg["$_name"]="${program_args[$_i]}"
			((_i++))
		done <<<"$(__extract_arg_names "$program_args_name")"
	fi

	# Validate option types
	for _opt_name in "${!program_option_type[@]}"; do
		local _value="${program_option["$_opt_name"]}"
		[ -z "$_value" ] && continue
		case "${program_option_type["$_opt_name"]}" in
		choice)
			local _choices="${program_option_choices["$_opt_name"]}"
			local _valid=false
			for _choice in $_choices; do
				if [ "$_value" = "$_choice" ]; then
					_valid=true
					break
				fi
			done
			if [ "$_valid" = false ]; then
				local _choices_display
				_choices_display="${_choices// /, }"
				echo "Error: invalid value for --$_opt_name: \"$_value\". Valid choices: $_choices_display" >&2
				usage >&2
				exit 1
			fi
			;;
		integer)
			if [[ ! "$_value" =~ ^-?[0-9]+$ ]]; then
				echo "Error: --$_opt_name expects an integer, got \"$_value\"" >&2
				usage >&2
				exit 1
			fi
			;;
		path) ;;
		between)
			local _min _max
			_min=$(echo "${program_option_choices["$_opt_name"]}" | cut -d' ' -f1)
			_max=$(echo "${program_option_choices["$_opt_name"]}" | cut -d' ' -f2)
			if ! [[ "$_value" =~ ^-?[0-9]*\.?[0-9]+$ ]] ||
				! awk "BEGIN { exit !($_value >= $_min && $_value <= $_max) }"; then
				echo "Error: --$_opt_name must be a number between $_min and $_max, got \"$_value\"" >&2
				usage >&2
				exit 1
			fi
			;;
		esac
	done

	if [ "$program_has_args" = true ] &&
		[ -z "${program_args_default["$program_args_name"]}" ] &&
		[ "$program_args_count" -eq 0 ]; then
		echo "Error: argument $program_args_name is required" >&2
		usage >&2
		exit 1
	fi
}

# shellcheck source=lib/trim.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/trim.sh"
# shellcheck source=lib/extract.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/extract.sh"
