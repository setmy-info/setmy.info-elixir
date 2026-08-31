# IntelliJ IDEA setup

Optional — the project builds and tests entirely from the command line (see the
[README](../README.md)). This is only what IDEA itself needs.

## Plugin

[Elixir](https://plugins.jetbrains.com/plugin/7522-elixir) — adds the SDK types the steps below
refer to.

## SDK paths

*Settings → Languages & Frameworks → Elixir*, and *File → Project Structure → SDKs*:

1. Erlang SDK: `/opt/erlang/lib/erlang`
2. Elixir SDK: `/opt/elixir`

Adjust both to wherever your distribution puts them; `which elixir` and
`erl -noshell -eval 'io:format("~s~n",[code:root_dir()]),halt().'` will tell you.

## Formatting

Do **not** let IDEA reformat Elixir sources. This project indents with 4 spaces, which the stock
Elixir formatter cannot emit — `mix format` gets there through the `apps/formatter` plugin, and
`mix format --check-formatted` is what CI verifies. Configure format-on-save to run `mix format`
(the Elixir plugin can do this), or use the pre-commit hook from the README instead of IDEA's own
formatter.

## Ignored files

`.idea/` and `*.iml` are in `.gitignore`; IDEA's project files are never committed.
