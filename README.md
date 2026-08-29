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
`config/config.exs`). Anything that starts the application gets the endpoint — `iex -S mix`, `mix run --no-halt`,
`mix test`, or the release — which is why the e2e tests can just make HTTP requests without anything starting a server
around them.

## Getting started

```sh
mix deps.get
mix compile
mix test              # unit tier
iex -S mix            # all four endpoints up; http://127.0.0.1:48101/
```

## Application configuration (`commons` / Hex `setmy_info_commons`)

The Elixir row of `clj-commons` (`info.setmy.*`) and `python-commons` (`smi_python_commons.*`), implementing the
architecture index's **"Application configuration"** overload order in full. Clojure is the base implementation -
`config/application.clj` landed 2023-09-07, `application.py`
2023-10-06 as a faithful port of it - so where the two disagree, Clojure is followed and the choice is stated in the
module that makes it.

Module names, function names and argument order are kept one-to-one with both:

| Elixir                                                           | clj-commons / python-commons        |
|------------------------------------------------------------------|-------------------------------------|
| `SetmyInfo.Commons.Config.Application`                           | `config.application`                |
| `SetmyInfo.Commons.Config.Constants`                             | `config.constants`                  |
| `SetmyInfo.Commons.Config.Overrides`                             | *(new in this row)*                 |
| `SetmyInfo.Commons.Arguments.{Argument,Config,Constants,Parser}` | `arguments.*`                       |
| `SetmyInfo.Commons.Environment.Variables`                        | `environment.variables`             |
| `SetmyInfo.Commons.{Yaml,Json}.Parser`                           | `yaml.parser`, `json.parser`        |
| `SetmyInfo.Commons.{String,File,Collection}.Operations`          | `string/file/collection.operations` |

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

Tiers are **ExUnit tags**, not path lists. Each app's `test_helper.exs` starts with
`ExUnit.start(exclude: [:integration, :e2e])`, and every module in `test/integration/` or `test/e2e/` carries the
matching `@moduletag`. That keeps `mix test`'s own umbrella recursion doing the work — adding or removing an app needs
no change anywhere — and makes a bare `mix test` the fast one. The directory split under `test/` is kept for
readability.

- `test/unit/` — fast, in-process, no files, no environment, no network
- `test/integration/` — the public API surface, config files, environment variables
- `test/e2e/` — the library or app driven end to end; for each demo app that includes real HTTP requests
  (`:httpc`) against its own running endpoint

`commons` splits its tiers by **ADR-0031's dependency table** rather than by speed: unit tests are in-memory only,
anything reading a config file or an environment variable is integration tier, and the e2e tier drives the whole library
as a real application would (including a scenario-for-scenario port of `python-commons`' `behave` feature, ExUnit-shaped
— see `apps/commons/test/e2e/environment_variables_test.exs` for why no Cucumber runner).

## Quality tooling

```sh
mix quality            # everything below, in order, as one gate
```

| Command | Tool | What it checks |
|---|---|---|
| `mix format --check-formatted` | Elixir formatter | formatting |
| `mix compile --warnings-as-errors` | compiler | warnings, type errors |
| `mix credo --strict` | Credo | style, consistency, refactoring opportunities |
| `mix dialyzer` | Dialyxir | success typing, across the whole umbrella |
| `mix sobelow` | Sobelow | static security analysis, per app |
| `mix audit` | mix_audit | dependency advisories |
| `mix coverage` | ExCoveralls | aggregated coverage, HTML report in `cover/` |
| `mix docs` | ExDoc | API documentation in `doc/` |

Notes on the two that are not simply the stock invocation:

- **`mix sobelow`** is an alias for `mix cmd mix sobelow --exit medium`. Sobelow refuses to run against an umbrella
  root ("each application should be scanned separately"), so it is fanned out over `apps/*` with Mix's own `cmd`
  recursion, and it is declared in each app's `deps` rather than at the root — a task's binary only resolves against
  the current project's own dependencies. `--exit medium` gates on medium- and high-confidence findings: reading a
  caller-supplied config path is `commons`' entire job, and Sobelow reports that as a low-confidence
  `Traversal.FileModule` finding. It stays printed; it does not fail the build.
- **`mix coverage`** is `mix coveralls.html --umbrella --include integration --include e2e`. `--umbrella` aggregates
  every app into one report at the root, which is also the only place ExCoveralls looks for `coveralls.json` (it reads
  it from the current directory, and per-app runs happen inside `apps/<name>/`). Each app declares
  `test_coverage: [tool: ExCoveralls]` itself — without it, `mix test --cover` silently falls back to Mix's built-in
  cover tool for that app.

`.mix_audit_ignore` is the per-advisory escape hatch for `mix audit`: each entry documents why a finding is accepted
and when it must be re-reviewed. It is not a blanket suppression.

## Publishing — one package per app

Every app publishes to Hex separately, with `mix hex.publish` run from that app's own directory:

```sh
cd apps/demo_module_a
HEX_BUILD=1 mix hex.build          # inspect the tarball first
HEX_BUILD=1 mix hex.publish
```

Or every app at once, from the umbrella root: `HEX_BUILD=1 mix cmd mix hex.build`.

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

`Jenkinsfile` is the single CI definition: Inspection → Build → Unit tests → Integration tests → E2E tests → Quality
(format/lint, types, security in parallel) → Coverage and docs → System/Acceptance → Package → Publish → Deploy → Tag,
with the org's standard branch gating (`master` / `devel*` / `release*` / `hotfix*`). The three test tiers are separate
stages on purpose, so a failure names the tier it happened in. No GitHub Actions workflow.

### Hotfix branches (`hotfix*`)

A `hotfix*` branch — branched from `master`, one fix, quick review — is a first-class branch case. "Quick" is the human
review, never the pipeline: a hotfix runs the exact same Inspection → Package path as every other branch (all test
tiers, quality, packaging), is publish-eligible like `master`/`devel*` so the exact build under review can be
installed, and deploys to `test` and `prelive` (`HOTFIX_TO_TEST`/`HOTFIX_TO_PRELIVE`; `HOTFIX_TO_DEV` is `SKIP` by
default). It never deploys `live` and never tags — merging it to `master` is what does that, through the normal master
build.
