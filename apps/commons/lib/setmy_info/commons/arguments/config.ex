defmodule SetmyInfo.Commons.Arguments.Config do
  @moduledoc """
  A CLI description plus its option declarations. Equivalent of clj-commons'
  `Config` record / python-commons' `Config` class.

  python-commons also declares a `SubCommandsConfig`, but its `parse_arguments`
  branch is unfinished (`# TODO : by example below : make it work`) and the
  Clojure port has no equivalent at all, so it is not ported here.
  """

  alias SetmyInfo.Commons.Arguments.Argument

  defstruct description: "", arguments: []

  @type t :: %__MODULE__{description: String.t(), arguments: [Argument.t()]}

  @doc "Builds a CLI config from a `description` and its `Argument` declarations."
  @spec new(String.t(), [Argument.t()]) :: t()
  def new(description, arguments) do
    %__MODULE__{description: description, arguments: arguments}
  end
end
