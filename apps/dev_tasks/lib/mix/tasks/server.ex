defmodule Mix.Tasks.Server do
  use Mix.Task

  @shortdoc "Start/stop a background static file server for e2e running-instance tests"

  @moduledoc """
  Start/stop a background Plug.Cowboy static file server, or run one in the
  foreground. Mirrors `tools/http-server.js` / `scripts/http_server.py`:
  same start/stop/serve subcommands, same per-port state file recording the
  child's OS pid so a later `stop` can find and kill it.

  Erlang/Elixir has no built-in "spawn fully detached, survives parent exit"
  primitive the way Python's `subprocess.Popen(start_new_session=True)` or
  Node's `spawn(detached: true)` do - `Port.open` ties the child to the
  owning BEAM process. Uses the portable shell equivalent instead:
  `nohup ... & echo $!`, capturing the OS pid from the echoed output.

      mix server start --app demo_module_a
      mix server stop --app demo_module_a
      mix server serve --app demo_module_a   # foreground, blocks
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(args) do
    {opts, positional, _invalid} = OptionParser.parse(args, strict: [app: :string])
    command = List.first(positional) || "start"
    app = opts[:app] || Mix.raise("Missing required option: --app <name>")

    case command do
      "start" -> start_server(app)
      "stop" -> stop_server(app)
      "serve" -> serve(app)
      other -> Mix.raise("Unknown server command: #{other}")
    end
  end

  defp state_dir, do: Path.join([WorkspaceHelper.root_dir(), ".artifacts", "http-servers"])
  defp state_file(port), do: Path.join(state_dir(), "#{port}.json")

  defp app_config(app) do
    app_atom = String.to_atom(app)
    port = Application.get_env(app_atom, :port) || Mix.raise("No :port configured for #{app}")
    web_dir = Application.get_env(app_atom, :web_dir) || "priv/web"
    app_dir = Path.join([WorkspaceHelper.root_dir(), "apps", app])
    %{port: port, dir: Path.join(app_dir, web_dir)}
  end

  defp start_server(app) do
    %{port: port, dir: dir} = app_config(app)
    File.mkdir_p!(state_dir())
    file = state_file(port)

    if File.exists?(file) do
      Mix.raise("HTTP server for port #{port} is already registered.")
    end

    mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")

    shell_command =
      "nohup #{mix_bin} server serve --app #{app} > /dev/null 2>&1 & echo $!"

    {pid_output, 0} = System.cmd("/bin/sh", ["-c", shell_command], cd: WorkspaceHelper.root_dir())
    pid = pid_output |> String.trim() |> String.to_integer()

    File.write!(file, encode_state(%{"pid" => pid, "port" => port, "dir" => dir}))

    if wait_until_listening(port) do
      Mix.shell().info("Started HTTP server on port #{port} serving #{dir}")
    else
      File.rm(file)
      Mix.raise("HTTP server on port #{port} did not start listening in time")
    end
  end

  defp wait_until_listening(port, attempts \\ 50)
  defp wait_until_listening(_port, 0), do: false

  defp wait_until_listening(port, attempts) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [], 200) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        Process.sleep(100)
        wait_until_listening(port, attempts - 1)
    end
  end

  defp stop_server(app) do
    %{port: port} = app_config(app)
    file = state_file(port)

    if File.exists?(file) do
      %{"pid" => pid} = file |> File.read!() |> decode_state()
      System.cmd("kill", [to_string(pid)], stderr_to_stdout: true)
      File.rm!(file)
      Mix.shell().info("Stopped HTTP server on port #{port}")
    else
      Mix.shell().info("No HTTP server registered for port #{port}")
    end
  end

  defp serve(app) do
    # A bare `mix <task>` invocation does NOT start dependency applications
    # (telemetry, cowboy, plug_cowboy) the way `mix run`/an OTP release does
    # - confirmed by hitting `:gen_server.call(:telemetry_handler_table, ...)
    # no process` for real before adding this line, not assumed.
    Mix.Task.run("app.start")

    %{port: port, dir: dir} = app_config(app)

    {:ok, _pid} =
      Plug.Cowboy.http(SetmyInfo.Build.StaticServerPlug, [dir: dir],
        port: port,
        ip: {127, 0, 0, 1}
      )

    Process.sleep(:infinity)
  end

  # Tiny hand-rolled JSON, avoiding a Jason dependency for two fields -
  # `:json` (stdlib since OTP 27) handles encode; decode via a minimal
  # parser would be overkill, so this reads back with a simple split instead
  # of a real JSON decoder (state file is only ever written by this task).
  defp encode_state(map) do
    :json.encode(map) |> IO.iodata_to_binary()
  end

  defp decode_state(binary) do
    binary
    |> String.trim()
    |> String.trim_leading("{")
    |> String.trim_trailing("}")
    |> String.split(",")
    |> Map.new(fn pair ->
      [key, value] = String.split(pair, ":", parts: 2)
      key = key |> String.trim() |> String.trim("\"")
      value = value |> String.trim() |> String.trim("\"")
      {key, value}
    end)
  end
end
