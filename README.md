# setmy.info-elixir

Monorepo for Elixir, Erlang modules, libraries, applications and API-s.

This repo doubles as a **reference implementation**, the Elixir row of the same system
`setmy.info-js` (Node/npm) and `setmy.info-python` (Python/`venv`+`pip`) already implement: a Mix **umbrella project**
deliberately shaped to mirror the
[Maven default build lifecycle](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html#default-lifecycle),
each app independently versioned and (where Hex actually allows it) separately publishable. See **ADR-0045** (software
build lifecycles, in `setmy-info.github.io`) for the maintained phase-mapping table across Maven / npm / Python /
Elixir / Make, and
`setmy.info-js/requirements-rules.md` for the language-agnostic spec this implements one row of - that document is
deliberately npm-source-free in its normative text.

Maven-closeness is a **soft rule**, same as the npm/Python sides: phase names/ordering are kept for the
context-switching savings, but where a 1:1 imitation would need a hack Mix/Hex don't naturally support, the natural
Elixir way wins and the difference is documented ("Known deliberate differences" below).

Built from real org precedent, not from ADR-0045 guesses alone: `elixir-start-project/PoC/second`
(a full calculator service, extensively self-audited in its own `PoC/comparision.md`) and
`elixir-start-project/PoC/first` (an umbrella project built around a dynamic module-loading engine, the ancestor of the
real, published `elixir-module-loader` hex package) both already validate the tooling choices below in this same org.
Per the plan this repo was built from, this skeleton is **minimal demo scope** - small pure-function modules plus one
running-instance e2e server per app, matching `setmy.info-js`/`setmy.info-python`'s own scope, not PoC/second's full
REST/GraphQL/Ecto surface (which stays reference material, see `report.md`).

## Apps

An umbrella project (`apps_path: "apps"`), not a flat single-app repo - in-umbrella deps
(`{:demo_module_a, in_umbrella: true}`) link automatically, so there's no workspace-linking problem to solve the way
npm/`pip` had to.

- `commons` (Hex package `setmy_info_commons`) - **not a demo app**: the real, reusable library of this repo, Spring
  Boot style layered application configuration. The Elixir row of `clj-commons`
  and `python-commons` (see "Application configuration" below)
- `demo_module_a` (Hex package `setmy_info_demo_module_a`) - base app, no local deps
- `demo_module_b` (Hex package `setmy_info_demo_module_b`) - base app, **the typed worked example**
  (§9): full `@spec` coverage, `mix dialyzer` enforced during `validate` because (and only because)
  this app's own `mix.exs` has a `:dialyzer` project key - mirrors the JS side's `tsconfig.json`
  presence / Python's `[tool.mypy]` table presence
- `demo_module_c` - depends on `a` and `b` (`in_umbrella: true`); proves §9.4's typed/untyped coexistence
- `demo_module_d` - depends on `c`, the deepest node in the demo graph
- `dev_tasks` - not a demo app, hosts every custom `Mix.Task` phase module (see "Why a dedicated
  `dev_tasks` app" below)

Every **demo** app has a `priv/web/index.html` demo page, its own configured port (`config/config.exs`: `48101`/`48111`/
`48121`/`48131` for a/b/c/d), and the full unit/integration/e2e test-tier split, with `Mix.Tasks.Server`
starting/stopping a real
`Plug.Cowboy` instance around integration/e2e tests - see "Test pyramid" below.

`commons` has the full test-tier split too, but no port and no `priv/web` - it is a library, not a service. The four
server-lifecycle phases therefore fan out over
`WorkspaceHelper.server_apps_in_order/1` (apps with a `:port`) rather than `demo_apps_in_order/1`; every other phase -
validate, verify, package, sbom, sign, install_local, publish, deploy, security, site - still covers it, and it
publishes to Hex exactly like `demo_module_a`/`b`.

## Why a dedicated `dev_tasks` app

A custom `Mix.Task` module placed directly under the umbrella root's own `lib/mix/tasks/` is **not discoverable** by
`mix <task>`, even after `mix compile` - confirmed directly with a probe task before committing to this design, not
assumed from Mix's docs. Standard task discovery only looks at what's compiled as part of a real app; the umbrella root
itself is never "compiled" as one. Custom tasks also do **not** auto-recurse per-app the way built-ins like `mix test`/
`mix compile`
do (confirmed with the same probe: it printed once, not four times) - hence
`SetmyInfo.Build.WorkspaceHelper`'s own hand-rolled fan-out logic, used by every phase task.

`apps/dev_tasks` hosts:

- `lib/setmy_info/build/workspace_helper.ex` - umbrella app discovery (`apps/*/mix.exs` glob) + topological sort (Kahn's
  algorithm) + `demo_apps_in_order/1`, the Elixir equivalent of
  `workspace-utils.js`/`workspace_utils.py`
- `lib/setmy_info/build/profile_helper.ex` - ADR-0041/0042 canonical profile validation + root/app YAML merge, the
  equivalent of `profile-utils.js`/`profile_utils.py`
- `lib/setmy_info/build/static_server_plug.ex` - wraps `Plug.Static` with a `/` → `index.html`
  rewrite (`Plug.Static` doesn't map bare `/` on its own) and a 404 fallback
- `lib/mix/tasks/*.ex` - one `Mix.Task` module per §2 phase not already covered by a built-in or an alias (resources,
  server, pre/post-integration-test, pre/post-e2e-test, verify, package, sbom, sign, install_local, publish, deploy,
  validate, site, security)

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

## Workspace tooling: Mix umbrella, real org precedent

- **Bootstrap**: `mix deps.get` at the umbrella root - genuinely simpler than JS/Python here, no
  "which interpreter/package manager" ambiguity to solve; Mix deps live in the project's own
  `deps/`/`_build/`, not a global store.
- **Custom phase commands**: a mix of real `Mix.Task` modules (`dev_tasks`) and root `mix.exs`
  aliases (`test.unit`/`test.integration`/`test.e2e`/`tooling_test`/`coverage`) - aliases were required specifically for
  the `test.*` names because they collide with `mix test`'s own built-in alias-resolution/umbrella-recursion behavior in
  a way a plain `Mix.Task` module doesn't reliably intercept (confirmed directly, not assumed - see `mix.exs`'s own
  comment on this).
- **Resource/profile filtering** (§6): `Mix.Tasks.Resources` + YAML profiles (`profiles/<name>.yaml`), the same
  `${propertyName}` substitution and the same YAML choice as the Python side (confirmed as the org's real convention via
  `python-commons`'s PyYAML dependency and
  `elixir-module-loader`'s own config shape) - decoupled from Mix's own env system, same as the npm/Python sides keep
  resource profiles independent of `NODE_ENV`/no stdlib env concept.

## Lifecycle

Run from the repository root, in order:

```sh
mix deps.get                                                      # bootstrap
mix clean                                                         # + stops registered servers, removes all generated output (see below)
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
DEPLOY_TARGET=dev mix deploy                                      # dev|test|prelive|live
mix site                                                           # mix docs + aggregated report index
```

This whole sequence has been run clean, end to end, on this machine (Elixir 1.19.5 / Erlang OTP 29), across the full
mixed typed/untyped app graph, including real HTTP e2e requests against every app's own running instance. See
`report.md` for the bugs that surfaced while verifying it and how they were fixed.

`Jenkinsfile` runs this same sequence in CI, same stage skeleton as `setmy.info-js`/
`setmy.info-python`'s own `Jenkinsfile` (Inspection → Preparation → Build → E2E → Quality/reporting →
System/Acceptance → Package → Publish → Deploy → Tag), same branch-gated Publish/Deploy pattern (`master` / `devel*` /
`release*`). **No GitHub Actions workflow** - deliberate divergence from both real PoCs (which each carry their own
`.github/workflows/ci.yml`):
`setmy.info-js`'s own `ci.yml` was deleted after repeated DAG-scheduling bugs, and
`setmy.info-python` never got one; `Jenkinsfile` is this system's one CI definition across all three
languages.

### Emulating CI locally, without Jenkins — planned, not present

The POSIX-`sh` `ci-local/` emulation scripts were **removed** (2026-08-25). They duplicated the `Jenkinsfile`'s stage
order and branch gating in a second language, which is exactly the drift risk §3.11 warns about — every hotfix-branch
or phase change had to be made twice, in three repos (this repo's copy included). The replacement, planned but not built yet, is a **small Groovy
runner shared by all three repos** that reads the real `Jenkinsfile` (the org `jenkinsfile-starter` shape plus these
three implementations of it) and executes its `stages`/`steps`/`when` closures locally, so there is one source of
truth instead of a copy. Until it exists, `Jenkinsfile` is the CI definition and there is no local emulation — run the
individual lifecycle commands from the "Lifecycle" section above by hand.

## Publish / Deploy (prepared, not wired to a real target yet)

`Mix.Tasks.Publish` never calls real `mix hex.publish` unless `HEX_API_KEY` is set - confirmed directly, not assumed
from the flag name, that `mix hex.publish --dry-run --yes` still tries to authenticate/prompt before reaching its "no
publish" behavior, and hangs indefinitely with no TTY (`--yes` only skips the confirm-to-publish prompt, not the
authenticate-now one). The safe default path reuses `mix hex.build` instead (Package's own local-only validation) and
just logs what branch/app would have published.

`Mix.Tasks.Deploy` requires the `DEPLOY_TARGET` environment variable (there is no `--target`
flag; `Jenkinsfile` sets it) to be one of `dev`/`test`/`prelive`/`live` and
writes a
`.deploy/<dist-name>/<target>/deploy.json` descriptor with `status: "prepared-not-executed"` - same as the npm/Python
sides, no real target infrastructure exists yet.

### `install-local`, repurposed

Same repurposing as the Python side: installs the *packaged* `.tar` (Package's actual output) plus every transitive
in-umbrella-sibling tarball into a disposable scratch Mix project as path dependencies, and confirms it compiles and the
public API resolves. Elixir doesn't need this for umbrella siblings themselves (`in_umbrella: true` already links them
at dev time automatically), but it still catches packaging bugs (missing `priv/` files, a wrong file list) the same way
the Python side's own repurposing does, since dev-time compilation never exercises a package's declared file-inclusion
rules the way installing the actual tarball does.

### Package: `demo_module_c`/`demo_module_d` are structurally excluded

`mix hex.build` fails outright for any app with `in_umbrella: true` deps: *"Dependencies excluded from the package (only
Hex packages can be dependencies): demo_module_a, demo_module_b"* - a real, unfixable-by-engineering constraint of Hex
itself, not a bug in this build. `Mix.Tasks.Package`
detects apps with local deps and skips them with a clear log line instead of silently failing or hiding the constraint -
`demo_module_a`/`demo_module_b` (no local deps) package normally.

## Test pyramid

- `test/unit/*_test.exs` - fast, in-process
- `test/integration/*_test.exs` - against the public API surface only, same divergence rationale as the Python side
- `test/e2e/*_test.exs` - **and** at least one test per demo app makes a real HTTP request (via
  `:inets` `httpc`) against a real running instance (§7.5), started by `mix pre_integration_test`/
  `mix pre_e2e_test` via `Mix.Tasks.Server` + `Plug.Cowboy`

`commons` splits its tiers strictly by **ADR-0031's dependency table** rather than by speed: unit tests are in-memory
only, everything that reads a config file or an environment variable is integration tier, and the e2e tier drives the
whole library end to end (plus a scenario-for-scenario port of `python-commons`' `behave` feature, ExUnit-shaped - see
`apps/commons/test/e2e/environment_variables_test.exs` for why no Cucumber runner). That is also why
`mix coverage` includes `commons`' integration and e2e tiers and only the demo apps' unit tier:
unit-only coverage of a library whose job *is* files and environment measures the wrong thing (52% against a fully
tested library, measured, versus 95% with the right scope).

`apps/dev_tasks/test/unit` and `apps/dev_tasks/test/integration` are the build tooling's own tests (§7.7):
`workspace_helper_test.exs`/`profile_helper_test.exs` are pure in-process calls;
`server_test.exs` spawns a real `mix server start`/`stop` subprocess and makes a real HTTP request against it. Run via
`mix tooling_test`.

## Clean: safe from a dirty state

Maven's `clean` removes `target/` - everything generated - and `requirements-rules.md` §2 row 2 requires the lifecycle
to be safe to run from a dirty state. Stock `mix clean` only removes
`_build/` compile output, so the root `mix.exs` aliases `clean` to stock `clean` **plus**:

- stopping every background HTTP server registered in `.artifacts/http-servers/*.json` (a dead pid is ignored - that is
  exactly the interrupted-run case this exists for);
- removing `.artifacts/`, `.deploy/`, `.signatures/`, `docs/` (`mix site`'s ExDoc output) and every
  `apps/*/priv/resources/` (`mix resources`' profile-filtered output).

Two related dirty-state guards live in the tasks themselves: `mix server start` treats a state file whose pid is no
longer alive (`kill -0`) as stale and replaces it instead of failing with "already registered", and `mix package` wipes
its own `.artifacts/<dist-name>/` plus any leftover `*.tar` in the app directory (which `mix publish`'s dry-run
`hex.build` leaves behind) before building.
`mix install_local`/`mix publish` consume the tarball matching the app's *current* `version:`, and fail clearly if only
an older one is present.

## Security / Quality gate policy

`mix security` **gates on any finding**, everywhere (local and CI alike), with no severity threshold - a deliberately
stricter policy than Maven's `dependency-check:check` (CVSS threshold,
`failBuildOnCVSS`) and than the JS sibling, which gates at `npm audit --audit-level=high`. The two halves differ in what
a threshold *could* look like:

- Sobelow findings could be thresholded via `mix sobelow --threshold low|medium|high` (or a per-app `.sobelow-conf`,
  which `mix security`'s `--config` flag would pick up - none exists today, so Sobelow runs with its defaults); not done
  today.
- `mix deps.audit` has no severity threshold at all - it exits non-zero on any unignored advisory.
  `.mix_audit_ignore` is the reasoned, per-advisory escape hatch (each entry documents why the finding is accepted and
  when it must be re-reviewed), not a blanket suppression.

The full, un-thresholded Sobelow + `deps.audit` output is also copied into the site report by
`mix site`, so relaxing the gate later would not hide anything.

## Site (reports)

`mix site` runs `mix docs` (ExDoc, `output: "docs"`, `main: "readme"`) and writes
`docs/reports/index.html` linking the lint report (`mix credo --strict`, rendered), the security report (`mix security`
's own Sobelow+`deps.audit` output), and the dependency tree (`mix deps.tree`) - all **shared across the whole
umbrella**, not per-app, since there's one shared
`deps/`/`_build/` and one `mix.lock`, not one environment per app - same reasoning the Python side's own shared-report
choice documents.

## Known deliberate differences from `setmy.info-js` / `setmy.info-python` / Maven

- **SBOM is a hand-rolled CycloneDX-shaped JSON placeholder**, explicitly labeled as such (§11.2 allows this) - no
  actively-maintained real CycloneDX generator exists for Hex/Mix, unlike the Python side which got a real generator
  (`cyclonedx-py`) because one exists.
- **Sign** is still a SHA-256 checksum placeholder, same as the npm/Python sides - no real signature infrastructure
  exists anywhere in this system yet.
- **`demo_module_c`/`demo_module_d` never produce a Hex package** - see "Package" above, a real Hex constraint, not a
  gap in this build.
- **`dialyxir` (demo_module_b only) and `sobelow` (all four demo apps) are declared per-app, not at the umbrella
  root** - `mix dialyzer`/`mix sobelow` resolve task visibility against the *current project's own* `deps()` when run
  with `cd:` set to a specific app's path, not the shared root
  `deps/` folder contents; confirmed directly by hitting "task not found" with only a root-level declaration.
- **Coverage is unit-test-scoped** for the demo apps (`coverage:` alias, not bare `mix coveralls`) - ExUnit
  auto-discovers every test under `test/**`, so a bare `mix coveralls` at the root pulls in e2e tests too and fails with
  connection-refused unless every app's e2e server happens to already be running; same scope the JS/Python coverage
  phases already use. `commons` is the one exception, for the ADR-0031 reason given under "Test pyramid"; its tiers need
  no running instance, so including them does not reintroduce that failure mode.
- **Publish/Deploy** stay in "prepared, not executed" mode until real registry credentials/target infrastructure exist -
  required by the spec itself (§10), not a gap.
- **`commons` does not ship its `resources/` or `test/resources/` fixtures**, and has no
  `resources/` directory at all, so `mix resources` logs "No resources directory for commons, skipping". Its `${...}`
  placeholders are resolved at *runtime* from the environment, which is the library's own job - not at build time by
  `Mix.Tasks.Resources` from `profiles/<name>.yaml`. Two different mechanisms that share a syntax; see the "Application
  configuration" section above.

### Hotfix branches (`hotfix*`)

Since `jenkinsfile-starter` 1.1.0 (ported here as Jenkinsfile 1.1.0; see `setmy.info-js/requirements-rules.md` §3.1), a
`hotfix*` branch — branched from `master`, one fix, quick review — is a first-class branch case. "Quick" is the human
review, never the pipeline: a hotfix runs the exact same Inspection → Package path as every branch (all test tiers,
quality, packaging), then `mix publish` treats it as a **hotfix candidate** (publish-eligible like `master`/`devel*`) on
its own channel so the exact build under review can be installed, and deploys to `test` and
`prelive` (`HOTFIX_TO_TEST`/`HOTFIX_TO_PRELIVE`). It never deploys `live` and
never tags — merging it to `master` is what does that, through the normal master build. The unused `MASTER_TO_PRELIVE` flag (declared since the starter, read by no stage) was removed in the
same pass.
