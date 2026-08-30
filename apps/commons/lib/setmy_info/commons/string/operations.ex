defmodule SetmyInfo.Commons.String.Operations do
    @moduledoc """
    String operations. Direct port of `info.setmy.string.operations`
    (clj-commons) / `smi_python_commons.string.operations` (python-commons),
    keeping the same function names and the same argument order.

    Deliberate differences from the two originals, all forced by the language
    rather than chosen:

    * `to_short/2`, `to_long/2` and `to_double/2` from the Clojure original are
      absent - the BEAM has exactly one integer type and one float type, so
      they would be `to_int/2` and `to_float/2` under four extra names. The
      Python port already dropped them for the same reason.
    * `find_named_placeholders/2` de-duplicates (Clojure's `distinct`); the
      Python port has an open `TODO` to do the same, so Clojure is followed
      here as the base implementation.
    * `combined_list/3` drops pairs containing `nil` (Clojure's explicit
      filter). Python's `str.join` would raise on those instead.
    """

    alias SetmyInfo.Commons.Collection.Operations, as: CollectionOperations

    @comma_string ","
    @empty_string ""
    @placeholder_pattern ~r/\$\{(.*?)\}/

    @doc "The default `split_and_trim/2` delimiter: `\",\"`."
    @spec comma_string() :: String.t()
    def comma_string, do: @comma_string

    @doc "The empty string `\"\"`, the default for the `default_text`/`join_text` arguments below."
    @spec empty_string() :: String.t()
    def empty_string, do: @empty_string

    @doc "Splits on `delimiter` (default comma) and trims every fragment."
    @spec split_and_trim(String.t(), String.t()) :: [String.t()]
    def split_and_trim(text, delimiter \\ @comma_string) do
        text |> String.split(delimiter) |> trim_list()
    end

    @doc "Trims leading and trailing whitespace from every string in the list."
    @spec trim_list([String.t()]) :: [String.t()]
    def trim_list(strings_list), do: Enum.map(strings_list, &String.trim/1)

    @doc """
    `"true"`/`"yes"` and `"false"`/`"no"` (any case) convert; anything else
    raises, same as both originals. `nil` yields `default_value`, and a `nil`
    default degrades to `false` - the Clojure original's `(or default-value
    false)`, which its own test suite exercises directly.
    """
    @spec to_boolean(String.t() | nil, boolean() | nil) :: boolean()
    def to_boolean(text, default_value \\ false)
    def to_boolean(nil, nil), do: false
    def to_boolean(nil, default_value), do: default_value

    def to_boolean(text, _default_value) do
        case String.downcase(text) do
            value when value in ["true", "yes"] -> true
            value when value in ["false", "no"] -> false
            _other -> raise ArgumentError, "Invalid boolean value"
        end
    end

    @doc """
    Whole-string integer parse. `"123.123"` does NOT parse to `123` (both
    originals reject it too - Python's `int()` raises, Clojure's
    `Integer/parseInt` throws), so the default is returned instead.
    """
    @spec to_int(String.t() | nil, number() | nil) :: number()
    def to_int(text, default_value \\ 0)
    def to_int(nil, nil), do: 0
    def to_int(nil, default_value), do: default_value

    def to_int(text, default_value) do
        case Integer.parse(text) do
            {value, @empty_string} -> value
            _other -> default_value || 0
        end
    end

    @doc """
    Whole-string float parse (`"1.5"` -> `1.5`; `"1.5abc"` does not parse).
    `nil` text or an unparsable string yields `default_value`, and a `nil`
    default degrades to `0.0`, mirroring `to_int/2`.
    """
    @spec to_float(String.t() | nil, number() | nil) :: number()
    def to_float(text, default_value \\ 0.0)
    def to_float(nil, nil), do: 0.0
    def to_float(nil, default_value), do: default_value

    def to_float(text, default_value) do
        case Float.parse(text) do
            {value, @empty_string} -> value
            _other -> default_value || 0.0
        end
    end

    @doc """
    Parses JSON, falling back to `default_value` on any decode failure - the
    Python port's behaviour. The Clojure original lets the exception escape.
    """
    @spec json_to_object(String.t() | nil, term()) :: term()
    def json_to_object(text, default_value \\ %{})
    def json_to_object(nil, default_value), do: default_value

    def json_to_object(text, default_value) do
        case JSON.decode(text) do
            {:ok, parsed} -> parsed
            {:error, _reason} -> default_value
        end
    end

    @doc """
    Parses a YAML document, falling back to `default_value` when `text` is
    `nil` or fails to parse. Keys stay strings (see
    `SetmyInfo.Commons.Yaml.Parser`).
    """
    @spec yaml_to_object(String.t() | nil, term()) :: term()
    def yaml_to_object(text, default_value \\ %{})
    def yaml_to_object(nil, default_value), do: default_value

    def yaml_to_object(text, default_value) do
        case YamlElixir.read_from_string(text) do
            {:ok, parsed} -> parsed
            {:error, _reason} -> default_value
        end
    end

    @doc """
    Lists every distinct `${name}` placeholder in `text`, in first-appearance
    order. `as_clean: true` (the default) returns bare names, `false` returns
    them still wrapped in `${...}`.
    """
    @spec find_named_placeholders(String.t(), boolean()) :: [String.t()]
    def find_named_placeholders(text, as_clean \\ true) do
        @placeholder_pattern
        |> Regex.scan(text)
        |> Enum.uniq()
        |> Enum.map(fn [wrapped, name] -> if as_clean, do: name, else: wrapped end)
    end

    @doc "Replaces every `${place_holder_name}` occurrence; `nil` replaces with an empty string."
    @spec replace_named_placeholder(String.t(), String.t(), String.t() | nil) :: String.t()
    def replace_named_placeholder(text, place_holder_name, replacement) do
        String.replace(text, "${" <> place_holder_name <> "}", replacement || @empty_string)
    end

    @doc """
    Cartesian product of two string lists, each pair joined by `join_text`.
    Pairs containing `nil` are dropped.

        iex> alias SetmyInfo.Commons.String.Operations
        iex> Operations.combined_list(["A", "B"], ["X", "Y"], ":")
        ["A:X", "A:Y", "B:X", "B:Y"]
    """
    @spec combined_list([String.t() | nil], [String.t() | nil], String.t()) :: [String.t()]
    def combined_list(list1, list2, join_text \\ @empty_string) do
        list1
        |> CollectionOperations.product_as_pairs(list2)
        |> Enum.reject(fn {left, right} -> is_nil(left) or is_nil(right) end)
        |> Enum.map(fn {left, right} -> to_string(left) <> join_text <> to_string(right) end)
    end

    @doc """
    `combined_list/3` with a filter. `func` is genuinely optional in both
    originals, and in both of them a missing `func` yields an empty list
    (Clojure's `when (and (not (nil? func)) ...)`, Python's `if func is not
    None and func(sum_item)`); that quirk is preserved rather than "fixed",
    since `Config.Application`'s file discovery relies on always passing one.
    """
    @spec combined_by_function_list(
                    [String.t()],
                    [String.t()],
                    String.t(),
                    (String.t() -> boolean()) | nil
                ) ::
                    [String.t()]
    def combined_by_function_list(list1, list2, join_text \\ @empty_string, func \\ nil) do
        result =
            for item1 <- list1, item2 <- list2, reduce: [] do
                acc ->
                    sum_item = to_string(item1) <> join_text <> to_string(item2)
                    if not is_nil(func) and func.(sum_item), do: [sum_item | acc], else: acc
            end

        Enum.reverse(result)
    end

    @doc "Clojure's `nil-to-default` / Python's `none_to_default`."
    @spec nil_to_default(String.t() | nil, String.t()) :: String.t()
    def nil_to_default(text, default_text \\ @empty_string)
    def nil_to_default(nil, default_text), do: default_text
    def nil_to_default(text, _default_text), do: text
end
