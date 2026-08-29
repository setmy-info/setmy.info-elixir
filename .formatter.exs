# Umbrella root: format the root files here and delegate every app to its own
# .formatter.exs, the way `mix new --umbrella` sets it up.
[
  inputs: ["{mix,.formatter,.credo}.exs", "config/*.exs"],
  subdirectories: ["apps/*"]
]
