# setmy.info-elixir — build report

Date: 2026-07-19

## Scope

Built this repo from a bare scaffold (`README.md`, `LICENSE` only) into a working third reference implementation of the
language-agnostic build system specified in `setmy.info-js/requirements-rules.md`
and ADR-0045 - the Elixir row, alongside the existing npm and Python rows. A Mix umbrella project (`apps_path: "apps"`),
four demo apps (`a`, `b` standalone - `b` typed via Dialyzer; `c` depends on
`a`+`b`; `d` depends on `c`) plus a fifth, non-demo `dev_tasks` app hosting every custom phase task, every phase in
requirements-rules.md §2, a `Jenkinsfile` + `ci-local/` mirroring the npm/Python sides' CI shape exactly. Built per the
approved plan: umbrella (not flat), minimal demo scope matching JS/Python (not `elixir-start-project/PoC/second`'s full
REST/GraphQL/Ecto complexity).

Every phase was actually run, not just written - `./ci-local/run.sh` was exercised for all four branch cases (`develop`,
`master`, `release-1.0.0`, a feature branch) and passed clean. The bugs below were all caught this way: by running the
thing, the same discipline the npm/Python sides' own `report.md` files follow throughout their history. The Elixir build
surfaced significantly more real, non-obvious platform constraints than either prior language did - Mix/umbrella task
discovery, dependency-visibility, and Hex packaging rules aren't well-documented anywhere, and every one below was found
empirically, not anticipated from reading Mix's docs first.

## Bugs found and fixed while verifying

1. **A custom `Mix.Task` module placed directly under the umbrella root's own `lib/mix/tasks/` was never discoverable by
   `mix <task>`**, even after a clean `mix compile` - confirmed with a throwaway probe task before committing to any
   task-module design, not assumed from Mix's docs. Root cause: standard task discovery only looks at what's compiled as
   part of a real app; the umbrella root itself is never "compiled" as one. Fixed by creating a dedicated
   `apps/dev_tasks`
   app to host every custom task module - moving the same probe task there made it discoverable immediately, confirming
   the fix before building the rest of `dev_tasks` on top of it.
2. **Assumed custom tasks would auto-recurse per-app the way built-ins (`mix test`, `mix compile`)
   do - verified false** with the same probe (it printed once at the umbrella root, not four times, once per app). Had
   to hand-roll `SetmyInfo.Build.WorkspaceHelper`'s own app-discovery + topological-sort + fan-out logic instead of
   relying on any Mix built-in behavior.
3. **`Mix.Tasks.Server`'s `serve/1` crashed**: `:gen_server.call(:telemetry_handler_table, ...) no
   process`. `Plug.Cowboy.http/3` needs its own dependency apps (`:telemetry`, `:cowboy`, ...)
   already started, and a bare `mix <task>` invocation does not auto-start them the way `mix run`
   or a Phoenix app's supervision tree would. Fixed by adding `Mix.Task.run("app.start")` at the top of `serve/1`,
   before calling `Plug.Cowboy.http/3`.
4. **Server started successfully, but `curl http://localhost:<port>/` returned "Not Found"** -
   `Plug.Static` does not auto-map a bare `/` request to `/index.html` the way most static-file servers do by default.
   Fixed with a manual rewrite in `StaticServerPlug.call/2`
   (`path_info == [] → path_info: ["index.html"]`) before delegating to `Plug.Static`. Also found and removed an
   `only_matching: []` option from the initial `Plug.Static.init/1` call in the same pass - empty list there means
   "match nothing", the opposite of the intent; confirmed by seeing every request 404 even for real files until it was
   removed.
5. **`mix hex.build` fails outright for `demo_module_c`/`demo_module_d`**: *"Dependencies excluded from the package (
   only Hex packages can be dependencies): demo_module_a, demo_module_b"* - a real, unfixable-by-engineering structural
   constraint: Hex refuses to publish a package that depends on `in_umbrella: true` siblings, since those aren't
   independently resolvable Hex packages. Not a bug to route around - documented directly in `Mix.Tasks.Package`'s
   `@moduledoc` and handled by having Package detect apps with local deps and skip them with a clear log line, rather
   than letting the whole phase fail or silently swallowing the error.
6. **`Mix.Tasks.Sign` crashed** (`illegal operation on a directory`) trying to read
   `install-check/` - a directory `Mix.Tasks.InstallLocal` leaves behind in the artifacts dir, picked up by an overly
   broad glob. Same category of bug as the Python side's own `publish.py`
   fix (item 5 in that repo's report). Fixed by narrowing the glob to `Path.wildcard("*.tar")`.
7. **`:erl_tar.extract/2` raised `{:error, :invalid_tar_checksum}` on a real, verified-uncorrupted Hex `.tar`** -
   confirmed directly that the system `tar` binary extracts the exact same file with no error, ruling out a corrupted
   artifact before looking anywhere else. Hex's outer `.tar`
   format (an outer tar containing `contents.tar.gz` + `metadata.config` + `CHECKSUM` + `VERSION`)
   apparently isn't fully compatible with `:erl_tar`'s checksum validation in this Erlang/OTP version. Fixed by
   switching `Mix.Tasks.InstallLocal` to shell out to the system `tar` binary instead of `:erl_tar`.
8. **`mix hex.publish --dry-run --yes` hung indefinitely** (a full 2-minute non-interactive timeout)
   waiting on stdin, even though its own help text says `--dry-run` "builds package and performs local checks without
   publishing." Confirmed directly, not assumed from the flag name: it still tries to refresh/prompt for Hex
   authentication before ever reaching the "no publish" behavior, and `--yes` only skips the confirm-to-publish prompt,
   not the authenticate-now one. Fixed by redesigning `Mix.Tasks.Publish` to never call `mix hex.publish` at all on the
   dry-run path - it reuses `mix hex.build` (Package's own local-only validation, no network/auth touched) instead, and
   only calls the real `mix hex.publish --yes` when `HEX_API_KEY` is actually set, with the key exported so Hex
   authenticates from the env var rather than prompting.
9. **A stale `validate: [...]` alias in the root `mix.exs` silently shadowed the real
   `Mix.Tasks.Validate` module** once that module was written in `dev_tasks` - Mix resolves aliases before task modules
   of the same name, so `mix validate` kept running the old
   `format --check-formatted`-only alias logic instead of the new Dialyzer-checking task. Caught by visibly seeing
   format-check diff output where Dialyzer output was expected, not by reading the config and noticing the collision in
   advance. Fixed by removing the stale alias; proper
   `test.unit`/`test.integration`/`test.e2e` aliases (needed for a different, unrelated reason - see item 10) were added
   in the same pass.
10. **`mix test.unit`/`.integration`/`.e2e` as `Mix.Task` modules in `dev_tasks` were never found**
    - names starting with `test.` collide with `mix test`'s own built-in alias-resolution/umbrella- recursion behavior
      in a way plain `Mix.Task` modules under a compiled app don't reliably intercept (unlike every other custom task
      here - `resources`, `server`, `deploy`, etc. - none of which are named after a built-in). Fixed by making them
      root `mix.exs` aliases instead (`"test.unit": ["test <paths...>"]`), matching `elixir-start-project/PoC/first`'s
      own real precedent for exactly this naming collision.
11. **`mix dialyzer` (for `demo_module_b`) and `mix sobelow` (for all four demo apps), run with
    `cd: app.path`, both reported "task not found" even though `dialyxir`/`sobelow` were declared as deps at the
    umbrella ROOT `mix.exs`.** Root cause: Mix resolves task visibility against the *current project's own* `deps()`,
    not the shared `deps/` folder contents on disk - a root-level declaration doesn't make the task visible when the
    current project is a specific app. Fixed by moving `dialyxir` (demo_module_b only) and `sobelow` (all four demo
    apps) into each app's own
    `deps()`, removed from the root.
12. **Sobelow refuses to run at an umbrella root at all**: *"This does not appear to be a Phoenix application...
    Umbrella application, each application should be scanned separately"* - confirmed directly by trying it there first.
    Fixed `Mix.Tasks.Site`/`Mix.Tasks.Security` to loop over each demo app and run Sobelow per-app instead of once at
    the root.
13. **A bare `mix coveralls` at the root ran every test tier** (unit + integration + e2e) since ExUnit auto-discovers
    everything under `test/**`, and failed with connection-refused on
    `demo_module_d`'s e2e server test because no server was running for that invocation. Fixed by adding a `coverage:`
    alias explicitly scoped to the same `test/unit` paths `test.unit` itself uses - same scope the npm/Python sides' own
    coverage phase already uses.
14. **`Mix.Tasks.Sbom` originally used `Code.eval_file(mix.lock)` to read the lockfile**, which produced dozens of
    spurious "quoted keyword" compiler warnings on every run (a `mix.lock` file's literal syntax isn't meant to be
    `eval`'d directly, even though it happens to work). Fixed by switching to `Mix.Dep.Lock.read/0`, Mix's own accessor
    for the same data - silent, no warnings.
15. **Real `mix credo --strict` findings**: missing `@moduledoc` on four task modules, an unformatted large number
    literal (`48101` → `48_101`, Credo's readability convention), a nested-module-alias suggestion in `sbom.ex`, and a
    negated if/else branch in `publish.ex`. All fixed for real (not suppressed) - `mix credo --strict` now passes with
    zero issues.
16. **A real, currently-unfixable-by-version-bump security finding**: `cowlib 2.18.0` (transitive, via `plug_cowboy` →
    `cowboy`) flagged by `mix deps.audit` for two CVEs, and 2.18.0 is the latest version available (checked via
    `mix hex.info cowlib` - no newer release to bump to). Researched both directly against OSV.dev
    (`https://api.osv.dev/v1/vulns/<id>` and `/v1/query`), not taken on faith from `mix_audit`'s local database:
    - `EEF-CVE-2026-43969` (cookie header-injection): the advisory's own affected range is
      `2.9.0-2.16.1`; our locked `2.18.0` is past that range - `mix_audit`'s local DB entry appears stale relative to
      the upstream OSV record.
    - `EEF-CVE-2026-43966` (HTTP response splitting): genuinely unpatched upstream (no upper bound in the advisory), but
      not exploitable through how this repo actually uses cowlib - the vulnerable path requires calling
      `cow_http_struct_hd:item/1` directly with attacker-controlled data, which neither `StaticServerPlug` nor
      `Plug.Static` do, and cowboy ≥2.16.0 (we're on 2.17.0) already rejects CR/LF in outgoing headers by default
      regardless.

    Created `.mix_audit_ignore` documenting both findings with full reasoning, wired into
    `Mix.Tasks.Security` via `--ignore-file` - a deliberately visible, reasoned suppression per §12.3's "stay visible,
    don't silently hide a finding" rule, not a blanket ignore.
17. **`Mix.Tasks.Publish`'s `publish_branch?/1` incorrectly treated `release*` branches as publish-eligible**,
    inconsistent with the actual `Jenkinsfile` `when` conditions (Publish never runs on a `release*` branch - `Release`
    needs `branch 'master'` exactly, `Snapshot` needs
    `startsWith('devel')`; a `release*` name matches neither). The same quirk was already documented on the npm/Python
    sides; this was a fresh instance of the same mismatch, not a copy of an existing bug. Caught while writing
    `ci-local/release-branch.sh` and comparing its expected stages side by side against the actual `Jenkinsfile`. Fixed
    to only match `branch == "master"`
    or `String.starts_with?(branch, "devel")`.

## Verified working, end to end

Ran the full sequence from `README.md` (bootstrap → clean → validate → format:check → lint → resources → compile →
tooling_test → unit/integration/e2e tests → coverage → security → verify → package → sbom → sign → install-local →
publish dry-run → deploy → site) with a clean
`_build`/`deps`, across all four demo apps plus `dev_tasks`, on Linux (Elixir 1.19.5 / Erlang OTP

29)
    - no errors after the fixes above. E2E tests confirmed making real HTTP requests (`:inets`
      `httpc`) against a real running `Plug.Cowboy` instance for every demo app, not just re-compiling the code (§7.5).
      `mix credo --strict` passes with zero issues; `mix dialyzer` passes for
      `demo_module_b`.

`./ci-local/run.sh <branch>` was run for all four branch cases and passed clean:

- `develop` → full pipeline: Inspection..Package, Publish/Snapshot (dry-run `mix hex.build` for
  `a`/`b`, correct skip messages for `c`/`d`), Deploy/dev, Deploy/test.
- `master` → Inspection..Package, Publish/Release (dry-run), Deploy/live, Tag.
- `release-1.0.0` → Inspection..Package, Deploy/dev, Deploy/test, Deploy/prelive, **no Publish** - confirmed this
  matches the `Jenkinsfile`'s actual `when` logic (neither Publish branch condition matches `release*`), the exact quirk
  bug #17 above fixed, not a leftover bug re-surfacing.
- A feature branch → Inspection..Package only (Package still correctly packages `a`/`b`, skips
  `c`/`d`), nothing branch-gated ran.

## Design decisions worth recording (not bugs, but real judgment calls)

- **Umbrella project with 4 demo apps, not a flat single-app repo** - user's explicit choice (`AskUserQuestion`,
  "Umbrella, 4 demo apps"), matching `elixir-start-project/PoC/first`'s own shape and giving `demo_module_c`/
  `demo_module_d`'s dependency edges a real, automatic linking mechanism (`in_umbrella: true`) with no workspace-linking
  problem to solve, unlike npm/`pip`.
- **A dedicated `dev_tasks` app for all custom phase tasks**, not task modules scattered at the umbrella root - required
  by bug #1, not a stylistic preference; also gives the build tooling itself a real place to have its own `test/unit`/
  `test/integration` tests (§7.7), the same
  "tooling has its own tests" pattern the npm/Python sides already establish, and gives the fan-out logic
  (`WorkspaceHelper`) a single, shared home instead of duplicating it into each phase task.
- **`test.unit`/`test.integration`/`test.e2e`/`coverage` as root `mix.exs` aliases, not
  `Mix.Task` modules** - the one category of custom command that had to leave `dev_tasks`, because of the `test.*`
  naming collision described in bug #10. A deliberate exception to "every custom task lives in `dev_tasks`", documented
  as such directly in `mix.exs`'s own comment, not silently inconsistent.
- **`dialyxir`/`sobelow` declared per-app, not once at the umbrella root** - required by bug #11, not a preference; also
  arguably the more correct home for them anyway, since both are meant to be opt-in per app (Dialyzer especially - only
  `demo_module_b` uses it).
- **`is_typed` opt-in via `:dialyzer` project-key presence** in an app's own `mix.exs`, exactly mirroring the npm side's
  `tsconfig.json`-presence check and the Python side's `[tool.mypy]`-table presence check (§9.4) - one app (`b`) typed,
  three untyped, all through the same
  `validate`/`compile`/`test.*` invocations with no separate pipeline.
- **YAML for resource profiles**, not JSON - the org's real convention, confirmed via
  `python-commons`'s PyYAML dependency (already established on the Python side, see that repo's Round 2) and
  independently via `elixir-module-loader`'s own existing `config/*.exs` shape (though that repo uses native Elixir
  config, not this build system's own profile concept - the YAML choice here is about profile *files*, a concept
  `elixir-module-loader` doesn't have).
- **`prelive` config environment added** (`config/prelive.exs`) - genuinely new: neither
  `elixir-start-project/PoC/first`/`PoC/second` nor `elixir-module-loader` has a `prelive.exs` (the latter has `local`/
  `dev`/`ci`/`test`/`live` - 5 of ADR-0041's 6 canonical names, the most complete of any existing Elixir repo in this
  org, but still missing `prelive`). This skeleton is the first fully ADR-0041-complete Elixir config in the org.

## Open items (not resolved here - resolve explicitly, don't inherit silently)

- Real publish (`HEX_API_KEY` set) and real deploy: blocked on actual Hex credentials and actual target infrastructure
  existing, not a design question - same as the npm/Python sides' own open items.
- `demo_module_c`/`demo_module_d` have no Hex publishing story at all (see bug #5) - genuinely unresolved, not just
  deferred: if these apps ever need independent Hex distribution, the in-umbrella dependency structure itself would have
  to change (e.g. extracting shared code into a real, separately-published Hex package the way `elixir-module-loader`
  itself was extracted from
  `PoC/first`'s engine).
- System/Acceptance stages are placeholders, same as the npm/Python sides - no test tier exists yet for either.
- Mutation testing: no Elixir-ecosystem equivalent wired in (unlike `mutmut`'s placeholder on the Python side) - not
  evaluated here.
- `.mix_audit_ignore`'s two cowlib entries need re-review whenever `cowlib`/`plug_cowboy` is upgraded - see the file's
  own header comment.

## `elixir-module-loader` as the likely real migration target (read-only review)

Per the user's own framing when kicking this build off ("most likely the project later moves into
elixir-module-loader"), a short read-only pass over
`/home/has/sources/components/setmy.info/submodules/elixir-module-loader` - no code moved, same treatment the npm/Python
sides gave their own sibling-repo reviews.

It's a real, already-published Hex library - a single (non-umbrella) app, flattened out of
`elixir-start-project/PoC/first`'s dynamic module-loading engine. It already ships
`config/{local,dev,ci,test,live}.exs` (5 of ADR-0041's 6 canonical names, missing only `prelive` - the gap this
skeleton's own `config/prelive.exs` closes for the first time in this org). Its dynamic-loading engine is exactly the
kind of capability `demo_module_c`/`demo_module_d`'s dependency chain here only fakes with static `in_umbrella: true`
edges - migrating it in would mean deciding whether it becomes a fifth umbrella app other apps depend on, or stays a
standalone library this umbrella's own apps pull in as a regular Hex dependency (its published package, not a path
dependency) - a real design decision to make explicitly when that migration actually happens, not assumed here.

## Round 2: filtered-resources leak out of the cross-language review

Date: 2026-07-19

Found by the cross-language review recorded in `setmy.info-js/report.md` Round 8 (item 37), fixed here as part of that
round's follow-up. Numbering continues this repo's own sequence.

18. **`mix resources`' generated output shipped inside the published Hex package and was committed as if source.**
    The Resources task writes profile-filtered output to `apps/<name>/priv/resources/<profile>/`, and Hex's default
    package file set includes all of `priv/` — the actual `mix hex.build` file listing showed `priv/resources/ci`
    inside `setmy_info_demo_module_a-1.0.0.tar`, i.e. CI-environment config baked into a supposedly environment-neutral
    versioned artifact. The same generated file was also committed to git (it rode along in the initial "Elixir
    solution" commit). Three-part fix, each part verified, plus two real git-behavior discoveries made while verifying:
    - `package/0` in `demo_module_a`/`demo_module_b`'s `mix.exs` now declares an explicit `files:` allowlist (`lib`,
      `priv/web`, `mix.exs`, `.formatter.exs`) instead of Hex's default set — re-ran `mix package` with
      `priv/resources/ci/` present on disk and confirmed the tarball listing now contains `priv/web` only.
    - `.gitignore` gained a `**/priv/resources/` rule. The `**/` prefix is load-bearing: a gitignore pattern containing
      a mid-path slash is anchored to the `.gitignore`'s own directory, so a bare `priv/resources/` only matches at the
      repo root, never under `apps/*` — verified with `git check-ignore`, not assumed.
    - Even with the correct pattern, `git check-ignore` still reported the file as not ignored — because **a file
      already in the index is exempt from gitignore entirely**, and the generated file was already tracked via the
      initial commit. Untracked it with `git rm --cached` (file kept on disk, removal staged); only then did the ignore
      rule take effect. Practical lesson: adding a gitignore rule for something already committed silently does
      nothing — check-ignore/status verification after the change is what caught both traps.

    The new spec rule for this whole finding class is `setmy.info-js/requirements-rules.md` §6.6: profile-filtered
    output MUST NOT be included in a published artifact and MUST be VCS-ignored. The npm side had the same package-leak
    half of the bug (`dist/resources/` inside `files: ["dist"]`), fixed in the same round; the Python side was clean by
    construction (its wheel packages only `src/`), which is what made the contrast visible.

## Round 3: dirty-state safety and security gate policy, ported from the JS sibling's Round 10

Date: 2026-08-25

Ports of `setmy.info-js/report.md` Round 10 items 45 and 46 (item 44 - build destroying the resources output - does not
apply: `mix compile` never touches `priv/resources/`). Numbering continues this repo's own sequence. Nothing committed.

19. **`mix clean` was stock `mix clean` only, so nothing ever removed the lifecycle's own generated output or stopped a
    leaked server** (JS item 46; §2 row 2 "MUST be safe to run from a dirty state"; Maven's `clean` removes all of
    `target/`). Root `mix.exs` now aliases `clean: ["clean", &clean_generated/1]`: stock clean, then every
    `.artifacts/http-servers/*.json` pid is `kill`ed (dead pid ignored), then `.artifacts/`, `.deploy/`,
    `.signatures/`, `docs/` (Site's ExDoc output - path confirmed from `site.ex`/`docs: [output: "docs"]`),
    `apps/*/priv/resources/` and `apps/*/*.tar` are removed. A function in `mix.exs` rather than a
    `Mix.Tasks.Clean` in `dev_tasks`, for the reason already recorded on the `test.*` aliases (custom modules named
    after built-ins don't reliably win at an umbrella root) plus one more: clean must work when `_build/` - where
    `dev_tasks`' compiled tasks live - is already gone. Verified: with a live registered server and all five directories
    present, `mix clean` printed one "Stopped ... pid" line and five "Removed ..." lines, the process was gone and none
    of the directories remained. The command `ci-local/lib.sh`'s `stage_preparation` and the README already call
    (`mix clean`) is the one that does this.
20. **`mix server start` raised "already registered" on a state file whose pid was long dead** (JS item 46's second
    half). It now probes the recorded pid with `kill -0`; a dead pid is logged as stale, the file removed, and the start
    proceeds; a live pid still raises (message now includes the pid). Verified both ways: started a server, killed its
    pid by hand (port confirmed free with `ss`), `mix server start` printed "Removing stale HTTP server state ... (pid N
    is dead)" and started; a second start against the live one still exits 1. Limitation found while testing, NOT fixed:
    liveness is judged by the *registered* pid only. If an unregistered process (e.g. one whose state file was
    hand-edited or lost) still holds the port, the new `serve` child fails to bind, but `wait_until_listening` connects
    to the squatter and reports success anyway - exactly what happened when a botched test step killed the wrong process
    here. A bind-failure check on the child would close this; left as an open item since it is a pre-existing gap, not
    part of this round's port.
21. **`mix package` was not re-runnable after `mix publish`**: Publish's dry-run runs `mix hex.build` in place and
    leaves `apps/<app>/<dist>-<version>.tar` behind, so Package's strict `[tar_path] = Path.wildcard(...)` match blew up
    with a MatchError on the next run. Package now `rm_rf!`s its own `.artifacts/<dist>/`, deletes any
    `apps/<app>/*.tar` before `hex.build`, and the match is a `case` with clear errors for zero/many tarballs. Verified:
    `package -> install_local -> publish -> package` succeeds with the leftover tar present.
22. **`install_local` and `publish` consumed `[tar | _]` of a glob**, i.e. whichever tarball happened to sort first,
    stale versions included. New `WorkspaceHelper.packaged_tar/1` (app info now carries `version:` from the app's
    `mix.exs`) resolves `.artifacts/<dist>/<dist>-<version>.tar` exactly; no tarballs at all stays the existing soft
    "run package first" message (also the normal case for the Package-skipped apps c/d), tarballs of only other versions
    raise a clear error naming what was found. Verified by renaming the 1.0.0 tar to 0.9.0: both tasks fail with "No
    packaged tarball for demo_module_a version 1.0.0 ... (found: [...-0.9.0.tar])".
23. **Security gate policy was implicit** (JS item 45). Behavior unchanged - `mix security` still gates on any Sobelow
    or `deps.audit` finding - but README now has a "Security / Quality gate policy" section stating it:
    Sobelow could be thresholded via `--threshold` (no `.sobelow-conf` exists today, `--config` falls back to defaults),
    `deps.audit` has no threshold at all, `.mix_audit_ignore` is the reasoned per-advisory escape hatch, the JS sibling
    gates at `npm audit --audit-level=high`, and the un-thresholded output stays in the site report.
24. **README documented `mix deploy --target dev`, but `Mix.Tasks.Deploy` reads only `DEPLOY_TARGET`** (its own
    @moduledoc, `ci-local/lib.sh` and `Jenkinsfile` all agree). README lifecycle block and Publish/Deploy section
    corrected to `DEPLOY_TARGET=dev mix deploy`.

Verified by running (Elixir 1.20.3 / OTP 29): `mix deps.get` (network available), `mix compile --warnings-as-errors`,
`mix format --check-formatted`, `mix credo --strict` (no issues), `mix clean`, `mix resources --profile ci`,
`mix pre_integration_test` (4 servers), `mix post_integration_test`, `mix package`, `mix install_local`, `mix publish`
(dry-run), `mix package` again, `mix tooling_test` (10 passed), the stale-pid and version-mismatch paths above, and a
final `mix clean` leaving no `.artifacts/` and no `server serve` process. Not run this round: `mix validate`, the test
tiers, `mix coverage`, `mix security`, `mix site`, `mix sign`, `mix sbom`, the `ci-local/*.sh` cases, and the
`Jenkinsfile` - none of their code changed. No new automated test was added for the stale-pid path; it was exercised by
hand only.

### Hotfix branch support (same day)

See `setmy.info-js/report.md` Round 12 for the shared decision and change list. Here: `Jenkinsfile` 1.1.0
(Publish/Hotfix candidate stage, `HOTFIX_TO_*` flags, dead `MASTER_TO_PRELIVE` removed), `ci-local/hotfix-branch.sh` +
`run.sh` dispatch, publish resolver accepts `hotfix*`, README. Verified: `./ci-local/run.sh hotfix-1.0.1` EXIT 0.


### `ci-local/` removed (same day)

The POSIX-`sh` CI emulation scripts were deleted; see `setmy.info-js/report.md` Round 13 for the decision. They were a
second hand-maintained copy of the `Jenkinsfile`'s stage order and branch gating (proven by the `hotfix*` addition
having to be written twice), and are to be replaced by a shared Groovy runner that reads the real `Jenkinsfile`.
`Jenkinsfile` is unchanged and remains the only CI definition. README, code comments and (JS side)
`requirements-rules.md` §3.11 re-synced; format/lint checks clean.
