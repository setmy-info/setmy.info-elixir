# This app IS the umbrella's 4-space indentation plugin, so it formats
# itself with it. A Hex consumer's `import_deps` only reads the `export:`
# key of this file, so the plugin entry is inert there.
[
    plugins: [SetmyInfo.Elixir.Formatter.FourSpaces],
    inputs: ["{mix,.formatter}.exs", "{lib,test}/**/*.{ex,exs}"]
]
