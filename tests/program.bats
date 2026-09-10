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

@test "parse: unknown flags do not crash" {
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
	run "$script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"survived"* ]]
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

@test "parse: boolean flags ignore the =value form" {
	local script
	script=$(
		make_script <<'EOF'
name "mytool"
description "does stuff"
option "--remove-original, --rm" "Remove original"
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

# ── __trim ────────────────────────────────────

@test "__trim: removes leading whitespace" {
	local script
	script=$(
		make_script <<'EOF'
result=$(__trim "   hello")
echo "$result"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "hello" ]
}

@test "__trim: removes trailing whitespace" {
	local script
	script=$(
		make_script <<'EOF'
result=$(__trim "hello   ")
echo "$result"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "hello" ]
}

@test "__trim: removes leading and trailing whitespace" {
	local script
	script=$(
		make_script <<'EOF'
result=$(__trim "   hello world   ")
echo "$result"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "__trim: does not leak var into caller scope" {
	local script
	script=$(
		make_script <<'EOF'
var="original"
__trim "   trimmed   " > /dev/null
echo "$var"
EOF
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "original" ]
}

# ── __extract_arg_names ───────────────────────

@test "__extract_arg_names: single token" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_arg_names "<port>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "port" ]
}

@test "__extract_arg_names: multiple tokens" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_arg_names "<public-key> <file>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "public-key" ]
	[ "${lines[1]}" = "file" ]
}

@test "__extract_arg_names: no tokens returns empty" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_arg_names "no angle brackets"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

# ── __extract_option_name ─────────────────────

@test "__extract_option_name: long flag" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_option_name "--force"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "force" ]
}

@test "__extract_option_name: long flag with value" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_option_name "--num <amount>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "num" ]
}

@test "__extract_option_name: short flag only" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_option_name "-f"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "f" ]
}

@test "__extract_option_name: combined flags uses long" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_option_name "-n, --num <amount>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "num" ]
}

# ── __extract_flags ───────────────────────────

@test "__extract_flags: short flag only" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_flags "-f"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "-f" ]
}

@test "__extract_flags: long flag only" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_flags "--force"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "$output" = "--force" ]
}

@test "__extract_flags: combined flags" {
	local script
	script=$(
		make_lib_script <<'SCRIPT'
__extract_flags "-n, --num <amount>"
SCRIPT
	)
	run "$script"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "-n" ]
	[ "${lines[1]}" = "--num" ]
}
