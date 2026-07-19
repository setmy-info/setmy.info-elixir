# setmy.info-elixir

Monorepo for Elixir, Erlang modules, libraries, applications and API-s.

This repo doubles as a **reference implementation**, the Elixir row of the same system
`setmy.info-js` (Node/npm) and `setmy.info-python` (Python/`venv`+`pip`) already implement: a Mix
**umbrella project** deliberately shaped to mirror the
[Maven default build lifecycle](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html#default-lifecycle),
each app independently versioned and (where Hex actually allows it) separately publishable. See
**ADR-0045** (software build lifecycles, in `setmy-info.github.io`) for the maintained
phase-mapping table across Maven / npm / Python / Elixir / Make, and
`setmy.info-js/requirements-rules.md` for the language-agnostic spec this implements one row of -
that document is deliberately npm-source-free in its normative text.

Maven-closeness is a **soft rule**, same as the npm/Python sides: phase names/ordering are kept for
the context-switching savings, but where a 1:1 imitation would need a hack Mix/Hex don't naturally
support, the natural Elixir way wins and the difference is documented ("Known deliberate
differences" below).

Built from real org precedent, not from ADR-0045 guesses alone: `elixir-start-project/PoC/second`
(a full calculator service, extensively self-audited in its own `PoC/comparision.md`) and
`elixir-start-project/PoC/first` (an umbrella project built around a dynamic module-loading engine,
the ancestor of the real, published `elixir-module-loader` hex package) both already validate the
tooling choices below in this same org. Per the plan this repo was built from, this skeleton is
**minimal demo scope** - small pure-function modules plus one running-instance e2e server per app,
matching `setmy.info-js`/`setmy.info-python`'s own scope, not PoC/second's full REST/GraphQL/Ecto
surface (which stays reference material, see `report.md`).

## Apps

An umbrella project (`apps_path: "apps"`), not a flat single-app repo - in-umbrella deps
(`{:demo_module_a, in_umbrella: true}`) link automatically, so there's no workspace-linking problem
to solve the way npm/`pip` had to.

- `demo_module_a` (Hex package `setmy_info_demo_module_a`) - base app, no local deps
- `demo_module_b` (Hex package `setmy_info_demo_module_b`) - base app, **the typed worked example**
  (§9): full `@spec` coverage, `mix dialyzer` enforced during `validate` because (and only because)
  this app's own `mix.exs` has a `:dialyzer` project key - mirrors the JS side's `tsconfig.json`
  presence / Python's `[tool.mypy]` table presence
- `demo_module_c` - depends on `a` and `b` (`in_umbrella: true`); proves §9.4's typed/untyped
  coexistence
- `demo_module_d` - depends on `c`, the deepest node in the demo graph
- `dev_tasks` - not a demo app, hosts every custom `Mix.Task` phase module (see "Why a dedicated
  `dev_tasks` app" below)

Every demo app has a `priv/web/index.html` demo page, its own configured port
(`config/config.exs`: `48101`/`48111`/`48121`/`48131` for a/b/c/d), and the full
unit/integration/e2e test-tier split, with `Mix.Tasks.Server` starting/stopping a real
`Plug.Cowboy` instance around integration/e2e tests - see "Test pyramid" below.

## Why a dedicated `dev_tasks` app

A custom `Mix.Task` module placed directly under the umbrella root's own `lib/mix/tasks/` is
**not discoverable** by `mix <task>`, even after `mix compile` - confirmed directly with a probe
task before committing to this design, not assumed from Mix's docs. Standard task discovery only
looks at what's compiled as part of a real app; the umbrella root itself is never "compiled" as one.
Custom tasks also do **not** auto-recurse per-app the way built-ins like `mix test`/`mix compile`
do (confirmed with the same probe: it printed once, not four times) - hence
`SetmyInfo.Build.WorkspaceHelper`'s own hand-rolled fan-out logic, used by every phase task.

`apps/dev_tasks` hosts:

- `lib/setmy_info/build/workspace_helper.ex` - umbrella app discovery (`apps/*/mix.exs` glob) +
  topological sort (Kahn's algorithm) + `demo_apps_in_order/1`, the Elixir equivalent of
  `workspace-utils.js`/`workspace_utils.py`
- `lib/setmy_info/build/profile_helper.ex` - ADR-0041/0042 canonical profile validation + root/app
  YAML merge, the equivalent of `profile-utils.js`/`profile_utils.py`
- `lib/setmy_info/build/static_server_plug.ex` - wraps `Plug.Static` with a `/` → `index.html`
  rewrite (`Plug.Static` doesn't map bare `/` on its own) and a 404 fallback
- `lib/mix/tasks/*.ex` - one `Mix.Task` module per §2 phase not already covered by a built-in or an
  alias (resources, server, pre/post-integration-test, pre/post-e2e-test, verify, package, sbom,
  sign, install_local, publish, deploy, validate, site, security)

## Workspace tooling: Mix umbrella, real org precedent

- **Bootstrap**: `mix deps.get` at the umbrella root - genuinely simpler than JS/Python here, no
  "which interpreter/package manager" ambiguity to solve; Mix deps live in the project's own
  `deps/`/`_build/`, not a global store.
- **Custom phase commands**: a mix of real `Mix.Task` modules (`dev_tasks`) and root `mix.exs`
  aliases (`test.unit`/`test.integration`/`test.e2e`/`tooling_test`/`coverage`) - aliases were
  required specifically for the `test.*` names because they collide with `mix test`'s own built-in
  alias-resolution/umbrella-recursion behavior in a way a plain `Mix.Task` module doesn't reliably
  intercept (confirmed directly, not assumed - see `mix.exs`'s own comment on this).
- **Resource/profile filtering** (§6): `Mix.Tasks.Resources` + YAML profiles
  (`profiles/<name>.yaml`), the same `${propertyName}` substitution and the same YAML choice as the
  Python side (confirmed as the org's real convention via `python-commons`'s PyYAML dependency and
  `elixir-module-loader`'s own config shape) - decoupled from Mix's own env system, same as the
  npm/Python sides keep resource profiles independent of `NODE_ENV`/no stdlib env concept.

## Lifecycle

Run from the repository root, in order:

```sh
mix deps.get                                                      # bootstrap
mix clean
mix validate                                                      # structural + dialyzer (demo_module_b)
mix format --check-formatted                                      # or: mix format to auto-fix
mix credo --strict
mix resources --profile local                                     # local|dev|ci|test|prelive|live
mix compile --warnings-as-errors
mix tooling_test                                                  # build tooling's own tests, §7.7
mix test.unit
mix pre_integration_test
mix test.integration
mix post_integration_test
mix pre_e2e_test
mix test.e2e
mix post_e2e_test
mix coverage                                                      # ExCoveralls, unit-test-scoped
mix security                                                      # Sobelow per app + deps.audit
mix verify
mix package                                                       # mix hex.build; skips c, d (see below)
mix sbom
mix sign
mix install_local                                                 # repurposed - see below
mix publish                                                       # dry-run (mix hex.build) unless HEX_API_KEY set
mix deploy --target dev                                           # dev|test|prelive|live
mix site                                                           # mix docs + aggregated report index
```

This whole sequence has been run clean, end to end, on this machine (Elixir 1.19.5 / Erlang OTP
29), across the full mixed typed/untyped app graph, including real HTTP e2e requests against every
app's own running instance. See `report.md` for the bugs that surfaced while verifying it and how
they were fixed.

`Jenkinsfile` runs this same sequence in CI, same stage skeleton as `setmy.info-js`/
`setmy.info-python`'s own `Jenkinsfile` (Inspection → Preparation → Build → E2E →
Quality/reporting → System/Acceptance → Package → Publish → Deploy → Tag), same branch-gated
Publish/Deploy pattern (`master` / `devel*` / `release*`). **No GitHub Actions workflow** -
deliberate divergence from both real PoCs (which each carry their own `.github/workflows/ci.yml`):
`setmy.info-js`'s own `ci.yml` was deleted after repeated DAG-scheduling bugs, and
`setmy.info-python` never got one; `Jenkinsfile` + `ci-local/` is this system's one working CI
layer across all three languages.

### Emulating CI locally, without Jenkins

`ci-local/` runs the exact same commands the `Jenkinsfile` runs, in the same order, as plain POSIX
`sh` scripts - same shape as the npm/Python sides:

```sh
ci-local/run.sh                    # picks the case from the current git branch
ci-local/run.sh some-branch-name   # or pass a branch name explicitly

ci-local/feature-branch.sh   # Inspection..Package only, nothing branch-gated
ci-local/devel-branch.sh     # + Publish/Snapshot, Deploy/dev, Deploy/test
ci-local/release-branch.sh   # + Deploy/dev, Deploy/test, Deploy/prelive (no Publish - see below)
ci-local/master-branch.sh    # + Publish/Release, Deploy/live, Tag
```

All four cases have been run against this repo and pass clean. `release-branch.sh` faithfully
reproduces the same real quirk the npm/Python sides' equivalents have: a `release*` branch name
doesn't match either Publish `when` condition (`Release` needs `branch 'master'` exactly,
`Snapshot` needs `startsWith('devel')`), so real Jenkins runs no Publish stage at all on a release
branch, and neither does `Mix.Tasks.Publish` (an earlier version of its branch check incorrectly
included `release*` - caught and fixed while writing `release-branch.sh`, see `report.md`).

## Publish / Deploy (prepared, not wired to a real target yet)

`Mix.Tasks.Publish` never calls real `mix hex.publish` unless `HEX_API_KEY` is set - confirmed
directly, not assumed from the flag name, that `mix hex.publish --dry-run --yes` still tries to
authenticate/prompt before reaching its "no publish" behavior, and hangs indefinitely with no TTY
(`--yes` only skips the confirm-to-publish prompt, not the authenticate-now one). The safe default
path reuses `mix hex.build` instead (Package's own local-only validation) and just logs what
branch/app would have published.

`Mix.Tasks.Deploy` requires `--target` to be one of `dev`/`test`/`prelive`/`live` and writes a
`.deploy/<dist-name>/<target>/deploy.json` descriptor with `status: "prepared-not-executed"` - same
as the npm/Python sides, no real target infrastructure exists yet.

### `install-local`, repurposed

Same repurposing as the Python side: installs the *packaged* `.tar` (Package's actual output) plus
every transitive in-umbrella-sibling tarball into a disposable scratch Mix project as path
dependencies, and confirms it compiles and the public API resolves. Elixir doesn't need this for
umbrella siblings themselves (`in_umbrella: true` already links them at dev time automatically),
but it still catches packaging bugs (missing `priv/` files, a wrong file list) the same way the
Python side's own repurposing does, since dev-time compilation never exercises a package's declared
file-inclusion rules the way installing the actual tarball does.

### Package: `demo_module_c`/`demo_module_d` are structurally excluded

`mix hex.build` fails outright for any app with `in_umbrella: true` deps: *"Dependencies excluded
from the package (only Hex packages can be dependencies): demo_module_a, demo_module_b"* - a real,
unfixable-by-engineering constraint of Hex itself, not a bug in this build. `Mix.Tasks.Package`
detects apps with local deps and skips them with a clear log line instead of silently failing or
hiding the constraint - `demo_module_a`/`demo_module_b` (no local deps) package normally.

## Test pyramid

- `test/unit/*_test.exs` - fast, in-process
- `test/integration/*_test.exs` - against the public API surface only, same divergence rationale as
  the Python side
- `test/e2e/*_test.exs` - **and** at least one test per app makes a real HTTP request (via `:inets`
  `httpc`) against a real running instance (§7.5), started by `mix pre_integration_test`/
  `mix pre_e2e_test` via `Mix.Tasks.Server` + `Plug.Cowboy`

`apps/dev_tasks/test/unit` and `apps/dev_tasks/test/integration` are the build tooling's own tests
(§7.7): `workspace_helper_test.exs`/`profile_helper_test.exs` are pure in-process calls;
`server_test.exs` spawns a real `mix server start`/`stop` subprocess and makes a real HTTP request
against it. Run via `mix tooling_test`.

## Site (reports)

`mix site` runs `mix docs` (ExDoc, `output: "docs"`, `main: "readme"`) and writes
`docs/reports/index.html` linking the lint report (`mix credo --strict`, rendered), the security
report (`mix security`'s own Sobelow+`deps.audit` output), and the dependency tree
(`mix deps.tree`) - all **shared across the whole umbrella**, not per-app, since there's one shared
`deps/`/`_build/` and one `mix.lock`, not one environment per app - same reasoning the Python side's
own shared-report choice documents.

## Known deliberate differences from `setmy.info-js` / `setmy.info-python` / Maven

- **SBOM is a hand-rolled CycloneDX-shaped JSON placeholder**, explicitly labeled as such (§11.2
  allows this) - no actively-maintained real CycloneDX generator exists for Hex/Mix, unlike the
  Python side which got a real generator (`cyclonedx-py`) because one exists.
- **Sign** is still a SHA-256 checksum placeholder, same as the npm/Python sides - no real signature
  infrastructure exists anywhere in this system yet.
- **`demo_module_c`/`demo_module_d` never produce a Hex package** - see "Package" above, a real Hex
  constraint, not a gap in this build.
- **`dialyxir` (demo_module_b only) and `sobelow` (all four demo apps) are declared per-app, not at
  the umbrella root** - `mix dialyzer`/`mix sobelow` resolve task visibility against the *current
  project's own* `deps()` when run with `cd:` set to a specific app's path, not the shared root
  `deps/` folder contents; confirmed directly by hitting "task not found" with only a root-level
  declaration.
- **Coverage is unit-test-scoped only** (`coverage:` alias, not bare `mix coveralls`) - ExUnit
  auto-discovers every test under `test/**`, so a bare `mix coveralls` at the root pulls in e2e
  tests too and fails with connection-refused unless every app's e2e server happens to already be
  running; same scope the JS/Python coverage phases already use.
- **Publish/Deploy** stay in "prepared, not executed" mode until real registry credentials/target
  infrastructure exist - required by the spec itself (§10), not a gap.
