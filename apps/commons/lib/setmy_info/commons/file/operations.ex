defmodule SetmyInfo.Commons.File.Operations do
    @moduledoc """
    File operations. Direct port of `info.setmy.file.operations` (clj-commons)
    / `smi_python_commons.file.operations` (python-commons): a missing file is
    not an error, it yields `error_return` (default `""`), which is what makes
    "try every candidate config path, keep the ones that exist" work without
    exception handling at the call site.
    """

    @doc """
    Whole content of `file_name`, or `error_return` (default `""`) when the
    file cannot be read for any reason (missing, unreadable, a directory).
    """
    @spec read_file(Path.t(), String.t()) :: String.t()
    def read_file(file_name, error_return \\ "") do
        case File.read(file_name) do
            {:ok, content} -> content
            {:error, _reason} -> error_return
        end
    end
end
