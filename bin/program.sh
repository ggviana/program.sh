#!/usr/bin/env bash

program_name=""
program_description=""
program_has_args=false
program_has_options=false
program_options=""
program_args_name=""
program_args_description=""
program_version=""
program_allow_unknown_options=false
# shellcheck disable=SC2034
declare -A program_arg
declare -a program_args
declare -A program_args_default
declare -i program_args_count=0
declare -A program_option
declare -A program_option_type
declare -A program_option_choices
declare -A program_option_flag
declare -A program_option_env
declare -A program_option_validator
# Built-in flags are pre-registered so a script that declares one of them gets the
# same redeclaration error as any other collision, instead of being shadowed.
declare -A program_option_declared=(
	["help"]="--help, -h" ["--help"]="--help, -h" ["-h"]="--help, -h"
	["version"]="--version" ["--version"]="--version"
	["generate-completions"]="--generate-completions"
	["--generate-completions"]="--generate-completions"
)
declare -A program_option_required
declare -a program_dependencies
declare -A program_dependency_declared

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

# Sets the version string reported by --version. Optional: when it is not called,
# --version falls back to the modification time of the running script, formatted
# vYYYY.mm.DD.HHmmss, so every script has a version without declaring one.
# Sets $program_version.
#
# Usage: version "<string>"
version() {
	program_version="$1"
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

# Declares a named option. Multiple options can be declared, but each option name
# and each flag may be declared only once — a redeclaration exits 1.
# The option name is derived from the first long flag (--flag → flag),
# falling back to the short flag (-f → f).
# --no-* flags strip the no- prefix from the key, default to true, and set to false when passed.
# Initialises $program_option["name"] (and all aliases) with the default value.
#
# Usage: option "<flags>" "<description>" "<default>"
#
# Flag forms: -f | --flag | -f, --flag | -f <val> | --flag <val> | --no-feature
# A flag is value-accepting when the flags string contains <...>, and takes an
# optional value when it contains [...] — in that form, passing the flag with no
# value after it stores "true", exactly like a boolean flag.
#
# Example:
#   option "-n, --num <amount>" "Number of results" "10"
#   option "--force" "Skip confirmation"
#   option "--no-cheese" "Omit cheese"  → program_option["cheese"]
option() {
	local option_flags=$1
	local option_description
	option_description=$(__trim "$2")
	# The description is presentation and is trimmed; the default is data and is not,
	# so a whitespace-significant default such as ", " survives intact.
	local option_default_value="$3"

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

	local _flags
	IFS=$'\n' read -r -d ' ' -a _flags <<<"$(__extract_flags "$option_flags")"

	# Reject redeclarations before touching any state. Reported under whichever
	# declaration form the caller used, since required_option() delegates here.
	local _decl="option"
	[ "${FUNCNAME[1]:-}" = required_option ] && _decl="required_option"
	if [ -n "${program_option_declared["$option_name"]+declared}" ]; then
		echo "Error: $_decl \"$option_flags\" redeclares the option name \"$option_name\", already declared by \"${program_option_declared["$option_name"]}\"" >&2
		exit 1
	fi
	for _flag in "${_flags[@]}"; do
		if [ -n "${program_option_declared["$_flag"]+declared}" ]; then
			echo "Error: $_decl \"$option_flags\" redeclares the flag \"$_flag\", already declared by \"${program_option_declared["$_flag"]}\"" >&2
			exit 1
		fi
	done
	program_option_declared["$option_name"]="$option_flags"
	for _flag in "${_flags[@]}"; do
		program_option_declared["$_flag"]="$option_flags"
	done

	program_has_options=true
	program_options+="$option_name:$option_flags:$option_description:$option_default_value;"

	# Initialize the canonical name and every stripped flag alias with the default
	program_option["$option_name"]="$option_default_value"
	for _flag in "${_flags[@]}"; do
		local _alias="${_flag#-}"
		_alias="${_alias#-}"
		program_option["$_alias"]="$option_default_value"
		# The flag error messages refer to: the first long form, else the short one
		if [ -z "${program_option_flag["$option_name"]}" ] ||
			[[ "$_flag" == --* && "${program_option_flag["$option_name"]}" != --* ]]; then
			program_option_flag["$option_name"]="$_flag"
		fi
	done
}

# Prints the declared flag closest to an unrecognised one, when the two are close
# enough that a typo is the likely explanation. Candidates are read from stdin, one
# per line. Prints nothing when the token is too short to guess at or nothing is near.
__suggest_flag() {
	local unknown="$1"
	[ "${#unknown}" -ge 4 ] || return 0
	awk -v a="$unknown" '
		function lev(s, t,   ls, lt, i, j, c, m, d) {
			ls = length(s); lt = length(t)
			for (i = 0; i <= ls; i++) d[i, 0] = i
			for (j = 0; j <= lt; j++) d[0, j] = j
			for (i = 1; i <= ls; i++)
				for (j = 1; j <= lt; j++) {
					c = (substr(s, i, 1) == substr(t, j, 1)) ? 0 : 1
					m = d[i - 1, j] + 1
					if (d[i, j - 1] + 1 < m) m = d[i, j - 1] + 1
					if (d[i - 1, j - 1] + c < m) m = d[i - 1, j - 1] + c
					d[i, j] = m
				}
			return d[ls, lt]
		}
		NF {
			dist = lev(a, $0)
			if (best == "" || dist < best) { best = dist; cand = $0 }
		}
		END { if (best != "" && best <= 2) print cand }
	'
}

# True when a token reads as a flag rather than as data: it starts with a dash, is
# not a lone "-", and is not a negative number. Both of those are ordinary arguments.
__looks_like_flag() {
	[[ "$1" == -?* ]] || return 1
	[[ "$1" =~ ^-[0-9]+([.][0-9]+)?$ ]] && return 1
	return 0
}

# Formats a file's modification time as vYYYY.mm.DD.HHmmss. Handles both BSD
# (stat -f %m, date -r <epoch>) and GNU (stat -c %Y, date -d @<epoch>) userlands.
# Returns non-zero when the file is unreadable or neither flavour is available.
__file_version() {
	local file="$1" epoch
	[ -f "$file" ] || return 1
	epoch=$(stat -f %m "$file" 2>/dev/null) || epoch=$(stat -c %Y "$file" 2>/dev/null) || return 1
	[ -n "$epoch" ] || return 1
	date -r "$epoch" +"v%Y.%m.%d.%H%M%S" 2>/dev/null ||
		date -d "@$epoch" +"v%Y.%m.%d.%H%M%S" 2>/dev/null
}

# Prints the version reported by --version: the declared string when version() was
# called, otherwise the running script's modification time.
__program_version() {
	if [ -n "$program_version" ]; then
		echo "$program_version"
	else
		__file_version "$0" || echo "unknown"
	fi
}

# Resolves any flag or alias to the canonical option name registered by option().
# Given "option \"-t, --to <res>\"", both "-t" and "--to" resolve to "to";
# "--no-cheese" resolves to "cheese". Falls back to the dash-stripped input when
# no declared option owns the flag.
__resolve_option_name() {
	local candidate="${1#-}"
	candidate="${candidate#-}"
	local _ro_options _ro_option _ro_name _ro_flags _ro_rest _ro_flag_list _ro_flag _ro_alias
	IFS=';' read -ra _ro_options <<<"$program_options"
	for _ro_option in "${_ro_options[@]}"; do
		IFS=':' read -r _ro_name _ro_flags _ro_rest <<<"$_ro_option"
		[ -n "$_ro_name" ] || continue
		if [ "$_ro_name" = "$candidate" ]; then
			echo "$candidate"
			return
		fi
		IFS=$'\n' read -r -d ' ' -a _ro_flag_list <<<"$(__extract_flags "$_ro_flags")"
		for _ro_flag in "${_ro_flag_list[@]}"; do
			_ro_alias="${_ro_flag#-}"
			_ro_alias="${_ro_alias#-}"
			if [ "$_ro_alias" = "$candidate" ]; then
				echo "$_ro_name"
				return
			fi
		done
	done
	echo "$candidate"
}

# Declares the type of value an option accepts, enabling runtime validation and
# (later) completion generation. Must be called after option() and before parse(),
# and only once per option — a second declaration for the same option exits 1.
# Any flag of the option may be given — aliases resolve to the canonical name.
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
	local option_name
	option_name=$(__resolve_option_name "$flag")
	if [ -n "${program_option_type["$option_name"]+declared}" ]; then
		echo "Error: option_type \"$flag\" redeclares the type of \"${program_option_flag["$option_name"]:---$option_name}\", already declared as \"${program_option_type["$option_name"]}\"" >&2
		exit 1
	fi
	program_option_type["$option_name"]="$type"
	if [ "$type" = "choice" ] || [ "$type" = "between" ]; then
		program_option_choices["$option_name"]="$*"
	fi
}

# Declares an environment variable to fall back to when the flag is absent from the
# command line. Must be called after the corresponding option declaration and before
# parse(), and only once per option — a second declaration for the same option exits 1. Precedence is: command line, then environment, then the declared default.
# An environment value satisfies required_option() and is checked by option_type()
# exactly like a value passed on the command line.
# Any flag of the option may be given — aliases resolve to the canonical name.
#
# Usage: option_env "<flag>" "<VARIABLE>"
#
# Example:
#   option "-p, --port <port>" "Port to listen on" "8080"
#   option_env "--port" "PORT"
option_env() {
	local option_name
	option_name=$(__resolve_option_name "$1")
	if [ -n "${program_option_env["$option_name"]+declared}" ]; then
		echo "Error: option_env \"$1\" redeclares the variable of \"${program_option_flag["$option_name"]:---$option_name}\", already declared as \"${program_option_env["$option_name"]}\"" >&2
		exit 1
	fi
	program_option_env["$option_name"]="$2"
}

# Declares a function to validate, and optionally transform, an option's value.
# Must be called after the corresponding option declaration and before parse().
# Any flag of the option may be given — aliases resolve to the canonical name.
#
# The function is called with the value as its only argument. Whatever it prints on
# stdout replaces the stored value, so it can coerce as well as check; returning
# non-zero rejects the value and exits 1. It may write its own explanation to
# stderr first. Like option_type(), it is skipped when the value is empty, and it
# runs after the built-in type check so both can apply to one option.
#
# Usage: option_validator "<flag>" <function>
#
# Example:
#   to_upper() { echo "${1^^}"; }
#   option "--env <name>" "Environment"
#   option_validator "--env" to_upper
option_validator() {
	local option_name
	option_name=$(__resolve_option_name "$1")
	if [ -n "${program_option_validator["$option_name"]+declared}" ]; then
		echo "Error: option_validator \"$1\" redeclares the validator of \"${program_option_flag["$option_name"]:---$option_name}\"" >&2
		exit 1
	fi
	program_option_validator["$option_name"]="$2"
}

# Declares a required option. Stands in for option() — it takes the same flags and
# description, registers the option identically, and additionally marks it required.
# parse() prints an error and exits 1 when the flag is absent, the same way an
# unsatisfied option_type does. Composes with option_type: the flag must be passed,
# and its value must then satisfy the declared type.
#
# There is no default parameter: an option with a default can never be missing, so
# passing one — or requiring a --no-* flag, which defaults to true — is an error.
#
# Usage: required_option "<flags>" "<description>"
#
# Example:
#   required_option "--to <resolution>" "Target resolution"
#   option_type "--to" choice "480" "720" "1080"
required_option() {
	local option_flags="$1"
	if [ -n "${3:-}" ]; then
		echo "Error: required_option \"$option_flags\" does not take a default value" >&2
		exit 1
	fi

	option "$option_flags" "$2"

	local _req_flags
	IFS=$'\n' read -r -d ' ' -a _req_flags <<<"$(__extract_flags "$option_flags")"
	local option_name
	option_name=$(__resolve_option_name "${_req_flags[0]}")
	if [ -n "${program_option["$option_name"]}" ]; then
		echo "Error: required_option \"$option_flags\" defaults to true, so it can never be missing" >&2
		exit 1
	fi
	program_option_required["$option_name"]=true
}

# Lets unrecognised flags through as positional arguments instead of failing.
# Without it, parse() exits 1 on any token that looks like a flag but matches no
# declaration. Call it when the script forwards flags to another command.
#
# Usage: allow_unknown_options
#
# Example:
#   argument "<command>" "Command to run"
#   allow_unknown_options
#   parse "$@"        # "each ls -la" keeps -la in program_args
allow_unknown_options() {
	program_allow_unknown_options=true
}

# Declares external command dependencies required by the program. Can be called
# multiple times; each call accepts a comma-separated list, and entries accumulate.
# Each command may be declared only once — a repeat exits 1, whether it appears in
# the same call or a later one, and whether or not the invocation differs.
# Checked by parse() after flags are matched — a failing check prints an error
# and exits 1.
#
# Each entry is either a bare command name, checked by running "<name> --version",
# or a full command (containing a space), run exactly as given — use this form
# when --version isn't the right invocation (e.g. "docker -v").
#
# Usage: depends_of "<list>"
#
# Example:
#   depends_of "curl, jq"        # runs: curl --version / jq --version
#   depends_of "jq, docker -v"   # runs: jq --version    / docker -v
depends_of() {
	local dependencies_list="$1"
	local dependency
	local -a _depends_of_items
	IFS=',' read -ra _depends_of_items <<<"$dependencies_list"
	local dependency_name
	for dependency in "${_depends_of_items[@]}"; do
		dependency=$(__trim "$dependency")
		[ -z "$dependency" ] && continue
		# Keyed by command name, so "docker" and "docker -v" collide: checking one
		# command twice is redundant at best and contradictory at worst.
		dependency_name="${dependency%% *}"
		if [ -n "${program_dependency_declared["$dependency_name"]+declared}" ]; then
			echo "Error: depends_of \"$dependency\" redeclares the dependency \"$dependency_name\", already declared by \"${program_dependency_declared["$dependency_name"]}\"" >&2
			exit 1
		fi
		program_dependency_declared["$dependency_name"]="$dependency"
		program_dependencies+=("$dependency")
	done
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
		[[ "$_gc_flags" =~ \<.*\> || "$_gc_flags" =~ \[.*\] ]] && _gc_has_value=true

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
			if [ -n "${program_option_env["$option_name"]}" ]; then
				suffix="$suffix (env: ${program_option_env["$option_name"]})"
			fi
			if [ -n "${program_option_required["$option_name"]}" ]; then
				suffix="$suffix (required)"
			fi
			printf "  %-20s %s%s\n" "$option_flags" "$option_description" "$suffix"
		done
	fi
	printf "  %-20s %s\n" "--help, -h" "Show this help message"
	printf "  %-20s %s\n" "--version" "Show the version"
	printf "  %-20s %s\n" "--generate-completions" "Output a bash completion script"
}

# Parses the script's arguments. Must be called after all option() and argument() declarations.
# - Handles --help / -h: prints usage and exits 0.
# - Handles --version: prints the declared version, or the script's mtime, exits 0.
# - Matched flags store their value in $program_option["name"] and all aliases.
#   Value-accepting flags consume the next token; boolean flags store "true".
# - Unrecognised tokens are appended to $program_args (indexed) and $program_arg (named);
#   a token that looks like a flag is an error unless allow_unknown_options() was called,
#   and the error suggests the nearest declared flag when one is close enough.
# - Checks depends_of() dependencies; exits 1 if a command is missing or fails.
# - Fills options from option_env() variables before validating anything.
# - Checks required_option() declarations; exits 1 when a required flag is absent.
# - Validates option_choices constraints; exits 1 on invalid value.
# - Runs option_validator() functions, storing whatever they print; exits 1 on
#   a non-zero return.
# - If a mandatory argument is missing, prints an error and exits 1.
#
# Usage: parse "$@"
parse() {
	declare -a all_flags
	declare -A option_aliases # option_name → space-separated stripped flag names
	declare -A program_flag_has_arg
	declare -A program_flag_optional_arg
	declare -A program_flag_option_name
	declare -A program_option_passed # option_name/alias → true when seen on the command line
	IFS=';' read -ra options <<<"$program_options"
	for option in "${options[@]}"; do
		IFS=':' read -r option_name option_flags option_description option_default_value <<<"$option"

		IFS=$'\n' read -r -d ' ' -a flags <<<"$(__extract_flags "$option_flags")"

		for flag in "${flags[@]}"; do
			all_flags+=("$flag")
			program_flag_option_name["$flag"]="$option_name"
			program_flag_has_arg["$flag"]=false
			program_flag_optional_arg["$flag"]=false
			if [ -n "$(__extract_arg_names "$option_flags")" ]; then
				program_flag_has_arg["$flag"]=true
			elif [ -n "$(__extract_optional_arg_names "$option_flags")" ]; then
				program_flag_has_arg["$flag"]=true
				program_flag_optional_arg["$flag"]=true
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
		--version)
			__program_version
			exit 0
			;;
		--generate-completions)
			generate_completions
			exit 0
			;;
		*)
			local matched=false
			local inline_flag="" inline_value=""

			# --flag=value is accepted as an alternative to --flag value
			if [[ "$arg" == --*=* ]]; then
				inline_flag="${arg%%=*}"
				inline_value="${arg#*=}"
			fi

			for flag in "${all_flags[@]}"; do
				local option_name value

				if [ "$flag" == "$arg" ]; then
					option_name="${program_flag_option_name["$flag"]}"
					if [ "${program_flag_optional_arg["$flag"]}" = "true" ]; then
						# [value] is taken only when the next token is data, not a flag
						if [ "$#" -gt 0 ] && ! __looks_like_flag "$1"; then
							value="$1"
							shift
						else
							value=true
						fi
					elif [ "${program_flag_has_arg["$flag"]}" = "true" ]; then
						value="$1"
						shift
					else
						if [[ "$flag" =~ ^--no- ]]; then
							value=false
						else
							value=true
						fi
					fi
				elif [ -n "$inline_flag" ] && [ "$flag" == "$inline_flag" ] &&
					[ "${program_flag_has_arg["$flag"]}" = "true" ]; then
					option_name="${program_flag_option_name["$flag"]}"
					value="$inline_value"
				else
					continue
				fi

				program_option["$option_name"]="$value"
				program_option_passed["$option_name"]=true
				for alias in ${option_aliases["$option_name"]}; do
					program_option["$alias"]="$value"
					program_option_passed["$alias"]=true
				done
				matched=true
			done
			if [ "$matched" = false ]; then
				# A token that looks like a flag but matches nothing is a mistake, not a
				# positional. A lone "-" and negative numbers stay arguments.
				if [ "$program_allow_unknown_options" = false ] && __looks_like_flag "$arg"; then
					if [ -n "$inline_flag" ] && [ -n "${program_flag_has_arg["$inline_flag"]+declared}" ]; then
						echo "Error: option $inline_flag does not take a value" >&2
					else
						echo "Error: unknown option $arg" >&2
						local _suggestion
						_suggestion=$(printf '%s\n' "${all_flags[@]}" --help -h --version --generate-completions |
							__suggest_flag "${inline_flag:-$arg}")
						[ -n "$_suggestion" ] && echo "Did you mean $_suggestion?" >&2
					fi
					usage >&2
					exit 1
				fi
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

	# Environment fallback for options the command line did not provide. Runs before
	# every validation, so an environment value satisfies required_option() and is
	# checked by option_type() like any other.
	local _env_name _env_var _env_alias
	for _env_name in "${!program_option_env[@]}"; do
		[ "${program_option_passed["$_env_name"]:-}" = true ] && continue
		_env_var="${program_option_env["$_env_name"]}"
		[ -n "${!_env_var:-}" ] || continue
		program_option["$_env_name"]="${!_env_var}"
		program_option_passed["$_env_name"]=true
		for _env_alias in ${option_aliases["$_env_name"]}; do
			program_option["$_env_alias"]="${!_env_var}"
			program_option_passed["$_env_alias"]=true
		done
	done

	# Validate dependencies
	for _dep in "${program_dependencies[@]}"; do
		local -a _dep_cmd
		local _dep_name
		if [[ "$_dep" == *" "* ]]; then
			read -ra _dep_cmd <<<"$_dep"
			_dep_name="${_dep_cmd[0]}"
		else
			_dep_cmd=("$_dep" "--version")
			_dep_name="$_dep"
		fi
		if ! "${_dep_cmd[@]}" &>/dev/null; then
			echo "Error: missing dependency \"$_dep_name\" (command failed: ${_dep_cmd[*]})" >&2
			usage >&2
			exit 1
		fi
	done

	# Validate required options
	for _req_name in "${!program_option_required[@]}"; do
		if [ "${program_option_passed["$_req_name"]:-}" != true ]; then
			echo "Error: option ${program_option_flag["$_req_name"]} is required" >&2
			usage >&2
			exit 1
		fi
	done

	# Validate option types
	for _opt_name in "${!program_option_type[@]}"; do
		local _value="${program_option["$_opt_name"]}"
		local _opt_flag="${program_option_flag["$_opt_name"]:---$_opt_name}"
		if [ -z "$_value" ]; then
			# A choice flag that was actually passed must carry one of its choices.
			# An option the caller never used stays unvalidated — there is no
			# concept of a required option.
			if [ "${program_option_passed["$_opt_name"]:-}" = true ] &&
				[ "${program_option_type["$_opt_name"]}" = choice ]; then
				local _missing_choices
				_missing_choices="${program_option_choices["$_opt_name"]// /, }"
				echo "Error: $_opt_flag requires one of: $_missing_choices" >&2
				usage >&2
				exit 1
			fi
			continue
		fi
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
				echo "Error: invalid value for $_opt_flag: \"$_value\". Valid choices: $_choices_display" >&2
				usage >&2
				exit 1
			fi
			;;
		integer)
			if [[ ! "$_value" =~ ^-?[0-9]+$ ]]; then
				echo "Error: $_opt_flag expects an integer, got \"$_value\"" >&2
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
				echo "Error: $_opt_flag must be a number between $_min and $_max, got \"$_value\"" >&2
				usage >&2
				exit 1
			fi
			;;
		esac
	done

	# Custom validators, after the built-in type checks so both apply
	local _val_name _val_value _val_flag _val_fn _val_out _val_alias
	for _val_name in "${!program_option_validator[@]}"; do
		_val_value="${program_option["$_val_name"]}"
		[ -z "$_val_value" ] && continue
		_val_flag="${program_option_flag["$_val_name"]:---$_val_name}"
		_val_fn="${program_option_validator["$_val_name"]}"
		if ! declare -F "$_val_fn" >/dev/null; then
			echo "Error: option_validator for $_val_flag names an undefined function \"$_val_fn\"" >&2
			exit 1
		fi
		if ! _val_out=$("$_val_fn" "$_val_value"); then
			echo "Error: invalid value for $_val_flag: \"$_val_value\"" >&2
			usage >&2
			exit 1
		fi
		program_option["$_val_name"]="$_val_out"
		for _val_alias in ${option_aliases["$_val_name"]}; do
			program_option["$_val_alias"]="$_val_out"
		done
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
