# setmy.info-elixir

Monorepo for Elixir, Erlang modules, libraries, applications and API-s.

A plain **Mix umbrella project**: every app is independently versioned, independently published to Hex, and
independently deployable as its own OTP release. There is no custom build system on top of Mix — the commands below are
the ones any Elixir developer already knows.

Built from real org precedent: `elixir-start-project/PoC/second` (a full calculator service) and
`elixir-start-project/PoC/first` (an umbrella project built around a dynamic module-loading engine, the ancestor of the
published `elixir-module-loader` hex package) both validate the tooling choices below in this same org. The demo scope
is deliberately small — pure-function modules plus one HTTP endpoint per app — not PoC/second's full REST/GraphQL/Ecto
surface.

## Apps

An umbrella project (`apps_path: "apps"`), not a flat single-app repo. In-umbrella deps link automatically, so there is
no workspace-linking problem to solve the way npm/`pip` had to.

- `commons` (Hex `setmy_info_commons`) — **not a demo app**: the real, reusable library of this repo, Spring Boot style
  layered application configuration. The Elixir row of `clj-commons` and `python-commons` (see "Application
  configuration" below). A library: no supervision tree, no port.
- `demo_module_a` (Hex `setmy_info_demo_module_a`) — base app, no local deps
- `demo_module_b` (Hex `setmy_info_demo_module_b`) — the typed worked example: full `@spec` coverage
- `demo_module_c` (Hex `setmy_info_demo_module_c`) — depends on `a` and `b`; typed and untyped code side by side
- `demo_module_d` (Hex `setmy_info_demo_module_d`) — depends on `c`, the deepest node in the demo graph

Each demo app is a real OTP application: its `mod:` callback starts a supervision tree with one `Plug.Cowboy` endpoint
serving that app's `priv/web/index.html` on its own port (`48101`/`48111`/`48121`/`48131` for a/b/c/d, set in
`config/config.exs`). Anything that starts the application gets the endpoint — `iex -S mix`, `mix run --no-halt`, or the
release. In the integration and e2e tiers, though, the test VM runs with `--no-start` and the HTTP requests go to the
release daemons brought up by the pre steps of `lifecycle.exs` (see "Tests").

## Getting started

```sh
mix deps.get
mix compile
mix test              # unit tier
mix format            # reformat in place - run before every commit
iex -S mix            # all four endpoints up; http://127.0.0.1:48101/
```

Indentation is **4 spaces**, like the rest of setmy.info (`.editorconfig`). Elixir's formatter has no width option and
always emits 2, so `formatter_indent.exs` is a `mix format` plugin that runs the stock formatter and then widens each
nesting level to 4 (alignment of wrapped continuation lines and heredoc contents are left as they are). It is loaded by
the root and per-app `.formatter.exs` files with `Code.require_file`, so `mix format` and `mix format --check-formatted`
both mean the 4-space form everywhere — editors, the pre-commit hook and CI included — and nothing needs compiling.

Formatting is a **local** concern: `mix format` rewrites the files, and CI only verifies with
`mix format --check-formatted` (a reformat in CI would leave changes in the Jenkins workspace that are never committed,
and the check could then never fail). Turn on format-on-save in your editor (ElixirLS / Lexical both do it), or add a
pre-commit hook:

```sh
printf '#!/bin/sh\nmix format --check-formatted\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Application configuration (`commons` / Hex `setmy_info_commons`)

The Elixir row of `clj-commons` (`info.setmy.*`) and `python-commons` (`smi_python_commons.*`), implementing the
architecture index's **"Application configuration"** overload order in full. Clojure is the base implementation -
`config/application.clj` landed 2023-09-07, `application.py` 2023-10-06 as a faithful port of it - so where the two
disagree, Clojure is followed and the choice is stated in the module that makes it.

Module names, function names and argument order are kept one-to-one with both:

| Elixir                                                                           | clj-commons / python-commons        |
|----------------------------------------------------------------------------------|-------------------------------------|
| `SetmyInfo.Commons.Config.Application`                                           | `config.application`                |
| `SetmyInfo.Commons.Config.Constants`                                             | `config.constants`                  |
| `SetmyInfo.Commons.Config.Overrides`                                             | *(new in this row)*                 |
| `SetmyInfo.Commons.Arguments.{Argument,Config,Constants,ParsedArguments,Parser}` | `arguments.*`                       |
| `SetmyInfo.Commons.Environment.Variables`                                        | `environment.variables`             |
| `SetmyInfo.Commons.{Yaml,Json}.Parser`                                           | `yaml.parser`, `json.parser`        |
| `SetmyInfo.Commons.{String,File,Collection}.Operations`                          | `string/file/collection.operations` |

### Overload order

Each layer overrides the one above it:

1. `application.{json,yml,yaml}` from each config path, in order
2. `application-<profile>.{json,yml,yaml}` for each active profile
3. optional files from `SMI_OPTIONAL_CONFIG_FILES`, then from `--smi-optional-config-files`
4. `${ENV_VAR}` placeholders inside those files, resolved *before* parsing, so
   `port: ${PORT}` with `PORT=8080` yields the integer `8080`
5. environment variables - `SMI_SERVER_PORT` overrides `smi.server.port`
6. CLI options - `--smi-server-port 9090` overrides both

```sh
SMI_SERVER_PORT=9090 my_service --smi-profiles dev --smi-server-port 9091
```

Files merge **deeply**. The `smi:` / `SMI_` / `--smi-` prefixes are the index's own table.

### Two deliberate divergences from the older two rows

- **`local` is the default active profile.** Both older rows default to no profile at all. ADR-0041 makes `local` the
  canonical developer-machine environment and ADR-0042 binds profile names to it one-to-one, so it is the only default
  that can be right without being told. Override with `SMI_PROFILES` / `--smi-profiles`, or opt out with
  `default_profiles: []`.
- **Environment and CLI override arbitrary configuration values** (`SetmyInfo.Commons.Config.Overrides`). Neither older
  row implements this layer - both stop at `${ENV_VAR}` substitution plus the four
  `SMI_*` control variables, so the index's documented "environment, then CLI" rows were never actually reached there.
  Only *existing* leaf paths under the `smi` root are overridable, and an override is coerced to the type of the value
  it replaces; see the module's own docs for why inventing keys and allowing every root key are both off by default.

## Tests

Three tiers, run one by one:

```sh
mix test.unit          # == mix test; the default, fastest tier
mix test.integration
mix test.e2e
mix test.all           # all three in one run
```

Tiers are **ExUnit tags**, not path lists. Each app's `test_helper.exs` ends with
`ExUnit.start(exclude: [:integration, :e2e])`, and every module in `test/integration/` or `test/e2e/` carries the
matching `@moduletag`. That keeps `mix test`'s own umbrella recursion doing the work — adding or removing an app needs
no change anywhere — and makes a bare `mix test` the fast one. The directory split under `test/` is kept for
readability.

### Running exactly one tier, file or test

The tier is chosen by tag, the scope by path (from the umbrella root — Mix maps `apps/<name>/...` to the right app)
and, optionally, a `:line` suffix for one test:

```sh
mix test                                                        # unit tier, every app
mix test apps/demo_module_c/test/unit/demo_probe_test.exs       # unit tier, one file
mix test apps/demo_module_c/test/unit/demo_probe_test.exs:10    # one test, by line

mix pre-integration-test                                        # integration tier needs the instances up
mix test --only integration --no-start                          # every app
mix test apps/demo_module_c/test/integration/demo_module_c_test.exs --only integration --no-start
mix post-integration-test

mix pre-e2e-test                                                # e2e: the same shape
mix test apps/demo_module_c/test/e2e/demo_probe_e2e_test.exs --only e2e --no-start
mix post-e2e-test
```

`--only <tag>` is what lets the excluded tier back in for that run, and `--no-start` keeps the test VM from opening
the ports the daemons already hold. A file under `test/integration/` or `test/e2e/` without the matching
`--only` runs nothing ("All tests have been excluded"). The pre and post phases are explained next.

### Integration and e2e run against real running instances

The integration and e2e tiers are **lifecycle phases** in the Maven failsafe sense:

```
pre-integration-test  →  integration-test  →  post-integration-test
pre-e2e-test          →  e2e-test          →  post-e2e-test
```

The umbrella's `mix.exs` defines only the phases and their contract: every pre step runs before the tier, every post
step runs after it, and the post steps **always** run — also when the tier fails. **What** the pre and post steps do is
the project's business and is declared in one place, **`lifecycle.exs`**, as a list of steps per phase (a Mix task
invocation as a string, or a function). From the point of view of the tiers and of CI there is only "pre" and "post";
a project built on this umbrella puts whatever its tiers need there — a database, a broker, a mock of a third-party
API, seed data — next to or instead of the current steps.

Currently the steps are `server.start` / `server.stop`: build every deployable app's OTP release for the test env and
start it as a daemon, and stop the daemons again (idempotent). The tiers run with `--no-start`, so the test VM brings
up no second copy on the same port. What the tiers exercise is therefore the **release artifact** — what gets deployed
— not code hosted inside the test runner. `server.start` waits until every port answers, and first stops anything a
previous aborted run left behind.

```sh
mix test.e2e              # == pre-e2e-test, mix test --only e2e --no-start, post-e2e-test
mix pre-e2e-test          # each phase is also a task of its own, for a CI log with one line per step
mix test --only e2e --no-start
mix post-e2e-test
```

`mix test.integration` / `mix test.e2e` / `mix test.all` / `mix coverage` are the bracketed tiers; when one run covers
both tiers, a step shared by their pre (or post) phases runs once.

Inside a release only the release's own app opens its endpoint: `demo_module_c`'s release also starts `a` and `b`
(Mix will not let a `:permanent` app's dependencies be merely loaded), but there they are libraries, and a second copy
of `a`'s endpoint next to `a`'s own release would fail with `:eaddrinuse`. `config/runtime.exs` switches
`serve: false` for every app except `RELEASE_NAME`; under Mix every app serves.

Every run also writes **JUnit XML**, one file per app, to `reports/junit/` (`junit_formatter`, wired in each app's
`test_helper.exs`, directory pinned in `config/test.exs`) — what Jenkins' `junit` step reads. The file name comes from
`JUNIT_REPORT_FILE` (default `test-junit-report.xml`), so CI gives every tier its own file instead of overwriting the
previous tier's.

`mix test.watch` (`mix_test_watch`) re-runs the unit tier on every save during development.

- `test/unit/` — fast, in-process, no files, no environment, no network
- `test/integration/` — the public API surface, config files, environment variables
- `test/e2e/` — the library or app driven end to end; for each demo app that includes real HTTP requests (`:httpc`)
  against its own running endpoint

`commons` splits its tiers by **ADR-0031's dependency table** rather than by speed: unit tests are in-memory only,
anything reading a config file or an environment variable is integration tier, and the e2e tier drives the whole library
as a real application would (including a scenario-for-scenario port of `python-commons`' `behave` feature,
ExUnit-shaped — see `apps/commons/test/e2e/environment_variables_test.exs` for why no Cucumber runner).

## Quality tooling

```sh
mix quality            # everything below, in order, as one gate
```

| Command                            | Tool                        | What it checks                                        |
|------------------------------------|-----------------------------|-------------------------------------------------------|
| `mix format --check-formatted`     | Elixir formatter            | formatting                                            |
| `mix compile --warnings-as-errors` | compiler                    | warnings, type errors                                 |
| `mix credo --strict`               | Credo                       | style, consistency, refactoring opportunities         |
| `mix dialyzer`                     | Dialyxir                    | success typing, across the whole umbrella             |
| `mix xref.cycles`                  | `mix xref`                  | module dependency cycles (none allowed)               |
| `mix sobelow`                      | Sobelow                     | static security analysis, per app                     |
| `mix audit`                        | mix_audit + `mix hex.audit` | dependency vulnerability advisories, retired packages |

All of them are **gates** — each fails on a finding. The **documents** are produced separately:

```sh
mix reports            # everything below, in one go
```

| Command                   | Tool               | Output                                                                                                                                                                                                                                                             |
|---------------------------|--------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `mix docs`                | ExDoc              | API documentation, `doc/`                                                                                                                                                                                                                                          |
| `mix coverage`            | ExCoveralls        | **test coverage** — every tier (unit, integration, e2e), HTML for people, `cover/excoveralls.html`; the build fails below `minimum_coverage` (90 %, `coveralls.json`)                                                                                              |
| `mix coverage.xml`        | ExCoveralls        | the same as SonarQube generic coverage XML, `cover/excoveralls.xml` (standalone, not part of `mix reports`: ExCoveralls accumulates stats per Mix VM, so two coverage runs in one invocation would double-count)                                                   |
| `mix sbom`                | sbom               | CycloneDX software bill of materials, one per app (each is its own artifact), `reports/sbom/<app>.xml`; `-l prod` scope, with one known leak: the umbrella root's own dev/test toolchain is listed too, because the tool resolves the shared `mix.lock` as a whole |
| `mix security.reports`    | mix_audit, Sobelow | vulnerability reports as JSON, `reports/security/`                                                                                                                                                                                                                 |
| *(part of `mix reports`)* | `mix deps.tree`    | dependency tree, `reports/deps.tree.txt`                                                                                                                                                                                                                           |
| every `mix test*` run     | junit_formatter    | JUnit XML per app, `reports/junit/`                                                                                                                                                                                                                                |

Notes on the two that are not simply the stock invocation:

- **`mix sobelow`** is an alias for `mix cmd mix sobelow --exit medium`. Sobelow refuses to run against an umbrella root
  ("each application should be scanned separately"), so it is fanned out over `apps/*` with Mix's own `cmd`
  recursion, and it is declared in each app's `deps` rather than at the root — a task's binary only resolves against the
  current project's own dependencies. `--exit medium` gates on medium- and high-confidence findings: reading a
  caller-supplied config path is `commons`' entire job, and Sobelow reports that as a low-confidence
  `Traversal.FileModule` finding. It stays printed; it does not fail the build.
- **`mix coverage`** is `mix coveralls.html --umbrella --include integration --include e2e --no-start`, bracketed by
  the pre and post steps of both tiers (`lifecycle.exs`) like the tiers it runs. `--umbrella` aggregates every app into
  one report at the root, which is also the only place ExCoveralls looks for `coveralls.json` (it reads it from the
  current directory, and per-app runs happen inside `apps/<name>/`). Each app declares
  `test_coverage: [tool: ExCoveralls]` itself — without it, `mix test --cover` silently falls back to Mix's built-in
  cover tool for that app.

Two ignore lists, one per audit tool, same discipline — each entry documents why a finding is accepted and when it must
be re-reviewed, never a blanket suppression: `.mix_audit_ignore` for mix_audit, and `hex: [ignore_advisories:]`
in `mix.exs` for `mix hex.audit` (Hex's own advisory database is broader, so it can list what mix_audit does not).

## Publishing — one package per app

Every app publishes to Hex separately, with `mix hex.publish package` run from that app's own directory:

```sh
cd apps/demo_module_a
HEX_BUILD=1 mix hex.build          # inspect the tarball first
HEX_BUILD=1 mix hex.publish package
```

Or every app at once, from the umbrella root: `HEX_BUILD=1 mix cmd mix hex.build`. Use `mix hex.publish package`
rather than bare `mix hex.publish` from an app directory: the bare form also builds docs, and `ex_doc` is declared at
the umbrella root only.

### Why `HEX_BUILD`

`demo_module_c` and `demo_module_d` depend on umbrella siblings. Hex refuses to package a dependency that carries any
SCM key (`:git`, `:github`, `:path`, `:in_umbrella`) unless it also carries `:hex` naming the published package —
without it, `mix hex.build` stops with *"Dependencies excluded from the package (only Hex packages can be
dependencies)"*.

That `:hex` option cannot simply be left on permanently: it makes Hex resolve the sibling's **own** dependencies from
the registry instead of from its `mix.exs`, so `mix compile` run from inside a dependent app's directory then fails to
compile the sibling. So the option is added only when `HEX_BUILD` is set — see the `sibling/2` helper in
`apps/demo_module_c/mix.exs`. Day-to-day development never sets it.

## Deploying — one release per app

Each demo app has its own OTP release:

```sh
MIX_ENV=live mix release demo_module_a
_build/live/rel/demo_module_a/bin/demo_module_a start
```

`mix release.all` builds every one of them for the current `MIX_ENV` (`mix release` requires a name when more than one
release is configured). `commons` has no release: it is a library, consumed as a Hex package, not run.

Mix environments follow **ADR-0041**'s canonical names — `local`, `dev`, `ci`, `test`, `prelive`, `live` — each with its
own `config/<env>.exs`, plus `config/runtime.exs` for values that must come from the environment at boot.

## CI

`Jenkinsfile` is the single CI definition, kept stage-for-stage in sync with `jenkinsfile-starter` 1.2.0 (no stages
added or removed; the starter's learning-example steps are left out, the placeholders filled): Inspection (pre-build
checks ‖ build tools) → Preparation (`mix deps.get`, `mix deps.unlock --check-unused`) → Build → Publish → Deploy → Tag,
with the org's standard branch gating (`master` / `devel*` / `release*` / `hotfix*`). The Build stage runs, in order:
`mix clean`, format check, compile and test-compile (`MIX_ENV=test`) with warnings as errors, the unit tier, the
integration tier bracketed by
`mix pre-integration-test` / `mix post-integration-test`, the quality gates, `mix reports`, the e2e tier bracketed by
`mix pre-e2e-test` / `mix post-e2e-test`, and
`HEX_BUILD=1 mix cmd mix hex.build`. Each is its own `mix` line, so the build log names what failed. `post { always }`
runs both post phases again for anything a failed tier left behind, feeds `reports/junit/*.xml` to Jenkins' `junit`
step and archives
`cover/`, `doc/`, `reports/` and the tarballs. Publish (`master` only — Hex has no snapshots, a version publishes
exactly once, so `devel*` keeps its tarballs as archived artifacts) runs
`HEX_BUILD=1 mix cmd mix hex.publish package --yes` when
`HEX_API_KEY` is set (`package`, because the bare form also builds docs with `ex_doc`, a root-only dependency an app
directory cannot see); Deploy builds the releases with `mix release.all --overwrite` for the target `MIX_ENV`. No GitHub
Actions workflow.

### Hotfix branches (`hotfix*`)

A `hotfix*` branch — branched from `master`, one fix, quick review — is a first-class branch case. "Quick" is the human
review, never the pipeline: a hotfix runs the exact same Inspection → Build path as every other branch (all test tiers,
quality, packaging), is not published (only `master` publishes to Hex; `devel*` merely archives its tarballs), and
deploys to `test` and `prelive` (`HOTFIX_TO_TEST` / `HOTFIX_TO_PRELIVE`). It never deploys `dev` or `live` and never
tags — merging it to `master` is what does that, through the normal master build.
