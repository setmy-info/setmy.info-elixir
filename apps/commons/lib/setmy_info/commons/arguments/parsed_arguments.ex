defmodule SetmyInfo.Commons.Arguments.ParsedArguments do
  @moduledoc """
  Result of `SetmyInfo.Commons.Arguments.Parser.parse_arguments/2`. Mirrors
  the `{:options, :arguments, :summary, :errors}` map clj-commons' parser
  returns (python-commons returns a flat `argparse.Namespace` instead, which
  loses the positional/error split).

  `errors` are structured tuples rather than the Clojure port's pre-rendered
  strings, because `SetmyInfo.Commons.Config.Application` has to filter out
  the "unknown option" entries that are in fact configuration overrides
  (`--smi-server-port`) - those are only knowable after the YAML has been
  read. `format_errors/1` renders them for display.
  """

  defstruct options: %{}, arguments: [], errors: [], summary: ""

  @type error :: {:unknown_option, String.t()} | {:missing_required, String.t()}

  @type t :: %__MODULE__{
          options: %{optional(atom()) => term()},
          arguments: [String.t()],
          errors: [error()],
          summary: String.t()
        }

  @doc "Renders every entry in `errors` for display, via `format_error/1`."
  @spec format_errors(t()) :: [String.t()]
  def format_errors(%__MODULE__{errors: errors}), do: Enum.map(errors, &format_error/1)

  @doc """
  Renders one error tuple as a human readable line, in the wording the
  Clojure port's `clojure.tools.cli` produces (`Unknown option: "-x"`,
  `Missing required option: "--flag"`).
  """
  @spec format_error(error()) :: String.t()
  def format_error({:unknown_option, flag}), do: ~s(Unknown option: "#{flag}")
  def format_error({:missing_required, flag}), do: ~s(Missing required option: "#{flag}")
end
