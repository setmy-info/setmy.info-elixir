# Umbrella root: format the root files here and delegate every app to its own
# .formatter.exs, the way `mix new --umbrella` sets it up.
Code.require_file("formatter_indent.exs", __DIR__)

[
    plugins: [SetmyInfo.Elixir.Formatter.FourSpaces],
    inputs: ["{mix,lifecycle,formatter_indent,.formatter,.credo}.exs", "config/*.exs"],
    subdirectories: ["apps/*"]
]
