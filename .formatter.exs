# Umbrella root: format the root files here and delegate every app to its own
# .formatter.exs, the way `mix new --umbrella` sets it up. The plugin widens
# indentation to 4 spaces; see apps/formatter/.
[
    plugins: [SetmyInfo.Elixir.Formatter.FourSpaces],
    inputs: ["*.{ex,exs}", ".{formatter,credo}.exs", "config/*.exs"],
    subdirectories: ["apps/*"]
]
