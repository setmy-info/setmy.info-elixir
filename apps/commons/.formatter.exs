# The umbrella's 4-space indentation plugin (apps/formatter, a dev/test
# dependency of this app). A Hex consumer's `import_deps` only reads the
# `export:` key of this file, so the plugin entry is inert there.
[
    plugins: [SetmyInfo.Elixir.Formatter.FourSpaces],
    inputs: ["{mix,.formatter}.exs", "{lib,test}/**/*.{ex,exs}"]
]
