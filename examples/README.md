# Examples

Each script demonstrates one feature of program.sh.

| Script | Feature demonstrated |
|--------|----------------------|
| [`greet.sh`](https://github.com/ggviana/program.sh/blob/main/examples/greet.sh) | Positional argument with named token access |
| [`upload.sh`](https://github.com/ggviana/program.sh/blob/main/examples/upload.sh) | Multiple positional tokens in a single `argument` declaration |
| [`publish.sh`](https://github.com/ggviana/program.sh/blob/main/examples/publish.sh) | Boolean flag — action gated behind `--force` |
| [`serve.sh`](https://github.com/ggviana/program.sh/blob/main/examples/serve.sh) | Value-accepting option with a default (`--port 8080`) |
| [`backup.sh`](https://github.com/ggviana/program.sh/blob/main/examples/backup.sh) | `--no-*` flag convention — defaults to `true`, flag disables the behaviour |
| [`convert.sh`](https://github.com/ggviana/program.sh/blob/main/examples/convert.sh) | `option_type choice` — value must be one of a fixed set |
| [`repeat.sh`](https://github.com/ggviana/program.sh/blob/main/examples/repeat.sh) | `option_type integer` — value must be a valid integer |
| [`sleep-for.sh`](https://github.com/ggviana/program.sh/blob/main/examples/sleep-for.sh) | `option_type between` — value must be a float within a range |
| [`completions.sh`](https://github.com/ggviana/program.sh/blob/main/examples/completions.sh) | `--generate-completions` — generating and installing tab completions |

Run any script with `--help` to see its usage.
