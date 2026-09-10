# program.sh

A declarative framework for writing bash CLIs. Source it at the top of a script to get structured argument/option parsing, auto-generated help, and tab completion.

## Quick start

```bash
#!/usr/bin/env bash
source "$HOME/.local/lib/program.sh"

name "biggest-files"
description "List the biggest files"
argument "<files>" "The path to the files" "./*"
option "-n, --num <amount>" "Amount of results to be displayed" "10"
option "--no-cheese" "Omit cheese"
parse "$@"

# Access options
echo "${program_option["num"]}"         # "10" or parsed value
echo "${program_option["cheese"]}"       # "true" or "false"

# Access positional args
echo "${program_args[0]}"              # first positional arg (indexed)
echo "${program_arg["files"]}"         # first positional arg (by name)
```

Running `biggest-files --help` produces:

```
Usage: biggest-files [options] <files>

List the biggest files

Arguments:
  <files>              The path to the files

Options:
  -n, --num <amount>   Amount of results to be displayed (default: 10)
  --no-cheese           Omit cheese (default: true)
```

## Installation

**curl** (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/ggviana/program.sh/main/install.sh | bash
```

**Custom location**:

```bash
curl -fsSL https://raw.githubusercontent.com/ggviana/program.sh/main/install.sh | INSTALL_DIR=/usr/local/lib bash
```

**Uninstall**:

```bash
curl -fsSL https://raw.githubusercontent.com/ggviana/program.sh/main/uninstall.sh | bash
```

Then source it at the top of your script:

```bash
source "$HOME/.local/lib/program.sh"
```

## API reference

### `name "<name>"`

Sets the program name shown in the usage line.

| Parameter | Description |
|-----------|:------------|
| `name`    | The program name |

Sets `program_name`.

```bash
name "port-kill"
# program_name → "port-kill"
# Usage line:  Usage: port-kill ...
```

---

### `description "<text>"`

Sets the one-line description shown below the usage line.

| Parameter | Description |
|-----------|-------------|
| `text`    | The description text |

Sets `program_description`.

```bash
description "Kills the process listening on the given port"
# program_description → "Kills the process listening on the given port"
```

---

### `argument "<name>" "<description>" "<default>"`

Declares a single positional argument. Only one positional argument declaration is supported per script.

| Parameter     | Description |
|---------------|-------------|
| `name`        | Argument name(s) shown in usage, using `<token>` syntax (e.g. `<port>` or `<public-key> <file>`) |
| `description` | Description shown in the Arguments section |
| `default`     | Default value (optional). If omitted, the argument is **mandatory** — `parse` will print an error and exit 1 when no positional arg is provided |

Named tokens in `name` are extracted and mapped to `program_arg` after `parse` runs.

```bash
# Single mandatory argument
argument "<port>" "Port number to kill"
parse "$@"
# program_arg["port"] → "3000"  (if called as: script 3000)

# Multiple positional values in one declaration
argument "<public-key> <file>" "Key and file to encrypt"
parse "$@"
# program_arg["public-key"] → "key.pub"
# program_arg["file"]       → "secret.txt"

# Optional argument with default
argument "<path>" "Directory to scan" "./"
parse "$@"
# program_arg["path"] → "./" when no arg is given
```

---

### `option "<flags>" "<description>" "<default>"`

Declares a named option. Multiple options can be declared. Use `required_option` in place of `option` when the flag must be provided.

| Parameter     | Description |
|---------------|-------------|
| `flags`       | One or more flag strings (see [Flag format](#flag-format)) |
| `description` | Description shown in the Options section |
| `default`     | Default value (optional) |

The option name is derived automatically from the flags string: the first long flag has its `--` stripped (`--num` → `num`). For `--no-*` flags the `no-` prefix is also stripped (`--no-cheese` → `cheese`). If only a short flag is given, the `-` is stripped (`-f` → `f`). The derived name is the key used in `program_option`.

**`--no-*` convention:** If the flags string contains a `--no-*` flag, the `no-` prefix is stripped from the key and the default is set to `true`. Passing the flag sets the key to `false`.

```bash
# Value-accepting option with short and long forms
option "-n, --num <amount>" "Number of results" "10"
# program_option["num"] → "10" by default
# script -n 5  →  program_option["num"] → "5"

# Boolean flag
option "--force" "Skip confirmation"
# program_option["force"] → "" by default
# script --force  →  program_option["force"] → "true"

# Negation flag — strips no- prefix, defaults to true, flag sets to false
option "--no-cheese" "Omit cheese"
# program_option["cheese"] → "true" by default
# script --no-cheese  →  program_option["cheese"] → "false"

# Short flag only
option "-v" "Verbose output"
# program_option["v"] → "" by default
```

---

### `option_type "<flag>" <type> [<args>...]`

Declares the type of value an option accepts. Must be called after the corresponding `option` declaration and before `parse`. Validation runs inside `parse` and exits 1 with a message on failure. Validation is skipped when the option value is empty and the flag was not passed — there is no concept of a required option. A `choice` flag that *is* passed must carry one of its choices: `--to` with nothing after it, or `--to=`, exits 1.

| Parameter | Description |
|-----------|-------------|
| `flag`    | The flag to constrain (e.g. `--to`). Any flag of the option works — aliases resolve to the canonical option name. |
| `type`    | One of `choice`, `integer`, `path`, `between` |
| `args…`   | Required for `choice` (the valid values) and `between` (min and max) |

**Types:**

| Type | Validation | Extra args |
|------|-----------|------------|
| `choice` | Value must match one of the listed values | `"val1" "val2" …` |
| `integer` | Value must be a valid integer (negative allowed) | — |
| `path` | No runtime validation — used for completion generation | — |
| `between` | Value must be a float in `[min, max]` (inclusive) | `<min> <max>` |

```bash
option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"
# script --to 720  → ok
# script --to 4k   → Error: invalid value for --to: "4k". Valid choices: 480, 720, 1080
# script --to      → Error: --to requires one of: 480, 720, 1080
# script           → ok, "${program_option["to"]}" is empty and unvalidated

option "--num <amount>" "Number of results" "10"
option_type "--num" integer
# script --num 5   → ok
# script --num abc → Error: --num expects an integer, got "abc"

option "--key <path>" "Path to key file"
option_type "--key" path
# any value accepted; type informs completion generation

option "--scale <value>" "Scale factor"
option_type "--scale" between 0.0 1.0
# script --scale 0.5  → ok
# script --scale 1.5  → Error: --scale must be a number between 0.0 and 1.0, got "1.5"
```

Error messages name the option by its declared flag — the first long form, or the short one for a short-only option — regardless of which alias was used to declare the type.

The `choice` type also annotates the usage output:
```
  --to <resolution>    Target resolution (choices: 480, 720, 1080)
```

---

### `required_option "<flags>" "<description>"`

Declares a required option. Stands in for `option` rather than accompanying it — same flags string, same description, and the option is registered identically, with the addition that `parse` prints an error and exits 1 when the flag is absent. That is the same failure shape as an unsatisfied `option_type`, and as with the other `parse` validations, `--help` and `--generate-completions` still work.

| Parameter     | Meaning |
|---------------|---------|
| `flags`       | One or more flag strings (see [Flag format](#flag-format)) |
| `description` | Text shown in the usage output |

There is no `default` parameter — an option with a default can never be missing. Presence is what is checked, not emptiness, so passing the flag by any alias or in the `--flag=value` form satisfies it.

```bash
required_option "--to <resolution>" "Target resolution"
option_type "--to" choice "480" "720" "1080"

# script --to 720   → ok
# script            → Error: option --to is required
# script --to=999   → Error: invalid value for --to: "999". Valid choices: 480, 720, 1080
# script --to       → Error: --to requires one of: 480, 720, 1080
```

Two declaration-time errors guard against contradictory declarations, both exiting 1 before `parse` runs:

```bash
required_option "--to <resolution>" "Target" "720"
# → Error: required_option "--to <resolution>" does not take a default value

required_option "--no-cheese" "Omit cheese"
# → Error: required_option "--no-cheese" defaults to true, so it can never be missing
```

It also annotates the usage output:
```
  --to <resolution>    Target resolution (choices: 480, 720, 1080) (required)
```

---

### `depends_of "<list>"`

Declares external command dependencies required by the program. Can be called multiple times — entries accumulate. Checked inside `parse`, after flags are matched; a failing check prints an error and exits 1. Like other `parse` validations, `--help` and `--generate-completions` still work even when a dependency is missing.

| Parameter | Description |
|-----------|-------------|
| `list`    | Comma-separated list of dependency entries |

Each entry is either a **bare command name**, checked by running `<name> --version`, or a **full command** (containing a space), run exactly as given — use this form when `--version` isn't the right invocation.

```bash
depends_of "curl, jq"
# runs: curl --version / jq --version
# if either is missing: Error: missing dependency "jq" (command failed: jq --version)

depends_of "docker -v"
# runs "docker -v" verbatim instead of "docker --version"
```

---

### `generate_completions`

Outputs a bash completion script for the current program to stdout. Called automatically by `parse` when `--generate-completions` is passed. Can also be called directly.

Derives all completion behavior from `option()` and `option_type()` declarations — no extra configuration needed. The function name is derived from the program name (`my-tool` → `_my_tool_complete`).

**Completion behavior per type:**

| Option type | After flag (`prev`) | Completing flags (`cur` starts with `-`) |
|---|---|---|
| `choice` | `compgen -W "<choices>"` | flag in `opts` |
| `path` | `compgen -f` (file/directory) | flag in `opts` |
| `integer` / `between` / untyped value | `COMPREPLY=(); return 0` | flag in `opts` |
| boolean (no `<value>`) | *(no case branch)* | flag in `opts` |

```bash
# In terminal — redirect to your completions directory:
my-script --generate-completions > completions/my-script.bash

# Or call directly from within a script:
generate_completions > completions/my-script.bash
```

Example output for a script with `option "--to <res>" …` + `option_type "--to" choice "480" "720" "1080"`:
```bash
_my_script_complete() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    local opts="--to"

    case "$prev" in
        --to)
            COMPREPLY=( $(compgen -W "480 720 1080" -- "$cur") )
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "$cur") )
    else
        COMPREPLY=( $(compgen -f -- "$cur") )
    fi
    return 0
}

complete -F _my_script_complete my-script
```

---

### `parse "$@"`

Parses the script's arguments. Must be called after all `option` and `argument` declarations.

- Handles `--help` / `-h` automatically: prints usage and exits 0.
- Handles `--generate-completions` automatically: prints a bash completion script and exits 0.
- For each matched flag, stores its value in `program_option["<name>"]`. Value-accepting flags consume the next token; boolean flags store `true`.
- Value-accepting flags also accept the inline form `--flag=value` (split on the first `=`, so `--set=a=b` yields `a=b`). Boolean flags do not: `--rm=x` is left as a positional arg.
- Unrecognised tokens are collected as positional args into `program_args` (indexed) and `program_arg` (named, if `argument` was declared).
- If a `required_option` flag is absent, prints an error to stderr and exits 1.
- If a mandatory argument (no default) is missing, prints an error to stderr and exits 1.

```bash
option "-n, --num <amount>" "Number of results" "10"
option "--force" "Skip confirmation"
argument "<path>" "Target path"
parse "$@"

# Called as: script --force -n 5 /tmp
# program_option["force"] → "true"
# program_option["num"]   → "5"
# program_args[0]         → "/tmp"
# program_arg["path"]     → "/tmp"
```

---

### `usage`

Prints the formatted help text to stdout. Called automatically by `parse` when `--help` or `-h` is passed. Can also be called directly.

Output sections:
1. `Usage: <name> [options] <argument>`
2. Description
3. Arguments block (only when an argument is declared)
4. Options block — declared options followed by built-in flags (`--help`, `--generate-completions`)

```bash
name "mytool"
description "Does something useful"
argument "<input>" "Input file"
option "-n, --num <amount>" "Number of results" "10"
usage
```

Output:
```
Usage: mytool [options] <input>

Does something useful

Arguments:
  <input>              Input file

Options:
  -n, --num <amount>   Number of results (default: 10)
  --help, -h           Show this help message
  --generate-completions Output a bash completion script
```

---

## Flag format

The `flags` parameter of `option` accepts one or more flag tokens in a single string. Tokens are extracted by the regex `(-{1,2}[a-zA-Z-]+)`.

| Form | Example |
|------|---------|
| Short flag only | `-f` |
| Long flag only | `--flag` |
| Both combined | `-f, --flag` |
| Short, value-accepting | `-f <value>` |
| Long, value-accepting | `--flag <value>` |
| Both, value-accepting | `-f, --flag <value>` |
| Negation (boolean off) | `--no-<feature>` |

A flag is treated as **value-accepting** when the flags string contains `<...>` anywhere. When matched during parsing, the next argument token is consumed as the flag's value.

---

## Accessor variables

These variables are populated by the framework and are available to scripts after `parse` runs.

### Scalars

| Variable | Content |
|----------|---------|
| `program_name` | Program name (set by `name`) |
| `program_description` | Program description (set by `description`) |
| `program_args_name` | Positional argument name as declared (e.g. `<port>`) |
| `program_args_description` | Positional argument description |
| `program_options` | Raw semicolon-delimited option records (`name:flags:description:default`) |
| `program_args_count` | Number of positional arguments received |

### Arrays

| Variable | Type | Content |
|----------|------|---------|
| `program_args` | indexed | Positional args in order — `program_args[0]`, `program_args[1]`, … |
| `program_arg` | associative | Positional args by name — `program_arg["port"]`, `program_arg["file"]`, … (populated from `<token>` names in the `argument` declaration) |
| `program_option` | associative | Option values — `program_option["num"]`, `program_option["cheese"]`, … Initialised to each option's default; updated by `parse` when the flag is passed |
| `program_args_default` | associative | Default values for the declared argument — keyed by the full argument name string |
| `program_option_type` | associative | Declared type per option name — `program_option_type["to"]` → `"choice"` |
| `program_option_choices` | associative | Space-separated choices or `"min max"` range per option name (set by `option_type` for `choice` and `between` types) — `program_option_choices["to"]` → `"480 720 1080"` |
| `program_dependencies` | indexed | Declared dependency entries, in order — `program_dependencies[0]`, … (set by `depends_of`) |

---

## Development

Requires [shellcheck](https://github.com/koalaman/shellcheck), [shfmt](https://github.com/mvdan/sh), and [bats](https://github.com/bats-core/bats-core).

```bash
brew install shellcheck shfmt
```

| Command | Description |
|---------|-------------|
| `make test` | Run the test suite with bats |
| `make lint` | Lint all shell scripts with shellcheck |
| `make fmt` | Format all shell scripts in-place with shfmt |
| `make fmt-check` | List files whose formatting differs (no writes) |

## Known limitations

- **Single positional argument declaration only.** `argument` overwrites the previous declaration if called more than once. Multiple positional values are still collected in `program_args` and `program_arg` as long as they are named in the single `argument` declaration (e.g. `argument "<key> <file>" …`).
- **Option names must not contain colons or semicolons.** These characters are used as internal delimiters in `program_options`.
- **`depends_of` actually executes the given command.** Stick to invocations with no side effects (e.g. `--version`, `-v`) — not something that starts a server, opens a REPL, or otherwise does real work.
