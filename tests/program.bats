#!/usr/bin/env bats

PROGRAM_SH="$BATS_TEST_DIRNAME/../bin/program.sh"
EXTRACT_SH="$BATS_TEST_DIRNAME/../lib/extract.sh"

make_lib_script() {
	local path="$BATS_TEST_TMPDIR/script_${BATS_TEST_NUMBER}.sh"
	printf '#!/usr/bin/env bash\nsource "%s"\n' "$EXTRACT_SH" >"$path"
	cat >>"$path"
	chmod +x "$path"
	echo "$path"
}

# Writes a helper script that sources program.sh then appends stdin body.
# Prints the path to the created script.
make_script() {
	local path="$BATS_TEST_TMPDIR/script_${BATS_TEST_NUMBER}.sh"
	printf '#!/usr/bin/env bash\nsource "%s"\n' "$PROGRAM_SH" >"$path"
	cat >>"$path"
	chmod +x "$path"
	echo "$path"
}

# ── name ──────────────────────────────────────

@test "name: appears in usage line" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage: mytool"* ]]
}

# ── description ───────────────────────────────

@test "description: appears in usage output" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "A tool that does something useful"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"A tool that does something useful"* ]]
}

# ── argument ──────────────────────────────────

@test "argument: name appears in usage line" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<path>" "Input path" "./"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"<path>"* ]]
}

@test "argument: shown in Arguments section with description" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<path>" "Input path" "./"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Arguments:"* ]]
	[[ "$output" == *"Input path"* ]]
}

@test "argument: default value stored in program array" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<path>" "Input path" "./*.txt"
echo "${program_args_default["<path>"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "./*.txt" ]
}

# ── option ────────────────────────────────────

@test "option/short flag: appears in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-f" "Force mode"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-f"* ]]
}

@test "option/long flag: appears in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--force"* ]]
}

@test "option/combined flags: appear in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-f, --force" "Force mode"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-f, --force"* ]]
}

@test "option/--no-flag: appears in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--no-cheese" "Omit cheese"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--no-cheese"* ]]
}

@test "option/default: shown as (default: X) in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items" "10"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"(default: 10)"* ]]
}

@test "option/no default: omits (default:) in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" != *"(default:"* ]]
}

@test "option/description: single-word appears in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Verbose"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Verbose"* ]]
}

@test "option/description: multi-word description is fully preserved" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Enable force mode"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Enable force mode"* ]]
}

@test "option/name: derived from long flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items" "10"
echo "${program_option["num"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "10" ]
}

@test "option/name: derived from short flag when no long flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-f" "Force mode"
echo "${program_option["f"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "option/aliases: passing long flag sets all aliases" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items" "10"
parse --num 5
echo "${program_option["num"]}"
echo "${program_option["n"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "5" ]
	[ "${lines[1]}" = "5" ]
}

@test "option/aliases: passing short flag sets all aliases" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items" "10"
parse -n 5
echo "${program_option["num"]}"
echo "${program_option["n"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "5" ]
	[ "${lines[1]}" = "5" ]
}

@test "option/aliases: default is available under all aliases" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items" "10"
echo "${program_option["num"]}"
echo "${program_option["n"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "10" ]
	[ "${lines[1]}" = "10" ]
}

@test "option/--no-flag: flag with --no- mid-word does not trigger auto-default" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--forno-a" "Some flag"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" != *"(default: true)"* ]]
}

@test "option/--no-flag: auto-default is true when no default given" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--no-cheese" "Omit cheese"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"(default: true)"* ]]
}

@test "option/--no-flag: key strips no- prefix" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--no-cheese" "Omit cheese"
parse
echo "${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "true" ]
}

@test "option/--no-flag: passing flag sets key to false" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--no-cheese" "Omit cheese"
parse --no-cheese
echo "${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "false" ]
}

# ── usage ─────────────────────────────────────

@test "usage: shows [options] when options are declared" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"[options]"* ]]
}

@test "usage: always shows [options] for built-in flags" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"[options]"* ]]
}

@test "usage: omits Arguments section when no argument declared" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" != *"Arguments:"* ]]
}

@test "usage: always shows Options section with built-in flags" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Options:"* ]]
	[[ "$output" == *"--help"* ]]
	[[ "$output" == *"--generate-completions"* ]]
}

# ── parse ─────────────────────────────────────

@test "parse: --help exits 0" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
}

@test "parse: -h exits 0" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse -h
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
}

@test "parse: --help prints usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

@test "parse: unknown flags fail cleanly rather than crashing" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --unknown-flag
echo "survived"
EOF
	)
	run bash -c "\"$script\" 2>&1"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'--unknown-flag' is not a mytool option"* ]]
	[[ "$output" != *"survived"* ]]
	[[ "$output" != *"unary operator expected"* ]]
	[[ "$output" != *"syntax error"* ]]
}

@test "parse: exits with error when mandatory argument is missing" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<port>" "Port number"
parse
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error:"* ]]
	[[ "$output" == *"<port>"* ]]
}

@test "parse: does not error when optional argument is missing" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<path>" "Input path" "./"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "parse: non-flag args are collected in program_args by index" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --force file1.txt file2.txt
echo "${program_args[0]}"
echo "${program_args[1]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "file1.txt" ]
	[ "${lines[1]}" = "file2.txt" ]
}

@test "parse: non-flag args accessible by name in program_arg" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<public-key> <message>" "Key and message"
parse mykey.pub "hello world"
echo "${program_arg["public-key"]}"
echo "${program_arg["message"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "mykey.pub" ]
	[ "${lines[1]}" = "hello world" ]
}

@test "parse: flag value is stored after parsing" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items" "10"
parse -n 5
echo "${program_option["num"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "5" ]
}

@test "parse: --flag=value sets the option" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
parse --to=720 a.mp4
echo "to=${program_option["to"]} args=${program_args[*]} count=$program_args_count"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=720 args=a.mp4 count=1" ]
}

@test "parse: --flag=value sets aliases too" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of items"
parse --num=5
echo "${program_option["n"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "5" ]
}

@test "parse: --flag=value splits on the first = only" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--set <pair>" "Key/value pair"
parse --set=a=b
echo "${program_option["set"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "a=b" ]
}

@test "option_type/choice: passed flag with no value errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse --to
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"--to requires one of: 480, 720"* ]]
}

@test "option_type/choice: passed flag with empty inline value errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse --to=
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"--to requires one of: 480, 720"* ]]
}

@test "option_type/choice: unpassed flag stays unvalidated" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse a.mp4
echo "to=[${program_option["to"]}] args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=[] args=a.mp4" ]
}

@test "option_type/choice: passed flag is tracked through aliases" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse -t
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"--to requires one of: 480, 720"* ]]
}

@test "parse: --flag=value is validated by option_type" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse --to=999
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'invalid value for --to: "999"'* ]]
}

@test "parse: boolean flags reject the =value form" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--remove-original, --rm" "Remove original"
parse --rm=x
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"option --rm does not take a value"* ]]
}

@test "parse: boolean flags keep the =value form as an argument when unknown options are allowed" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--remove-original, --rm" "Remove original"
allow_unknown_options
parse --rm=x
echo "rm=[${program_option["remove-original"]}] args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "rm=[] args=--rm=x" ]
}

@test "parse: handles arg values containing spaces without error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse "some arg with spaces"
echo "survived"
EOF
	)
	run bash -c "\"$script\" 2>&1"
	[[ "$output" != *"unary operator expected"* ]]
	[[ "$output" != *"syntax error"* ]]
	[[ "$output" == *"survived"* ]]
}

# ── alias resolution ──────────────────────────

@test "option_type: declared via a short alias annotates usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <resolution>" "Target resolution"
option_type "-t" choice "480" "720"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"(choices: 480, 720)"* ]]
}

@test "option_type: declared via a short alias reports the canonical flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <resolution>" "Target resolution"
option_type "-t" choice "480" "720"
parse -t 999
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'invalid value for --to: "999"'* ]]
	[[ "$output" != *"--t:"* ]]
}

@test "option_type: declared via a short alias feeds completions" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <resolution>" "Target resolution"
option_type "-t" choice "480" "720"
parse --generate-completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *'compgen -W "480 720"'* ]]
}

@test "option_type: --no-* flag resolves to the canonical key" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--no-cheese <kind>" "Cheese"
option_type "--no-cheese" choice "brie" "gouda"
parse --no-cheese=nope
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'invalid value for --no-cheese: "nope"'* ]]
}

@test "option_type: short-only option reports its own flag, not --f" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-f <num>" "Number"
option_type "-f" integer
parse -f abc
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'-f expects an integer, got "abc"'* ]]
	[[ "$output" != *"--f "* ]]
}

# ── required_option ───────────────────────────

@test "required_option: registers the option like option() does" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "-t, --to <resolution>" "Target resolution"
parse -t 720
echo "to=${program_option["to"]} t=${program_option["t"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=720 t=720" ]
}

@test "required_option: errors when the flag is not passed" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
parse a.mp4
echo "unreachable"
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"option --to is required"* ]]
	[[ "$output" != *"unreachable"* ]]
}

@test "required_option: passes when the flag is given" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
parse --to 720 a.mp4
echo "to=${program_option["to"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=720" ]
}

@test "required_option: satisfied by the --flag=value form" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
parse --to=720
echo "to=${program_option["to"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=720" ]
}

@test "required_option: satisfied when passed by an alias" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "-t, --to <resolution>" "Target resolution"
parse -t 720
echo "to=${program_option["to"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=720" ]
}

@test "required_option: reports the canonical flag for an aliased option" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "-t, --to <resolution>" "Target resolution"
parse
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"option --to is required"* ]]
}

@test "required_option: works with a boolean flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--force" "Force mode"
parse --force
echo "force=${program_option["force"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "force=true" ]
}

@test "required_option: composes with option_type — missing flag reports required" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse a.mp4
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"option --to is required"* ]]
}

@test "required_option: composes with option_type — bad value reports the type error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720"
parse --to=999
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'invalid value for --to: "999"'* ]]
}

@test "required_option: --help still exits 0 when a required flag is missing" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage: mytool"* ]]
}

@test "required_option: marks the option as (required) in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Target resolution (required)"* ]]
}

@test "required_option: rejects a default value argument" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target resolution" "720"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"does not take a default value"* ]]
}

@test "required_option: rejects a --no-* flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--no-cheese" "Omit cheese"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"defaults to true"* ]]
}

# ── unknown options ───────────────────────────

@test "parse: an unknown long flag is an error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<file>" "File"
option "--to <r>" "To"
parse --typo x.txt
echo "unreachable"
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'--typo' is not a mytool option"* ]]
	[[ "$output" != *"unreachable"* ]]
}

@test "parse: an unknown short flag is an error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "To"
parse -x
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'-x' is not a mytool option"* ]]
}

@test "parse: a lone dash stays a positional argument" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse -
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=-" ]
}

@test "parse: negative numbers stay positional arguments" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse -5 -3.14
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=-5 -3.14" ]
}

@test "allow_unknown_options: unknown flags become positional arguments" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<command>" "Command"
allow_unknown_options
parse ls -la
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=ls -la" ]
}

@test "allow_unknown_options: declared flags still parse normally" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "To"
allow_unknown_options
parse --to 720 --other x
echo "to=${program_option["to"]} args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=720 args=--other x" ]
}

# ── version ───────────────────────────────────

@test "version: --version prints the declared string" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
version "1.4.2"
parse --version
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "1.4.2" ]
}

@test "version: falls back to the script mtime as vYYYY.mm.DD.HHmmss" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --version
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]{6}$ ]]
}

@test "version: mtime fallback matches the file's own timestamp" {
	local script expected
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --version
EOF
	)
	expected=$(date -r "$(stat -f %m "$script" 2>/dev/null || stat -c %Y "$script")" +"v%Y.%m.%d.%H%M%S" 2>/dev/null ||
		date -d "@$(stat -c %Y "$script")" +"v%Y.%m.%d.%H%M%S")
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "$expected" ]
}

@test "version: --version is listed in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--version"* ]]
	[[ "$output" == *"Show the version"* ]]
}

@test "version: declaring --version as an option is rejected" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--version <v>" "Version"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the option name "version"'* ]]
}

@test "version: declaring -h as an option is rejected" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-h, --host <h>" "Host"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the flag "-h"'* ]]
}

# ── option_env ────────────────────────────────

@test "option_env: fills the option from the environment" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-p, --port <port>" "Port" "8080"
option_env "--port" "MYTOOL_PORT"
parse
echo "port=${program_option["port"]}"
EOF
	)
	MYTOOL_PORT=9000 run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port=9000" ]
}

@test "option_env: the command line beats the environment" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-p, --port <port>" "Port" "8080"
option_env "--port" "MYTOOL_PORT"
parse --port=1234
echo "port=${program_option["port"]}"
EOF
	)
	MYTOOL_PORT=9000 run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port=1234" ]
}

@test "option_env: the default applies when the variable is unset" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-p, --port <port>" "Port" "8080"
option_env "--port" "MYTOOL_PORT"
parse
echo "port=${program_option["port"]}"
EOF
	)
	run env -u MYTOOL_PORT "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port=8080" ]
}

@test "option_env: an empty variable does not override the default" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-p, --port <port>" "Port" "8080"
option_env "--port" "MYTOOL_PORT"
parse
echo "port=${program_option["port"]}"
EOF
	)
	MYTOOL_PORT='' run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port=8080" ]
}

@test "option_env: the value reaches every alias" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-p, --port <port>" "Port"
option_env "-p" "MYTOOL_PORT"
parse
echo "port=${program_option["port"]} p=${program_option["p"]}"
EOF
	)
	MYTOOL_PORT=9000 run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port=9000 p=9000" ]
}

@test "option_env: an environment value satisfies required_option" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--token <t>" "API token"
option_env "--token" "MYTOOL_TOKEN"
parse
echo "token=${program_option["token"]}"
EOF
	)
	MYTOOL_TOKEN=secret run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "token=secret" ]
}

@test "option_env: an environment value is checked by option_type" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <port>" "Port"
option_env "--port" "MYTOOL_PORT"
option_type "--port" integer
parse
EOF
	)
	MYTOOL_PORT=abc run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'--port expects an integer, got "abc"'* ]]
}

@test "option_env: the variable is shown in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <port>" "Port"
option_env "--port" "MYTOOL_PORT"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"(env: MYTOOL_PORT)"* ]]
}

# ── redeclaration ─────────────────────────────

@test "option: redeclaring the same option name errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "First"
option "--to <resolution>" "Second"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the option name "to"'* ]]
}

@test "option: redeclaring a flag owned by another option errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <resolution>" "Target"
option "-t, --time <seconds>" "Time"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the flag "-t"'* ]]
}

@test "option: --no-* and its plain name collide" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--no-cheese" "Omit cheese"
option "--cheese <kind>" "Cheese"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the option name "cheese"'* ]]
}

@test "option: distinct options do not collide" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <resolution>" "Target"
option "-s, --size <n>" "Size"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
}

@test "required_option: redeclaring an existing option errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target"
required_option "--to <resolution>" "Target"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'required_option "--to <resolution>" redeclares'* ]]
}

@test "option: redeclaring a required_option errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target"
option "--to <resolution>" "Target"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'option "--to <resolution>" redeclares'* ]]
}

@test "required_option: declared twice errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
required_option "--to <resolution>" "Target"
required_option "--to <resolution>" "Target"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'required_option "--to <resolution>" redeclares'* ]]
}

# ── option_validator ──────────────────────────

@test "option_validator: stdout replaces the stored value" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--env <name>" "Environment"
to_upper() { echo "${1^^}"; }
option_validator "--env" to_upper
parse --env staging
echo "env=${program_option["env"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "env=STAGING" ]
}

@test "option_validator: the coerced value reaches every alias" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-e, --env <name>" "Environment"
to_upper() { echo "${1^^}"; }
option_validator "--env" to_upper
parse -e staging
echo "env=${program_option["env"]} e=${program_option["e"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "env=STAGING e=STAGING" ]
}

@test "option_validator: a non-zero return rejects the value" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <p>" "Port"
even_only() { (( $1 % 2 == 0 )) || return 1; echo "$1"; }
option_validator "--port" even_only
parse --port 8081
echo "unreachable"
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'invalid value for --port: "8081"'* ]]
	[[ "$output" != *"unreachable"* ]]
}

@test "option_validator: the function's own message is kept" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <p>" "Port"
even_only() { echo "port must be even" >&2; return 1; }
option_validator "--port" even_only
parse --port 8081
EOF
	)
	run bash -c "\"$script\" 2>&1"
	[ "$status" -eq 1 ]
	[[ "$output" == *"port must be even"* ]]
	[[ "$output" == *'invalid value for --port'* ]]
}

@test "option_validator: option_type runs first" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <p>" "Port"
option_type "--port" integer
never() { echo "validator ran" >&2; return 1; }
option_validator "--port" never
parse --port abc
EOF
	)
	run bash -c "\"$script\" 2>&1"
	[ "$status" -eq 1 ]
	[[ "$output" == *"expects an integer"* ]]
	[[ "$output" != *"validator ran"* ]]
}

@test "option_validator: an unset option is not validated" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <p>" "Port"
never() { return 1; }
option_validator "--port" never
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "option_validator: a default value is validated" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--env <name>" "Environment" "staging"
to_upper() { echo "${1^^}"; }
option_validator "--env" to_upper
parse
echo "env=${program_option["env"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "env=STAGING" ]
}

@test "option_validator: an undefined function is reported" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--x <v>" "X"
option_validator "--x" nope
parse --x 1
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'names an undefined function "nope"'* ]]
}

@test "option_validator: declaring one twice errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--x <v>" "X"
keep() { echo "$1"; }
option_validator "--x" keep
option_validator "--x" keep
parse --x 1
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"redeclares the validator"* ]]
}

# ── end of options ────────────────────────────

@test "parse: -- stops flags from being interpreted" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
parse -- --all x.txt
echo "all=[${program_option["all"]}] args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=[] args=--all x.txt" ]
}

@test "parse: flags before -- still parse" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-n, --num <n>" "Num"
parse --all -n 3 -- ls -la
echo "all=${program_option["all"]} num=${program_option["num"]} args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true num=3 args=ls -la" ]
}

@test "parse: -- is consumed, not kept as an argument" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse -- a b
echo "args=${program_args[*]} count=$program_args_count"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=a b count=2" ]
}

@test "parse: a dash-leading filename survives --" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<file>" "File"
parse -- -report.txt
echo "file=${program_arg["file"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "file=-report.txt" ]
}

@test "parse: an unknown option after -- is not an error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
parse -- --typo
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=--typo" ]
}

@test "parse: a second -- is an ordinary argument" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse -- a -- b
echo "args=${program_args[*]} count=$program_args_count"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=a -- b count=3" ]
}

@test "parse: short flag groups are not expanded after --" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-b, --bold" "Bold"
parse -- -ab
echo "all=[${program_option["all"]}] args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=[] args=-ab" ]
}

@test "parse: -- alone leaves no arguments" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse --
echo "count=$program_args_count"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "count=0" ]
}

@test "parse: --help after -- is data, not a request for help" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
parse -- --help
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=--help" ]
}

@test "parse: an argument after -- satisfies a mandatory argument" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<file>" "File"
parse -- -x
echo "file=${program_arg["file"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "file=-x" ]
}

# ── combined short flags ──────────────────────

@test "parse: -ab sets both boolean flags" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-b, --bold" "Bold"
parse -ab
echo "all=${program_option["all"]} bold=${program_option["bold"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true bold=true" ]
}

@test "parse: -n5 attaches the value to a short flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <n>" "Num"
parse -n5
echo "num=${program_option["num"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "num=5" ]
}

@test "parse: a group ending in a value flag takes the rest of the token" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-b, --bold" "Bold"
option "-n, --num <n>" "Num"
parse -abn5
echo "all=${program_option["all"]} bold=${program_option["bold"]} num=${program_option["num"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true bold=true num=5" ]
}

@test "parse: a group ending in a value flag takes the next argument" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-n, --num <n>" "Num"
parse -an 5
echo "all=${program_option["all"]} num=${program_option["num"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true num=5" ]
}

@test "parse: an optional-value flag in a group takes the rest of the token" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-c, --cheese [type]" "Cheese"
parse -acbrie
echo "all=${program_option["all"]} cheese=${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true cheese=brie" ]
}

@test "parse: an optional-value flag ending a group stores true" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-c, --cheese [type]" "Cheese"
parse -ac
echo "all=${program_option["all"]} cheese=${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true cheese=true" ]
}

@test "parse: an undeclared flag inside a group is named precisely" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
parse -ax
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'-x' is not a mytool option"* ]]
}

@test "parse: a group whose first flag is undeclared is left whole" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
parse -xa
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'-xa' is not a mytool option"* ]]
}

@test "parse: a declared multi-character short flag is not expanded" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-ab <x>" "AB"
parse -ab 7
echo "a=${program_option["a"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "a=7" ]
}

@test "parse: forwarded flags are untouched when no short flag is declared" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
argument "<command>" "Command"
allow_unknown_options
parse ls -la
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=ls -la" ]
}

@test "parse: negative numbers are not expanded as flag groups" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-a, --all" "All"
parse -50 -3.14
echo "args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "args=-50 -3.14" ]
}

# ── did you mean ──────────────────────────────

@test "parse: an unknown option suggests the nearest declared flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
parse --tp 720
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"mytool: '--tp' is not a mytool option. See 'mytool --help'."* ]]
	[[ "$output" == *"The most similar option is"* ]]
	[[ "$output" == *$'\t--to <r>' ]]
	[[ "$output" != *"Usage:"* ]]
}

@test "parse: the suggestion works on the inline form" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
parse --tp=720
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'--tp=720' is not a mytool option"* ]]
	[[ "$output" == *$'\t--to <r>' ]]
}

@test "parse: built-in flags are suggested too" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
parse --hepl
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *$'\t--help' ]]
}

@test "parse: the suggestion shows an optional-value placeholder" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--cheese [type]" "Cheese"
parse --chese
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *$'\t--cheese [type]' ]]
}

@test "parse: a boolean suggestion has no placeholder" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--verbose" "Verbose"
parse --verbse
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *$'\t--verbose' ]]
}

@test "parse: equally close flags are all listed, in the plural" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--remove" "Remove"
option "--remote <url>" "Remote"
parse --remoe
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"The most similar options are"* ]]
	[[ "$output" == *$'\t--remove\n'* ]]
	[[ "$output" == *$'\t--remote <url>' ]]
}

@test "parse: nothing is suggested when no flag is close" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
parse --zzzzzzz
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'--zzzzzzz' is not a mytool option"* ]]
	[[ "$output" != *"The most similar"* ]]
}

@test "parse: short tokens are too ambiguous to suggest for" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <r>" "Target"
parse -x
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"'-x' is not a mytool option"* ]]
	[[ "$output" != *"The most similar"* ]]
}

# ── optional option values ────────────────────

@test "option: [value] with no value after it stores true" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--cheese [type]" "Add cheese"
parse --cheese
echo "cheese=${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "cheese=true" ]
}

@test "option: [value] takes the next token when it is data" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--cheese [type]" "Add cheese"
parse --cheese brie
echo "cheese=${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "cheese=brie" ]
}

@test "option: [value] does not swallow a following flag" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--cheese [type]" "Add cheese"
option "--to <r>" "Target"
parse --cheese --to 720
echo "cheese=${program_option["cheese"]} to=${program_option["to"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "cheese=true to=720" ]
}

@test "option: [value] accepts the inline form" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--cheese [type]" "Add cheese"
parse --cheese=gouda
echo "cheese=${program_option["cheese"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "cheese=gouda" ]
}

@test "option: [value] at the end of the arguments stores true" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
option "--cheese [type]" "Add cheese"
parse --to 720 --cheese
echo "cheese=${program_option["cheese"]} to=${program_option["to"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "cheese=true to=720" ]
}

@test "option: [value] takes a negative number as data" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--offset [n]" "Offset"
parse --offset -5
echo "offset=${program_option["offset"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "offset=-5" ]
}

@test "option: [value] is value-accepting for completions" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--cheese [type]" "Add cheese"
option_type "--cheese" choice "brie" "gouda"
parse --generate-completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *'compgen -W "brie gouda"'* ]]
}

# ── option_env redeclaration ──────────────────

@test "option_env: declaring a variable twice for one option errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--port <p>" "Port"
option_env "--port" "PORT"
option_env "--port" "OTHER"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the variable of "--port"'* ]]
	[[ "$output" == *'already declared as "PORT"'* ]]
}

@test "option_env: the second declaration is caught through an alias" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-p, --port <p>" "Port"
option_env "--port" "PORT"
option_env "-p" "OTHER"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the variable of "--port"'* ]]
}

@test "option_env: distinct options each get a variable" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--host <h>" "Host"
option "--port <p>" "Port"
option_env "--host" "MYTOOL_HOST"
option_env "--port" "MYTOOL_PORT"
parse
echo "host=${program_option["host"]} port=${program_option["port"]}"
EOF
	)
	MYTOOL_HOST=example MYTOOL_PORT=9000 run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "host=example port=9000" ]
}

# ── depends_of redeclaration ──────────────────

@test "depends_of: a command repeated in one call errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "echo, echo"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the dependency "echo"'* ]]
}

@test "depends_of: a command repeated across calls errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "echo, true"
depends_of "echo --version"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the dependency "echo"'* ]]
}

@test "depends_of: the bare and full forms of one command collide" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "echo"
depends_of "echo -n"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the dependency "echo"'* ]]
	[[ "$output" == *'already declared by "echo"'* ]]
}

@test "depends_of: distinct commands still accumulate" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "echo, true"
depends_of "printf -v x y"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

# ── option_type redeclaration ─────────────────

@test "option_type: declaring a type twice for one option errors" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
option_type "--to" choice "480" "720"
option_type "--to" integer
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the type of "--to"'* ]]
	[[ "$output" == *'already declared as "choice"'* ]]
}

@test "option_type: the second declaration is caught through an alias" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-t, --to <r>" "Target"
option_type "--to" integer
option_type "-t" choice "480"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'redeclares the type of "--to"'* ]]
}

@test "option_type: distinct options each get a type" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "Target"
option "--num <n>" "Num"
option_type "--to" choice "480"
option_type "--num" integer
parse --to 480 --num 3
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

# ── shell options ─────────────────────────────

@test "parse: a positional argument survives set -e" {
	local script
	script=$(
		make_script <<'EOF'
set -e
name "mytool"
description "does stuff"
argument "<file>" "File"
parse a.txt
echo "file=${program_arg["file"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "file=a.txt" ]
}

@test "parse: a full declaration set survives set -euo pipefail" {
	local script
	script=$(
		make_script <<'EOF'
set -euo pipefail
name "mytool"
description "does stuff"
version "1.0"
argument "<file>" "File" "."
option "-n, --num <x>" "Num"
option "--cheese [type]" "Cheese"
option "-p, --port <p>" "Port" "8080"
option_type "--num" integer
option_env "--port" "MYTOOL_PORT"
required_option "--to <r>" "Target"
option_type "--to" choice "480" "720"
depends_of "echo"
parse --to 480 -n 3 a.txt
echo "to=${program_option["to"]} num=${program_option["num"]} port=${program_option["port"]} args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "to=480 num=3 port=8080 args=a.txt" ]
}

@test "parse: error paths still report under set -euo pipefail" {
	local script
	script=$(
		make_script <<'EOF'
set -euo pipefail
name "mytool"
description "does stuff"
option "--to <r>" "Target"
option_type "--to" choice "480" "720"
parse --to 999
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'invalid value for --to: "999"'* ]]
}

@test "parse: an unknown option reports under set -euo pipefail" {
	local script
	script=$(
		make_script <<'EOF'
set -euo pipefail
name "mytool"
description "does stuff"
option "--to <r>" "Target"
parse --tp
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"is not a mytool option"* ]]
	[[ "$output" == *"--to <r>"* ]]
}

@test "parse: -- and combined flags survive set -euo pipefail" {
	local script
	script=$(
		make_script <<'EOF'
set -euo pipefail
name "mytool"
description "does stuff"
option "-a, --all" "All"
option "-n, --num <x>" "Num"
parse -an3 -- -weird.txt
echo "all=${program_option["all"]} num=${program_option["num"]} args=${program_args[*]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "all=true num=3 args=-weird.txt" ]
}

@test "parse: a bare script survives set -euo pipefail" {
	local script
	script=$(
		make_script <<'EOF'
set -euo pipefail
name "bare"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "parse: a value flag with nothing after it survives set -euo pipefail" {
	local script
	script=$(
		make_script <<'EOF'
set -euo pipefail
name "mytool"
description "does stuff"
option "-n, --num <x>" "Num"
parse --num
echo "num=[${program_option["num"]}]"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "num=[]" ]
}

@test "option: declaring an option survives set -e" {
	local script
	script=$(
		make_script <<'EOF'
set -e
name "mytool"
description "does stuff"
option "-n, --num <x>" "Num"
parse -n 3
echo "reached the end"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "reached the end" ]
}

@test "required_option: declaring one survives set -e" {
	local script
	script=$(
		make_script <<'EOF'
set -e
name "mytool"
description "does stuff"
required_option "-n, --num <x>" "Num"
parse -n 3
echo "reached the end"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "reached the end" ]
}

@test "option_type: resolving a flag survives set -e" {
	local script
	script=$(
		make_script <<'EOF'
set -e
name "mytool"
description "does stuff"
option "-n, --num <x>" "Num"
option_type "--num" integer
parse -n 3
echo "reached the end"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "reached the end" ]
}

# ── defaults ──────────────────────────────────

@test "option: a default keeps its surrounding whitespace" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--delimiter <d>" "Separator" ", "
parse
printf 'delimiter=[%s]\n' "${program_option["delimiter"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "delimiter=[, ]" ]
}

@test "option: a description is still trimmed" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <r>" "   Target resolution   "
parse --help
EOF
	)
	local expected
	expected=$(printf "  %-20s %s" "--to <r>" "Target resolution")
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"$expected"* ]]
}

@test "option: a whitespace-only default is still a default" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--pad <p>" "Padding" " "
parse
printf 'pad=[%s]\n' "${program_option["pad"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "pad=[ ]" ]
}

# ── option_type ───────────────────────────────

@test "option_type/choice: valid choices shown in usage" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"choices: 480, 720, 1080"* ]]
}

@test "option_type/choice: valid value passes" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
parse --to 720
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/choice: invalid value exits with error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
parse --to 4k
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error:"* ]]
}

@test "option_type/choice: error message contains the invalid value" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
parse --to 4k
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"4k"* ]]
}

@test "option_type/choice: error message contains valid choices" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
parse --to 4k
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"480"* ]]
	[[ "$output" == *"720"* ]]
	[[ "$output" == *"1080"* ]]
}

@test "option_type/choice: skips validation when option not provided" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/integer: valid integer passes" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--num <amount>" "Number of results"
option_type "--num" integer
parse --num 42
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/integer: non-integer value exits with error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--num <amount>" "Number of results"
option_type "--num" integer
parse --num abc
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error:"* ]]
}

@test "option_type/integer: negative integer is valid" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--num <amount>" "Number of results"
option_type "--num" integer
parse --num -5
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/integer: skips validation when option not provided" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--num <amount>" "Number of results"
option_type "--num" integer
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/path: value is stored without validation" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--key <path>" "Path to key"
option_type "--key" path
parse --key /nonexistent/path
echo "${program_option["key"]}"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "/nonexistent/path" ]
}

@test "option_type/path: skips validation when option not provided" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--key <path>" "Path to key"
option_type "--key" path
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/between: value within range passes" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
parse --scale 0.5
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/between: value below minimum exits with error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
parse --scale -0.1
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error:"* ]]
}

@test "option_type/between: value above maximum exits with error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
parse --scale 1.1
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error:"* ]]
}

@test "option_type/between: non-numeric value exits with error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
parse --scale abc
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error:"* ]]
}

@test "option_type/between: boundary values pass" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
parse --scale 0.0
echo "min ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"min ok"* ]]
}

@test "option_type/between: float value within range passes" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 100.0
parse --scale 3.14
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "option_type/between: skips validation when option not provided" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

# ── depends_of ─────────────────────────────────

@test "depends_of/bare name: existing command passes" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "true"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "depends_of/bare name: missing command fails with error" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "this-command-does-not-exist-xyz"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'Error: missing dependency "this-command-does-not-exist-xyz"'* ]]
}

@test "depends_of/comma list: names the specific missing dependency" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "true, this-command-does-not-exist-xyz"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'Error: missing dependency "this-command-does-not-exist-xyz"'* ]]
}

@test "depends_of/full command: entry with a space runs verbatim instead of appending --version" {
	local script
	script=$(
		make_script <<'EOF'
fake_bin="$BATS_TEST_TMPDIR/fakecmd"
cat >"$fake_bin" <<'INNER'
#!/usr/bin/env bash
[ "$1" = "-v" ] && exit 0
exit 1
INNER
chmod +x "$fake_bin"
export PATH="$BATS_TEST_TMPDIR:$PATH"

name "mytool"
description "does stuff"
depends_of "fakecmd -v"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "depends_of/multiple calls: entries accumulate across calls" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "true"
depends_of "this-command-does-not-exist-xyz"
parse
echo "ok"
EOF
	)
	run "$script"
	[ "$status" -eq 1 ]
	[[ "$output" == *'Error: missing dependency "this-command-does-not-exist-xyz"'* ]]
}

@test "depends_of/--help: bypasses dependency checks" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
depends_of "this-command-does-not-exist-xyz"
parse --help
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage: mytool"* ]]
}

# ── generate_completions ──────────────────────

@test "generate_completions: function name derived from program name" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"_mytool_complete()"* ]]
}

@test "generate_completions: dashes in name converted to underscores" {
	local script
	script=$(
		make_script <<'EOF'
name "my-tool"
description "does stuff"
option "--force" "Force mode"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"_my_tool_complete"* ]]
}

@test "generate_completions: all flag tokens appear in opts" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of results"
option "--force" "Force mode"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-n"* ]]
	[[ "$output" == *"--num"* ]]
	[[ "$output" == *"--force"* ]]
}

@test "generate_completions: choice type uses compgen -W with values" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *'compgen -W "480 720 1080"'* ]]
}

@test "generate_completions: integer type returns empty COMPREPLY" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--num <amount>" "Number of results"
option_type "--num" integer
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--num)"* ]]
	[[ "$output" == *"COMPREPLY=(); return 0"* ]]
}

@test "generate_completions: path type uses compgen -f" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--key <path>" "Path to key"
option_type "--key" path
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--key)"* ]]
	[[ "$output" == *"compgen -f"* ]]
}

@test "generate_completions: between type returns empty COMPREPLY" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--scale)"* ]]
	[[ "$output" == *"COMPREPLY=(); return 0"* ]]
}

@test "generate_completions: value flag without type returns empty COMPREPLY" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--output <file>" "Output file"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"--output)"* ]]
	[[ "$output" == *"COMPREPLY=(); return 0"* ]]
}

@test "generate_completions: multi-flag value option uses pipe in case pattern" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "-n, --num <amount>" "Number of results"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-n|--num)"* ]]
}

@test "generate_completions: boolean flag has no case branch" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" != *"--force)"* ]]
}

@test "generate_completions: registers with complete -F" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
generate_completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"complete -F _mytool_complete mytool"* ]]
}

@test "parse: --generate-completions exits 0" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --generate-completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
}

@test "parse: --generate-completions outputs completion function" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--force" "Force mode"
parse --generate-completions
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"complete -F"* ]]
}

# ── program::trim ────────────────────────────────────

@test "program::trim: removes leading whitespace" {
	local script
	script=$(
		make_script <<'EOF'
result=$(program::trim "   hello")
echo "$result"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "hello" ]
}

@test "program::trim: removes trailing whitespace" {
	local script
	script=$(
		make_script <<'EOF'
result=$(program::trim "hello   ")
echo "$result"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "hello" ]
}

@test "program::trim: removes leading and trailing whitespace" {
	local script
	script=$(
		make_script <<'EOF'
result=$(program::trim "   hello world   ")
echo "$result"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "program::trim: does not leak var into caller scope" {
	local script
	script=$(
		make_script <<'EOF'
var="original"
program::trim "   trimmed   " > /dev/null
echo "$var"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "original" ]
}

# ── program::extract_arg_names ───────────────────────

@test "program::extract_arg_names: single token" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_arg_names "<port>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port" ]
}

@test "program::extract_arg_names: multiple tokens" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_arg_names "<public-key> <file>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "public-key" ]
	[ "${lines[1]}" = "file" ]
}

@test "program::extract_arg_names: no tokens returns empty" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_arg_names "no angle brackets"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

# ── program::extract_option_name ─────────────────────

@test "program::extract_option_name: long flag" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_option_name "--force"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "force" ]
}

@test "program::extract_option_name: long flag with value" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_option_name "--num <amount>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "num" ]
}

@test "program::extract_option_name: short flag only" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_option_name "-f"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "f" ]
}

@test "program::extract_option_name: combined flags uses long" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_option_name "-n, --num <amount>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "num" ]
}

# ── program::extract_flags ───────────────────────────

@test "program::extract_flags: short flag only" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_flags "-f"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "-f" ]
}

@test "program::extract_flags: long flag only" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_flags "--force"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "--force" ]
}

@test "program::extract_flags: combined flags" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
program::extract_flags "-n, --num <amount>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "-n" ]
	[ "${lines[1]}" = "--num" ]
}
