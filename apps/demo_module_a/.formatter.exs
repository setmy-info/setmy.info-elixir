Code.require_file("../../formatter_indent.exs", __DIR__)

[
    plugins: [SetmyInfo.Elixir.Formatter.FourSpaces],
    inputs: ["{mix,.formatter}.exs", "{lib,test}/**/*.{ex,exs}"]
]
