# The project-specific pre/post steps of the test lifecycle live next door;
# this file only defines the phases. See lifecycle.exs.
Code.require_file("lifecycle.exs", __DIR__)

defmodule SetmyInfo.Elixir.MixProject do
    use Mix.Project

    alias SetmyInfo.Elixir.Lifecycle

    @tiers [:integration, :e2e]
    @all_tiers_args ["--include", "integration", "--include", "e2e", "--no-start"]

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
    # sobelow and sbom are the exceptions that are NOT here: both run per app
    # (sobelow refuses an umbrella root; an SBOM is per artifact), and a task's
    # binary only resolves against the current project's own deps - so they are
    # declared in every app's mix.exs and fanned out from the `sobelow` and
    # `sbom` aliases.
    defp deps do
        [
            {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
            {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
            {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
            {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
            {:excoveralls, "~> 0.18", only: :test, runtime: false},
            # JUnit XML per app for Jenkins' junit step (see each app's test_helper.exs).
            {:junit_formatter, "~> 3.4", only: :test, runtime: false},
            # `mix test.watch` - re-runs the unit tier on every save. Available in
            # :test too, because that is the env the task itself runs under.
            {:mix_test_watch, "~> 1.4", only: [:dev, :test], runtime: false}
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
                "test.compile": :test,
                "test.unit": :test,
                "test.integration": :test,
                "test.e2e": :test,
                "test.all": :test,
                # The lifecycle phases and their steps run in the tiers' env also when
                # invoked on their own, so the releases they build are the test ones.
                "pre-integration-test": :test,
                "post-integration-test": :test,
                "pre-e2e-test": :test,
                "post-e2e-test": :test,
                "server.start": :test,
                "server.stop": :test,
                coverage: :test,
                "coverage.xml": :test,
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
    # The integration and e2e tiers are LIFECYCLE PHASES in the Maven failsafe
    # sense - pre-integration-test / integration-test / post-integration-test,
    # and the same for e2e. This file defines only the phases and their
    # contract: every pre step runs before the tier, every post step runs after
    # it, and the post steps ALWAYS run, also when the tier fails (`bracket/3`).
    # What the steps are is the project's business and is declared in
    # lifecycle.exs. Currently they start and stop the deployable apps' OTP
    # releases as daemons (`server.start` / `server.stop` below), so that the
    # tiers - run with `--no-start`, so the test VM brings up no second copy on
    # the same port - exercise the release artifact itself, what gets deployed,
    # and not the code hosted inside the test runner.
    #
    # Each phase is also a task of its own (`mix pre-e2e-test`, ...), for CI
    # that wants each step to be its own line in the build log.
    defp aliases do
        [
            # Compiles the test env - test files included - without running anything, so a
            # warning in a test file fails the build on its own line. A task rather than
            # `MIX_ENV=test mix compile` in CI: an environment prefix is Bourne-shell syntax,
            # and the pipeline must run on a Windows agent too (`bat`).
            "test.compile": ["compile --warnings-as-errors"],
            "test.unit": ["test"],
            "pre-integration-test": Lifecycle.steps(:pre_integration_test),
            "post-integration-test": Lifecycle.steps(:post_integration_test),
            "pre-e2e-test": Lifecycle.steps(:pre_e2e_test),
            "post-e2e-test": Lifecycle.steps(:post_e2e_test),
            "test.integration": [
                bracket([:integration], "test", ["--only", "integration", "--no-start"])
            ],
            "test.e2e": [bracket([:e2e], "test", ["--only", "e2e", "--no-start"])],
            "test.all": [bracket(@tiers, "test", @all_tiers_args)],
            "server.start": [&servers_start/1],
            "server.stop": [&servers_stop/1],
            # --umbrella aggregates every app's stats into one report at the root,
            # which is also the only place ExCoveralls finds coveralls.json (it reads
            # it from the current directory, and per-app runs sit in apps/<name>/).
            # The HTML report is for people (cover/excoveralls.html). coverage.xml is
            # the SonarQube generic test-coverage XML - standalone on purpose:
            # ExCoveralls accumulates stats for the life of one Mix VM, so two
            # coverage runs in one invocation would double-count the second.
            coverage: [bracket(@tiers, "coveralls.html", ["--umbrella" | @all_tiers_args])],
            "coverage.xml": [bracket(@tiers, "coveralls.xml", ["--umbrella" | @all_tiers_args])],
            # Dependency advisories (mix_audit) plus retired/deprecated packages
            # (hex.audit) - the OWASP dependency-check + versions-plugin pair.
            audit: ["deps.audit --ignore-file .mix_audit_ignore", "hex.audit"],
            # Module dependency cycles are a design smell; none are allowed.
            "xref.cycles": ["xref graph --format cycles --fail-above 0"],
            # The tier a test runs in is its TAG; the directory under test/ is
            # readability only. Nothing in ExUnit ties the two together, so this
            # check does - see check_test_tiers/1.
            "test.tiers": [&check_test_tiers/1],
            # CycloneDX SBOM, one per app (each app is its own artifact - Hex package
            # and release), into reports/sbom/<app>.xml, generated from inside each
            # app directory with `-l prod`. Known limitation: the umbrella shares one
            # mix.lock, and the sbom tool resolves it as a whole, so the ROOT's
            # dev/test toolchain (credo, ex_doc, mix_audit, ...) still appears in
            # every app's SBOM; the app's own `only:` deps (sobelow) are filtered
            # correctly. `-r` (the tool's umbrella mode) has the same leak.
            sbom: [&sbom/1],
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
            # Build every app's Hex tarball, and publish them, with HEX_BUILD set for
            # exactly these two runs and nothing else. The variable makes demo_module_c's
            # and demo_module_d's `sibling/2` add the `:hex` option their siblings need to
            # be packageable - which also makes Hex resolve those siblings' OWN deps from
            # the registry, so anything that COMPILES with it set (a plain `mix compile`, a
            # tier, `mix cmd` over the apps) fails. That is why it is not a CI-wide
            # environment variable: `mix cmd` runs each app as a subprocess, which inherits
            # what is set here, so the blast radius stays inside the alias.
            package: [&hex_build/1, "cmd mix hex.build"],
            "package.publish": [&hex_build/1, "cmd mix hex.publish package --yes"],
            quality: [
                "format --check-formatted",
                "compile --warnings-as-errors",
                "credo --strict",
                "dialyzer",
                "xref.cycles",
                "test.tiers",
                "sobelow",
                "audit"
            ]
        ]
    end

    defp hex_build(_args), do: System.put_env("HEX_BUILD", "1")

    @tiers_with_tag %{"integration" => :integration, "e2e" => :e2e}
    @tier_directories ["unit" | Map.keys(@tiers_with_tag)]

    # Which tier a test belongs to is decided by its TAG - `@moduletag
    # :integration` / `:e2e`, excluded by default in each app's
    # test_helper.exs. The directory split under test/ is for readability, and
    # ExUnit knows nothing about it, so the two can silently disagree: a file
    # dropped into test/integration/ without the tag joins the UNIT tier
    # instead. It then runs on every `mix test`, `mix test.integration` never
    # sees it, and nothing goes red - the tier separation quietly stops being
    # true. The reverse is just as bad: a `:e2e` tag on a file in test/unit/
    # takes it out of every default run.
    #
    # This check is what makes the layout binding, and why the tiers can be
    # described as strictly separated rather than merely conventionally so.
    defp check_test_tiers(_args) do
        problems = "apps/*/test/**/*_test.exs" |> Path.wildcard() |> Enum.flat_map(&tier_problems/1)

        if problems == [] do
            Mix.shell().info("Test tiers: directory and @moduletag agree in every test file.")
        else
            Mix.raise("Test tier layout violations:\n\n" <> Enum.join(problems, "\n") <> "\n")
        end
    end

    defp tier_problems(path) do
        case Path.split(path) do
            ["apps", _app, "test", tier | _rest] when tier in @tier_directories ->
                tag_problems(path, tier, File.read!(path))

            _other ->
                ["  #{path}: not under test/#{Enum.join(@tier_directories, "/, test/")}/"]
        end
    end

    defp tag_problems(path, "unit", source) do
        for {directory, tag} <- @tiers_with_tag, tagged?(source, tag) do
            "  #{path}: unit-tier file carries @moduletag #{inspect(tag)}" <>
                " - move it to test/#{directory}/ or drop the tag"
        end
    end

    defp tag_problems(path, tier, source) do
        tag = Map.fetch!(@tiers_with_tag, tier)

        if tagged?(source, tag),
            do: [],
            else: ["  #{path}: missing @moduletag #{inspect(tag)} - it would run in the unit tier"]
    end

    defp tagged?(source, tag), do: Regex.match?(~r/@moduletag\s+#{inspect(tag)}\b/, source)

    # Runs `task` inside the lifecycle of the given tiers: all their pre steps,
    # the task, then all their post steps - the post steps in a `try/after`, so
    # a failing pre step or task (a Mix.raise, a compile error) cannot leave
    # them unrun.
    # (A failing `mix test` itself only records a non-zero exit status; it does
    # not raise, so the post steps run there anyway.) When more than one tier is
    # bracketed, a step shared by their pre (or post) phases runs once.
    defp bracket(tiers, task, task_args) do
        fn args ->
            # The pre steps are inside the try too: a pre step that fails halfway
            # (two daemons up, the third's port never answering) must still be
            # cleaned up by the post steps, which are idempotent.
            try do
                run_steps(tiers, :pre)
                Mix.Task.rerun(task, task_args ++ args)
            after
                run_steps(tiers, :post)
            end
        end
    end

    defp run_steps(tiers, pre_or_post) do
        tiers
        |> Enum.flat_map(&Lifecycle.steps(:"#{pre_or_post}_#{&1}_test"))
        |> Enum.uniq()
        |> Enum.each(&run_step/1)
    end

    defp run_step(fun) when is_function(fun, 1), do: fun.([])

    defp run_step(step) when is_binary(step) do
        [task | args] = OptionParser.split(step)
        Mix.Task.rerun(task, args)
    end

    # One OTP release per deployable app, so a module is deployed on its own
    # rather than as part of one umbrella-wide artifact:
    #
    #     MIX_ENV=live mix release demo_module_a
    #     _build/live/rel/demo_module_a/bin/demo_module_a start
    #
    # `commons` has no release of its own on purpose - it is a library, consumed
    # as the Hex package `setmy_info_commons`, not run.
    # This list also exists, necessarily inline, in config/config.exs (ports),
    # config/test.exs (serve: false) and config/runtime.exs (serve per release);
    # config files cannot read module attributes, so adding an app means all four.
    @deployable_apps [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d]

    # Everything that ships and therefore gets an SBOM and security reports:
    # the deployable apps plus the published libraries.
    @report_apps @deployable_apps ++ [:commons, :formatter]

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
        # `bin/<app> stop` returns as soon as the VM has been told to stop, so
        # wait until each port is actually released before rebuilding on top.
        Enum.each(@deployable_apps, &release_cmd(&1, "stop"))
        Enum.each(@deployable_apps, &wait_for_port_free/1)
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

    defp wait_for_port_free(app, attempts \\ 50) do
        port = Application.fetch_env!(app, :port)

        case :gen_tcp.connect(~c"127.0.0.1", port, [], 200) do
            {:error, _} ->
                :ok

            {:ok, socket} when attempts > 0 ->
                :gen_tcp.close(socket)
                Process.sleep(200)
                wait_for_port_free(app, attempts - 1)

            {:ok, socket} ->
                :gen_tcp.close(socket)
                Mix.raise("port #{port} of #{app} is still in use after stop - something else on it?")
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
    # finding is still a report, and failing on findings is what `mix quality`
    # does. "The tool produced no report at all" is a different thing - an
    # empty or missing file archived as if it were real - and that DOES fail.
    defp security_reports(_args) do
        dir = "reports/security"
        File.mkdir_p!(dir)
        env = [{"MIX_ENV", to_string(Mix.env())}]

        audit_args = ["deps.audit", "--format", "json", "--ignore-file", ".mix_audit_ignore"]
        {audit, _} = System.cmd(mix_executable(), audit_args, env: env)

        if String.trim(audit) == "" do
            Mix.raise("mix deps.audit produced no JSON output - deps_audit.json would be empty")
        end

        File.write!(Path.join(dir, "deps_audit.json"), audit)
        Mix.shell().info("Wrote #{dir}/deps_audit.json")

        for app <- @report_apps do
            out = Path.expand(Path.join(dir, "sobelow-#{app}.json"))

            {output, _} =
                System.cmd(mix_executable(), ["sobelow", "--format", "json", "--out", out],
                    cd: Path.join("apps", to_string(app)),
                    env: env
                )

            unless File.regular?(out) do
                Mix.raise("mix sobelow wrote no report for #{app}:\n#{output}")
            end

            Mix.shell().info("Wrote #{Path.relative_to_cwd(out)}")
        end
    end

    defp sbom(_args) do
        dir = Path.expand("reports/sbom")
        File.mkdir_p!(dir)

        for app <- @report_apps do
            out = Path.join(dir, "#{app}.xml")

            case System.cmd(mix_executable(), ["sbom.cyclonedx", "-f", "-l", "prod", "-o", out],
                   cd: Path.join("apps", to_string(app)),
                   env: [{"MIX_ENV", to_string(Mix.env())}],
                   stderr_to_stdout: true
                 ) do
                {_, 0} ->
                    Mix.shell().info("Wrote #{Path.relative_to_cwd(out)}")

                {output, status} ->
                    Mix.raise("mix sbom.cyclonedx failed for #{app} (exit #{status}):\n#{output}")
            end
        end
    end

    # The tree of the env `reports` runs in (:test) - what CI builds and tests
    # with, dev-only tooling excluded.
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
            # :mix is not a runtime dependency of any app, so it is not in the
            # PLT by default - but the formatter app is the `mix format` plugin
            # (apps/formatter), which implements Mix.Tasks.Format and calls
            # Mix.shell/0.
            plt_add_apps: [:mix],
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
