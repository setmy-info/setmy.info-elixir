defmodule SetmyInfo.Elixir.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      name: "setmy.info-elixir",
      version: "0.1.0",
      start_permanent: Mix.env() == :live,
      deps: deps(),
      aliases: aliases(),
      cli: cli(),
      test_coverage: [tool: ExCoveralls],
      releases: releases(),
      dialyzer: dialyzer(),
      docs: docs(),
      hex: hex()
    ]
  end

  # `mix hex.audit`'s accepted advisories - the same discipline as
  # .mix_audit_ignore: each one visible, reasoned, and to be re-reviewed when
  # cowlib is upgraded. All three are in cowlib 2.19.0 (transitive, via
  # plug_cowboy -> cowboy), the LATEST release at the time of review
  # (2026-08-29); there is nothing newer to bump to. mix_audit's database
  # does not list any of them against 2.19.0, which is why only hex.audit
  # needs this list.
  defp hex do
    [
      ignore_advisories: [
        # LOW. Cookie request-header injection in cow_cookie:cookie/1. The
        # advisory's own affected range ends at 2.16.1 (checked at
        # https://api.osv.dev/v1/vulns/GHSA-g2wm-735q-3f56); Hex's entry is
        # stale relative to it.
        "EEF-CVE-2026-43969",
        # MEDIUM. Response splitting via non-VCHAR bytes in
        # cow_http_struct_hd:escape_string/2 - reachable only by building
        # structured headers from request input with cow_http_struct_hd:item/1.
        # The demo apps' SetmyInfo.DemoModule*.Web plugs serve a static page and
        # build no headers from input; cowboy >= 2.16 also rejects CR/LF in
        # outgoing header values by default.
        "EEF-CVE-2026-43966",
        # MEDIUM. Link header directive smuggling via cow_link:link/1. Nothing
        # in this umbrella emits Link headers or calls cow_link at all.
        "EEF-CVE-2026-43971"
      ]
    ]
  end

  # Umbrella-root deps are the shared dev/test toolchain only - the root is
  # never compiled as an app, so nothing runtime belongs here. Runtime deps
  # (including `in_umbrella:` siblings) live in each app's own mix.exs.
  #
  # sobelow is the exception that is NOT here: it refuses to run against an
  # umbrella root ("each application should be scanned separately"), so it is
  # declared per app and fanned out with `mix cmd` - see the `sobelow` alias.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      # JUnit XML per app for Jenkins' junit step (see each app's test_helper.exs).
      {:junit_formatter, "~> 3.4", only: :test, runtime: false},
      # Documentation coverage: every public module/function has a doc + spec.
      {:doctor, "~> 0.23", only: [:dev, :test], runtime: false},
      # CycloneDX SBOM from mix.lock - the cyclonedx-maven-plugin equivalent.
      {:sbom, "~> 0.10", only: [:dev, :test], runtime: false},
      # `mix test.watch` - re-runs the unit tier on every save, dev only.
      {:mix_test_watch, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs: [
        credo: :dev,
        dialyzer: :dev,
        "deps.audit": :dev,
        audit: :dev,
        quality: :dev,
        "test.unit": :test,
        "test.integration": :test,
        "test.e2e": :test,
        "test.all": :test,
        "server.start": :test,
        "server.stop": :test,
        coverage: :test,
        "coverage.xml": :test,
        doctor: :dev,
        sbom: :dev,
        reports: :test,
        "security.reports": :dev,
        "test.watch": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test
      ]
    ]
  end

  # Test tiers are selected by ExUnit tags (`@moduletag :integration` /
  # `:e2e`, excluded by default in each app's test_helper.exs), not by
  # hardcoded path lists: `mix test`'s own umbrella recursion then keeps
  # working unchanged, and adding or removing an app needs no edit here.
  # The directory split under test/ is kept purely for readability.
  #
  # The integration and e2e tiers run against REAL RUNNING INSTANCES, the way
  # Maven's failsafe brackets integration-test with pre-/post-integration-test:
  # `server.start` builds every deployable app's OTP release for the test env
  # and starts it as a daemon (`bin/<app> daemon`), the tier runs with
  # `--no-start` so the test VM does not bring up a second copy on the same
  # port, and `server.stop` shuts the daemons down (`bin/<app> stop`). So what
  # the e2e tier exercises is the release artifact itself - what gets
  # deployed - not the code hosted inside the test runner. Mix stops an alias
  # at the first failing task, so a failing tier leaves the daemons running;
  # `server.stop` is idempotent and CI calls it again in post { always }.
  defp aliases do
    [
      "test.unit": ["test"],
      "test.integration": ["server.start", "test --only integration --no-start", "server.stop"],
      "test.e2e": ["server.start", "test --only e2e --no-start", "server.stop"],
      "test.all": [
        "server.start",
        "test --include integration --include e2e --no-start",
        "server.stop"
      ],
      "server.start": [&servers_start/1],
      "server.stop": [&servers_stop/1],
      # --umbrella aggregates every app's stats into one report at the root,
      # which is also the only place ExCoveralls finds coveralls.json (it reads
      # it from the current directory, and per-app runs sit in apps/<name>/).
      # The HTML report is for people (cover/excoveralls.html). coverage.xml is
      # the SonarQube generic test-coverage XML - standalone on purpose:
      # ExCoveralls accumulates stats for the life of one Mix VM, so two
      # coverage runs in one invocation would double-count the second.
      coverage: [
        "server.start",
        "coveralls.html --umbrella --include integration --include e2e --no-start",
        "server.stop"
      ],
      "coverage.xml": [
        "server.start",
        "coveralls.xml --umbrella --include integration --include e2e --no-start",
        "server.stop"
      ],
      # Dependency advisories (mix_audit) plus retired/deprecated packages
      # (hex.audit) - the OWASP dependency-check + versions-plugin pair.
      audit: ["deps.audit --ignore-file .mix_audit_ignore", "hex.audit"],
      # Module dependency cycles are a design smell; none are allowed.
      "xref.cycles": ["xref graph --format cycles --fail-above 0"],
      # CycloneDX SBOM from mix.lock, into reports/sbom/.
      sbom: ["sbom.cyclonedx -f -o reports/sbom/bom.xml"],
      # Vulnerability reports as files: mix_audit JSON (dependency advisories)
      # and one Sobelow JSON per app (static security analysis). The `audit`
      # and `sobelow` aliases above are the GATES - these are the documents.
      "security.reports": [&security_reports/1],
      # Everything that produces a document, in one go: API docs, coverage
      # HTML, SBOM, vulnerability reports, dependency tree.
      reports: ["docs", "coverage", "sbom", "security.reports", &deps_tree/1],
      # `mix release` needs a name when more than one release is configured;
      # this builds them all, one after another, for the current MIX_ENV.
      "release.all": [&release_all/1],
      # Sobelow refuses to run against an umbrella root ("each application
      # should be scanned separately"), so it is fanned out over apps/* with
      # Mix's own `cmd` recursion. Flags rather than a .sobelow-conf: the
      # config file is read from the current directory, which is a different
      # app on every iteration. `--exit medium` gates on medium- and
      # high-confidence findings only: commons' whole job is reading a
      # caller-supplied config path, which Sobelow reports as a low-confidence
      # Traversal.FileModule finding. It stays printed, it just does not fail
      # the build.
      sobelow: ["cmd mix sobelow --exit medium"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "xref.cycles",
        "doctor",
        "sobelow",
        "audit"
      ]
    ]
  end

  # One OTP release per deployable app, so a module is deployed on its own
  # rather than as part of one umbrella-wide artifact:
  #
  #     MIX_ENV=live mix release demo_module_a
  #     _build/live/rel/demo_module_a/bin/demo_module_a start
  #
  # `commons` has no release of its own on purpose - it is a library, consumed
  # as the Hex package `setmy_info_commons`, not run.
  @deployable_apps [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d]

  defp releases do
    Map.new(@deployable_apps, fn app ->
      {app,
       [
         # {:from_app, app} rather than the umbrella root's own version: each
         # app is versioned independently, and the release is that app's.
         version: {:from_app, app},
         # Umbrella siblings this app depends on are started inside the release
         # too (Mix insists: a :permanent app's deps cannot be merely :load).
         # They do NOT open their endpoints there - see config/runtime.exs.
         applications: [{app, :permanent}],
         include_executables_for: [:unix]
       ]}
    end)
  end

  defp release_all(args) do
    Enum.each(@deployable_apps, &Mix.Task.rerun("release", [to_string(&1) | args]))
  end

  # pre-integration-test / pre-e2e-test: build the releases for the current
  # Mix env, stop anything stale from an aborted run, start each app as a
  # daemon and wait until its port answers.
  defp servers_start(_args) do
    # Stop first, then rebuild: never swap release files under a live VM.
    Enum.each(@deployable_apps, &release_cmd(&1, "stop"))
    release_all(["--overwrite", "--quiet"])
    Enum.each(@deployable_apps, &release_cmd(&1, "daemon"))
    Enum.each(@deployable_apps, &wait_for_port/1)
    # The port answering is not proof it is OUR daemon (a stray listener would
    # pass too); `bin/<app> pid` only succeeds against the running release.
    Enum.each(@deployable_apps, &assert_running/1)
  end

  defp assert_running(app) do
    case release_cmd(app, "pid") do
      0 -> :ok
      _ -> Mix.raise("#{app}'s release is not running - is something else on its port?")
    end
  end

  # post-integration-test / post-e2e-test: idempotent - a daemon that is not
  # running just makes `bin/<app> stop` exit non-zero, which is ignored.
  defp servers_stop(_args) do
    Enum.each(@deployable_apps, &release_cmd(&1, "stop"))
  end

  defp release_cmd(app, command) do
    bin = Path.join([Mix.Project.build_path(), "rel", to_string(app), "bin", to_string(app)])

    if File.exists?(bin) do
      {output, status} = System.cmd(bin, [command], stderr_to_stdout: true)
      Mix.shell().info("#{app} #{command}: exit #{status} #{String.trim(output)}")
      status
    else
      Mix.shell().info("#{app} #{command}: no release at #{bin}, skipping")
      1
    end
  end

  defp wait_for_port(app, attempts \\ 50) do
    port = Application.fetch_env!(app, :port)

    case :gen_tcp.connect(~c"127.0.0.1", port, [], 200) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        Mix.shell().info("#{app} is listening on port #{port}")

      {:error, _} when attempts > 0 ->
        Process.sleep(200)
        wait_for_port(app, attempts - 1)

      {:error, reason} ->
        Mix.raise("#{app} did not open port #{port}: #{inspect(reason)}")
    end
  end

  # The tools' own exit codes are deliberately ignored here: a report of a
  # finding is still a report. Failing on findings is what `mix quality` does.
  defp security_reports(_args) do
    dir = "reports/security"
    File.mkdir_p!(dir)
    env = [{"MIX_ENV", to_string(Mix.env())}]

    audit_args = ["deps.audit", "--format", "json", "--ignore-file", ".mix_audit_ignore"]
    {audit, _} = System.cmd(mix_executable(), audit_args, env: env)

    File.write!(Path.join(dir, "deps_audit.json"), audit)
    Mix.shell().info("Wrote #{dir}/deps_audit.json")

    for app <- @deployable_apps ++ [:commons] do
      out = Path.expand(Path.join(dir, "sobelow-#{app}.json"))

      {_, _} =
        System.cmd(mix_executable(), ["sobelow", "--format", "json", "--out", out],
          cd: Path.join("apps", to_string(app)),
          env: env
        )

      Mix.shell().info("Wrote #{Path.relative_to_cwd(out)}")
    end
  end

  defp deps_tree(_args) do
    File.mkdir_p!("reports")

    case System.cmd(mix_executable(), ["deps.tree"], env: [{"MIX_ENV", to_string(Mix.env())}]) do
      {tree, 0} ->
        File.write!("reports/deps.tree.txt", tree)
        Mix.shell().info("Wrote reports/deps.tree.txt")

      {output, status} ->
        Mix.raise("mix deps.tree failed (exit #{status}):\n#{output}")
    end
  end

  # `mix` is `mix.bat` on Windows; find_executable resolves whichever is there.
  defp mix_executable, do: System.find_executable("mix") || "mix"

  defp dialyzer do
    [
      plt_local_path: "_build/plts",
      plt_core_path: "_build/plts",
      flags: [:error_handling]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/setmy-info/setmy.info-elixir"
    ]
  end
end
