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

    Its own umbrella app (a dev/test-only dependency of every other app,
    never in a release) rather than a script evaluated from .formatter.exs:
    `mix format` caches the evaluated .formatter.exs under _build/ and loads
    plugins from the compiled project, so a compiled module is the only form
    that is found reliably on every run - including with a single app as the
    current project.
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

        # A file with no code in it formats to "" - there is nothing to widen,
        # and appending the trailing newline below would make the plugin the
        # only reason the file changed.
        if stock == "" do
            stock
        else
            widen(stock, opts)
        end
    end

    defp widen(stock, opts) do
        widened =
            stock
            |> String.split("\n")
            |> Enum.with_index(1)
            |> reindent(protected_lines(stock), [{0, 0}], nil, [])
            |> Enum.join("\n")
            |> String.replace(~r/\n*\z/, "\n")

        widened_ast = ast(widened)

        if widened_ast != :unparsable and widened_ast == ast(stock) do
            widened
        else
            fall_back(stock, opts)
        end
    end

    @doc """
    What happens when the AST guard rejects the widened output: the stock
    2-space text is returned and a warning printed, unless `FOUR_SPACES_STRICT`
    is set, in which case it fails the run instead.

    The forgiving default keeps `mix format` usable while a plugin gap is being
    reported. Strict is what CI and the pre-commit hook set, and it is not
    optional there: the stock output is deterministic, so
    `--check-formatted` would compare it against itself and PASS - the gate
    could not enforce the 4-space rule it exists for, and the only evidence
    would be a line of stderr in a long build log.

    Public because it is a policy, and because it is the one branch of this
    module that well-formed input cannot reach: the guard only fires if
    widening corrupts a file, which no known input does. Calling it directly
    is how the unit tier covers both halves.
    """
    @spec fall_back(String.t(), keyword()) :: String.t() | no_return()
    def fall_back(stock, opts) do
        message = "FourSpaces: widening changed #{opts[:file] || "a file"}, kept 2 spaces"

        if System.get_env("FOUR_SPACES_STRICT") in [nil, ""] do
            Mix.shell().error(message)
            stock
        else
            Mix.raise(message <> " - failing because FOUR_SPACES_STRICT is set")
        end
    end

    defp ast(source) do
        case Code.string_to_quoted(source, columns: false) do
            {:ok, quoted} ->
                Macro.prewalk(quoted, fn
                    {form, _meta, args} -> {form, [], args}
                    other -> other
                end)

            # The safety net must never itself throw: output the widening broke
            # so badly it no longer parses reports as :unparsable, which equals
            # no stock AST, so the caller falls back.
            {:error, _reason} ->
                :unparsable
        end
    end

    # Two facts per literal, both taken from the AST so no line-content
    # guessing is involved: the line numbers that are the INSIDE of a
    # multi-line string, charlist or non-heredoc sigil (lines after the one
    # the literal starts on), and the lines heredocs OPEN on, mapped to their
    # delimiter.
    defp protected_lines(stock) do
        lines = String.split(stock, "\n")

        stock
        |> Code.string_to_quoted!(
            columns: true,
            token_metadata: true,
            literal_encoder: &{:ok, {:__literal__, &2, [&1]}}
        )
        |> Macro.prewalk({MapSet.new(), %{}}, fn
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
    defp protect({protected, heredocs} = acc, meta, lines) do
        delimiter = meta[:delimiter]

        cond do
            not is_binary(delimiter) or is_nil(meta[:line]) ->
                acc

            delimiter in @heredocs ->
                {protected, Map.put(heredocs, meta[:line], delimiter)}

            true ->
                continued = physical_newlines(lines, meta[:line], meta[:column], delimiter)
                {Enum.into((meta[:line] + 1)..(meta[:line] + continued)//1, protected), heredocs}
        end
    end

    @closing %{"(" => ")", "[" => "]", "{" => "}", "<" => ">"}

    # Newlines between a literal's opening delimiter (at line/column, after a
    # `~X` sigil prefix if any) and its matching closing one, honouring `\`
    # escapes and `\#{...}` interpolation (not in uppercase sigils).
    # Rejoining the file's tail per literal is quadratic in file size -
    # accepted: literals are sparse, files here are small, and the join is the
    # simplest thing that keeps line/column arithmetic out of the scanner.
    defp physical_newlines(lines, line, column, delimiter) do
        tail = lines |> Enum.drop(line - 1) |> Enum.join("\n") |> String.slice((column - 1)..-1//1)
        interpolates? = not Regex.match?(~r/^~[A-Z]/, tail)
        closing = Map.get(@closing, delimiter, delimiter)

        case String.split(tail, delimiter, parts: 2) do
            [_prefix, rest] -> count_newlines(String.graphemes(rest), closing, interpolates?, 0, 0)
            # Column metadata that does not lead to the delimiter: protect
            # nothing and let the AST guard judge the result.
            _other -> 0
        end
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
    # delimiter in it does not end anything. Known limit: a string nested in
    # an interpolation that itself interpolates a string ends the skip early;
    # the AST guard stands behind that case.
    defp count_newlines([quote | rest], closing, true, depth, count)
         when depth > 0 and quote in ["\"", "'"] do
        {rest, count} = skip_quoted(rest, quote, count)
        count_newlines(rest, closing, true, depth, count)
    end

    defp count_newlines(["\n" | rest], closing, interpolates?, depth, count),
        do: count_newlines(rest, closing, interpolates?, depth, count + 1)

    # Every non-heredoc delimiter is a single grapheme, so equality suffices.
    defp count_newlines([grapheme | rest], closing, interpolates?, depth, count) do
        if depth == 0 and grapheme == closing,
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

    defp reindent([{line, number} | rest], {protected, _heredocs} = literals, stack, nil, acc) do
        if MapSet.member?(protected, number),
            do: reindent(rest, literals, stack, nil, [line | acc]),
            else: reindent_code(line, number, rest, literals, stack, acc)
    end

    defp reindent_code(line, number, rest, {_protected, heredocs} = literals, stack, acc) do
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

        case Map.fetch(heredocs, number) do
            :error -> reindent(rest, literals, stack, nil, [out | acc])
            {:ok, delim} -> reindent(rest, literals, stack, {delim, wanted - indent}, [out | acc])
        end
    end

    defp split_indent(line) do
        body = String.trim_leading(line, " ")
        {String.length(line) - String.length(body), body}
    end
end
