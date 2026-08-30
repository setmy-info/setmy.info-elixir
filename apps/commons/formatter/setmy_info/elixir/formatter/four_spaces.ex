defmodule SetmyInfo.Elixir.Formatter.FourSpaces do
    @moduledoc """
    `mix format` plugin: the stock Elixir formatter has no indentation-width
    option and always emits 2 spaces. This project's style is 4 (.editorconfig),
    so every .ex/.exs file goes through the stock formatter and then has its
    indentation widened. Because it is a plugin, `mix format --check-formatted`
    (pre-commit hook, CI quality gate, editors) verifies the same 4-space form.

    The stock output mixes two kinds of indentation: NESTING, always exactly +2
    per level (a `do` block, a `->` clause, a wrapped argument list), and
    ALIGNMENT, a continuation line placed at an arbitrary column offset from the
    statement it belongs to (`assert x == [` puts the elements 9 columns in; a
    wrapped `@spec` aligns under its opening paren). Only nesting steps are
    widened (2 -> 4); alignment offsets are carried over unchanged, otherwise a
    wrapped line at column 70 would end up at 140.

    Inside a heredoc (`\"""` / `'''`) the content is shifted by exactly what its
    delimiter line was shifted, so string values - docs, code samples in docs,
    test fixtures - are unchanged. The continuation lines of an ordinary
    multi-line string, charlist or sigil ARE the value, so they are copied
    byte for byte (found through the AST, not by guessing at quotes). As a last
    line of defence the result must parse to the same AST as the stock output;
    if it does not, the stock output is used for that file and a warning printed.

    A compiled module of the commons app (apps/commons/formatter/, an extra
    elixirc path that is not in the Hex package) rather than a script evaluated
    from .formatter.exs: `mix format` caches the evaluated .formatter.exs under
    _build/ and loads plugins from the compiled project, so this is the only
    form that is found reliably on every run.
    """

    @behaviour Mix.Tasks.Format

    @heredocs [~s("""), ~s(''')]
    @stock 2
    @wanted 4

    @impl true
    def features(_opts), do: [extensions: [".ex", ".exs"]]

    @impl true
    def format(contents, opts) do
        stock = contents |> Code.format_string!(opts) |> IO.iodata_to_binary()

        widened =
            stock
            |> String.split("\n")
            |> Enum.with_index(1)
            |> reindent(protected_lines(stock), [{0, 0}], nil, [])
            |> Enum.join("\n")
            |> String.replace(~r/\n*\z/, "\n")

        if ast(widened) == ast(stock) do
            widened
        else
            Mix.shell().error("FourSpaces: widening changed #{opts[:file] || "a file"}, kept 2 spaces")

            stock
        end
    end

    defp ast(source) do
        source
        |> Code.string_to_quoted!(columns: false)
        |> Macro.prewalk(fn
            {form, _meta, args} -> {form, [], args}
            other -> other
        end)
    end

    # Line numbers that are the inside of a multi-line string, charlist or
    # sigil that is not a heredoc: lines after the one the literal starts on.
    defp protected_lines(stock) do
        lines = String.split(stock, "\n")

        stock
        |> Code.string_to_quoted!(
            columns: true,
            token_metadata: true,
            literal_encoder: &{:ok, {:__literal__, &2, [&1]}}
        )
        |> Macro.prewalk(MapSet.new(), fn
            {:__literal__, meta, [value]} = node, acc when is_binary(value) or is_list(value) ->
                {node, protect(acc, meta, lines)}

            {:<<>>, meta, _parts} = node, acc ->
                {node, protect(acc, meta, lines)}

            {sigil, meta, [{:<<>>, _, _parts}, _mods]} = node, acc when is_atom(sigil) ->
                if String.starts_with?(Atom.to_string(sigil), "sigil_"),
                    do: {node, protect(acc, meta, lines)},
                    else: {node, acc}

            node, acc ->
                {node, acc}
        end)
        |> elem(1)
    end

    # The lines a literal continues on are found in the SOURCE, not in the
    # value: `"a\nb"` on one physical line contains a newline character but
    # continues on no line at all.
    defp protect(acc, meta, lines) do
        delimiter = meta[:delimiter]

        if is_binary(delimiter) and delimiter not in @heredocs and meta[:line] do
            continued = physical_newlines(lines, meta[:line], meta[:column], delimiter)
            Enum.into((meta[:line] + 1)..(meta[:line] + continued)//1, acc)
        else
            acc
        end
    end

    @closing %{"(" => ")", "[" => "]", "{" => "}", "<" => ">"}

    # Newlines between a literal's opening delimiter (at line/column, after a
    # `~X` sigil prefix if any) and its matching closing one, honouring `\`
    # escapes and `\#{...}` interpolation (not in uppercase sigils).
    defp physical_newlines(lines, line, column, delimiter) do
        tail = lines |> Enum.drop(line - 1) |> Enum.join("\n") |> String.slice((column - 1)..-1//1)
        interpolates? = not Regex.match?(~r/^~[A-Z]/, tail)
        [_prefix, rest] = String.split(tail, delimiter, parts: 2)
        closing = Map.get(@closing, delimiter, delimiter)
        count_newlines(String.graphemes(rest), closing, interpolates?, 0, 0)
    end

    defp count_newlines([], _closing, _interpolates?, _depth, count), do: count

    defp count_newlines(["\\", _escaped | rest], closing, interpolates?, depth, count),
        do: count_newlines(rest, closing, interpolates?, depth, count)

    defp count_newlines(["#", "{" | rest], closing, true, depth, count),
        do: count_newlines(rest, closing, true, depth + 1, count)

    defp count_newlines(["{" | rest], closing, true, depth, count) when depth > 0,
        do: count_newlines(rest, closing, true, depth + 1, count)

    defp count_newlines(["}" | rest], closing, true, depth, count) when depth > 0,
        do: count_newlines(rest, closing, true, depth - 1, count)

    # A string inside the interpolation: skipped whole, so a `}` or the outer
    # delimiter in it does not end anything.
    defp count_newlines([quote | rest], closing, true, depth, count)
         when depth > 0 and quote in ["\"", "'"] do
        {rest, count} = skip_quoted(rest, quote, count)
        count_newlines(rest, closing, true, depth, count)
    end

    defp count_newlines(["\n" | rest], closing, interpolates?, depth, count),
        do: count_newlines(rest, closing, interpolates?, depth, count + 1)

    defp count_newlines([grapheme | rest], closing, interpolates?, depth, count) do
        if depth == 0 and String.starts_with?(Enum.join([grapheme | Enum.take(rest, 2)]), closing),
            do: count,
            else: count_newlines(rest, closing, interpolates?, depth, count)
    end

    defp skip_quoted([], _quote, count), do: {[], count}
    defp skip_quoted(["\\", _escaped | rest], quote, count), do: skip_quoted(rest, quote, count)
    defp skip_quoted([quote | rest], quote, count), do: {rest, count}
    defp skip_quoted(["\n" | rest], quote, count), do: skip_quoted(rest, quote, count + 1)
    defp skip_quoted([_ | rest], quote, count), do: skip_quoted(rest, quote, count)

    # stack: [{stock_indent, wanted_indent}] of the enclosing lines, innermost
    # first; heredoc: nil or {delimiter, shift} while inside one.
    defp reindent([], _protected, _stack, _heredoc, acc), do: Enum.reverse(acc)

    defp reindent([{"", _} | rest], protected, stack, heredoc, acc),
        do: reindent(rest, protected, stack, heredoc, ["" | acc])

    defp reindent([{line, _} | rest], protected, stack, {delim, shift} = heredoc, acc) do
        out = String.duplicate(" ", shift) <> line

        if String.starts_with?(String.trim_leading(line), delim),
            do: reindent(rest, protected, stack, nil, [out | acc]),
            else: reindent(rest, protected, stack, heredoc, [out | acc])
    end

    defp reindent([{line, number} | rest], protected, stack, nil, acc) do
        if MapSet.member?(protected, number),
            do: reindent(rest, protected, stack, nil, [line | acc]),
            else: reindent_code(line, rest, protected, stack, acc)
    end

    defp reindent_code(line, rest, protected, stack, acc) do
        {indent, body} = split_indent(line)
        stack = Enum.drop_while(stack, fn {stock, _} -> stock > indent end)
        [{stock, wanted} | _] = stack

        wanted =
            cond do
                indent == stock -> wanted
                indent - stock == @stock -> wanted + @wanted
                true -> wanted + (indent - stock)
            end

        stack = if indent == stock, do: stack, else: [{indent, wanted} | stack]
        out = String.duplicate(" ", wanted) <> body

        case heredoc_opened(body) do
            nil -> reindent(rest, protected, stack, nil, [out | acc])
            delim -> reindent(rest, protected, stack, {delim, wanted - indent}, [out | acc])
        end
    end

    defp split_indent(line) do
        body = String.trim_leading(line, " ")
        {String.length(line) - String.length(body), body}
    end

    # A heredoc opens when its delimiter ends a code line (`@doc """`, `~S"""`,
    # `x = '''`). Comments are skipped so a `"""` mentioned in one is inert.
    defp heredoc_opened("#" <> _), do: nil
    defp heredoc_opened(body), do: Enum.find(@heredocs, &String.ends_with?(body, &1))
end
