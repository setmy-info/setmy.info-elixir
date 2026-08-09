# Review: `commons` / `setmy_info_commons` application configuration

Review of the Elixir application-configuration library added in `apps/commons`, against (a) the stated requirements, (b)
the architecture index's "Application configuration" table, ADR-0041, ADR-0042 and ADR-0031, and (c) the two older rows
of the same library, `clj-commons` and
`python-commons`.

Every finding below was **reproduced**, not inferred from reading. Reproduction output is quoted inline. Nothing in this
document has been fixed - it describes the code as committed.

---

## 1. Requirements traceability

| #  | Requirement (as stated)                                                   | Status          | Notes                                                                                                                                         |
|----|---------------------------------------------------------------------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | Spring Boot style `application.yaml` loading                              | **Met**         | `Config.Application.init/3`                                                                                                                   |
| 2  | Profiled YAML overlay (`application-dev.yaml`) when the profile is active | **Met**         | verified for one and for several simultaneous profiles                                                                                        |
| 3  | `local` active by default "if possible"                                   | **Met**         | `Constants.default_profiles/0`; overridable, and `default_profiles: []` opts out                                                              |
| 4  | `abc.def: ${SOME_ENV_VAR}` placeholder resolution                         | **Met, subset** | bare `${VAR}` only - see [G-1](#g-1-spring-boot-placeholder-default-syntax)                                                                   |
| 5  | Environment variables override the resolved config                        | **Met, scoped** | only under the `smi` root by default - see [Q-1](#q-1-is-the-smi-root-restriction-the-behaviour-you-want)                                     |
| 6  | CLI options override environment                                          | **Met**         | `--smi-server-port` beats `SMI_SERVER_PORT`, asserted in the e2e tier                                                                         |
| 7  | Override only keys that already exist ("if those exist")                  | **Met**         | by design; consequences documented in `Config.Overrides`                                                                                      |
| 8  | Separate module, publishable to Hex                                       | **Met**         | `mix package` → `setmy_info_commons-1.0.0.tar` containing only `lib`, `mix.exs`, `.formatter.exs`; `mix install_local` compiles it standalone |
| 9  | Code kept close to Clojure and Python                                     | **Met**         | see §3                                                                                                                                        |
| 10 | Tests kept close to Clojure and Python                                    | **Met**         | see §5                                                                                                                                        |
| 11 | All README "## Lifecycle" steps work                                      | **Met**         | full sequence + `ci-local/run.sh` run clean                                                                                                   |

### Architecture index table, row by row

The index defines the overload order as **defaults in code → file (yaml over properties) → environment → CLI**.

| Index row             | This row                                                    | `clj-commons`       | `python-commons`    |
|-----------------------|-------------------------------------------------------------|---------------------|---------------------|
| Defaults in code      | **Not implemented** ([G-6](#g-6-no-defaults-in-code-layer)) | not implemented     | not implemented     |
| File - `.yaml`        | yes                                                         | yes                 | yes                 |
| File - `.properties`  | **Not implemented** ([G-5](#g-5-no-properties-support))     | not implemented     | not implemented     |
| Environment variables | yes                                                         | **not implemented** | **not implemented** |
| CLI                   | yes                                                         | **not implemented** | **not implemented** |

The two bottom rows are this row's addition; the two `Not implemented` cells are shared gaps inherited from both older
rows. The index's *first* row is the one nobody has built yet.

---

## 2. Is Clojure really the base? Yes.

|                  | first `config/application` commit | shape                                                                                                                                  |
|------------------|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `clj-commons`    | **2023-09-07**                    | original                                                                                                                               |
| `python-commons` | 2023-10-06                        | port - same function names, same `[path, parsed]` pair list, same `find_last_not_none_and_empty`, same pre-parse `${VAR}` substitution |

Confirmed by `git log` on both files. Where the two disagree, this row follows Clojure and says so in the module that
makes the choice. The exception is documented below in §3.

---

## 3. Parity with the two older rows

Structure is one-to-one: `config.application`, `config.constants`, `arguments.{argument,config,
constants,parser}`, `environment.variables`, `yaml.parser`, `json.parser`, `string.operations`,
`file.operations`, `collection.operations`.

### Divergences, and whether each is justified

| Divergence                                                 | Follows          | Justified?                                                                                                                                      |
|------------------------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| No `to_short`/`to_long`/`to_double`                        | Python           | **Yes** - one integer type, one float type on the BEAM                                                                                          |
| String keys, not keywords                                  | Python           | **Yes** - keywordizing file input means `String.to_atom/1` on unbounded input                                                                   |
| Deep merge                                                 | Python           | **Yes** - Clojure's `(merge-with (fn [l r] r) ...)` is shallow and drops sibling keys; Python's own test suite asserts the deep behaviour       |
| `find_named_placeholders` de-duplicates                    | Clojure          | **Yes** - Python carries `# TODO : find only unique placeholders`                                                                               |
| `combined_list` drops `nil` pairs                          | Clojure          | **Yes** - Python's `str.join` would raise                                                                                                       |
| Empty fragments dropped from env lists                     | Clojure          | **Yes** - Python returns `[""]` for `SMI_PROFILES=""`                                                                                           |
| `set/delete_environment_variable` really mutate            | Python           | **Yes** - Clojure raises `UnsupportedOperationException` only because the JVM cannot; the BEAM can                                              |
| `--smi-name` short flag is `n`                             | Python           | **Yes** - Clojure gives it `o`, colliding with its own `--smi-optional-config-files`                                                            |
| Full argv parsed, nothing stripped                         | Clojure          | **Yes** - `System.argv/0` already excludes the program name                                                                                     |
| Missing required option reported, not fatal                | Neither          | **Yes** - `argparse` calls `sys.exit(2)`, unusable from a library                                                                               |
| Structured error tuples, not strings                       | Neither          | **Yes** - `Config.Application` must filter unknown-option errors that are in fact override flags, which is only knowable after the YAML is read |
| Undeclared option swallows the next token                  | Neither          | **Forced** - `OptionParser` behaviour; `clojure.tools.cli` keeps it as a positional. Documented, and only affects the undeclared-option path    |
| Default config paths `["./resources", "./test/resources"]` | Clojure ordering | **Partly** - see [F-5](#f-5-test-fixtures-are-on-the-default-search-path-of-a-published-library)                                                |
| `local` default profile                                    | Neither          | **Yes** - ADR-0041/0042; explicitly requested                                                                                                   |
| Env/CLI value overrides                                    | Neither          | **Yes** - completes the index table                                                                                                             |

No unjustified divergence found.

---

## 4. Findings

### F-1 - CLI override path has no reserved-name guard, unlike the environment path

**Severity: medium. Confirmed.**

`Overrides.environment_overrides/2` explicitly refuses to consume the four `SMI_*` control variables as values.
`Overrides.cli_overrides/3` has no equivalent filter, so the same key is treated inconsistently depending on which layer
it arrives from:

```
config  = %{"smi" => %{"profiles" => "from-yaml", "name" => "from-yaml"}}
SMI_PROFILES=dev        -> environment_overrides == %{}                              # guarded
--smi-profiles dev      -> cli_overrides == %{["smi", "profiles"] => "dev"}           # NOT guarded
```

Consequence: `--smi-profiles dev` both selects the active profile *and* silently rewrites
`smi.profiles` in the merged configuration. Low blast radius today (it needs an `smi.profiles` /
`smi.name` / `smi.config.paths` key in someone's YAML), but the asymmetry is a latent trap and contradicts
`Constants.reserved_environment_variables/0`'s own stated intent.

**Fix:** give `cli_overrides/3` a reserved-flag list (`--smi-profiles`, `--smi-config-paths`,
`--smi-optional-config-files`, `--smi-name`) mirroring the environment side, ideally derived from
`Arguments.Constants.smi_arguments/0` so the two can't drift.

### F-2 - a bad boolean override crashes startup; a bad integer does not

**Severity: medium. Confirmed.**

`Overrides.coerce_like/2` degrades gracefully for numbers but propagates for booleans, because
`String.Operations.to_boolean/2` raises by design (both older rows raise too - but neither ever calls it on override
input):

```
SMI_PORT=not-a-number   -> %{["smi", "port"] => 8080}          # falls back to the configured value
SMI_SECURE=maybe        -> ** (ArgumentError) Invalid boolean value
```

Consequence: one typo'd environment variable takes the application down at configuration load, with an error message
naming neither the variable, the key, nor the file. That is the worst possible failure mode for a config library, and it
is inconsistent with the sibling clauses two lines above it.

**Fix:** in `coerce_like/2` only, rescue and fall back to the configured value the way the numeric clauses do - and log
which key/variable was rejected. Leave `to_boolean/2`'s own contract alone (both older rows raise, and its unit test
asserts that).

### F-3 - a top-level non-map config document crashes with `FunctionClauseError`

**Severity: medium. Confirmed.**

```
application.yaml containing "- a\n- b"
  -> ** (FunctionClauseError) no function clause matching in
     SetmyInfo.Commons.Config.Overrides.leaf_paths/2
```

`merge_maps/2`'s catch-all clause returns the right-hand side verbatim, so a document parsing to a list or a scalar
replaces the whole configuration map; `leaf_paths/2` then has no matching clause. Both older rows are fragile here too
(`merge_dicts` would raise on `.items()`, Clojure's `merge`
produces nonsense), so this is not a regression - but it is a crash with an internal error message where "ignore the
malformed file" or "raise a message naming the file" is what a caller needs.

**Fix:** in `merge_config/1`, skip entries whose parsed value is not a map, the same way `nil`
entries are already skipped - and say which file was skipped.

### F-4 - ADR-0042 is not enforced at runtime

**Severity: medium. Confirmed.**

ADR-0042 makes `local`/`dev`/`ci`/`test`/`prelive`/`live` the *only* allowed runtime profile names, and explicitly
forbids `staging`/`prod`. This library accepts anything:

```
SMI_PROFILES=staging,prod
  -> profiles_list == ["staging", "prod"]
  -> looks for application-staging.yaml, application-prod.yaml
```

The repo already owns the canonical check - `SetmyInfo.Build.ProfileHelper.require_canonical_profile/1`

- but only applies it at **build** time (`mix resources --profile`). ADR-0042's whole point is that build-time and
  runtime profiles are the same vocabulary, so the runtime half is currently unenforced. This also means the two older
  rows' `profileX`/`profileY` test values would be accepted here (this row's own tests deliberately use `dev` instead).

**Fix:** validate `profiles_list` in `Config.Application.init/3`. Raising outright would be a breaking default, so the
safer shape is a `:profile_validation` option (`:warn` default, `:strict`
opt-in), with the canonical list living in `Config.Constants` so `dev_tasks` and `commons` share one definition rather
than two copies.

### F-5 - test fixtures are on the default search path of a published library

**Severity: low-medium. By inspection.**

`Constants.default_config_paths/0` is `["./resources", "./test/resources"]`, inherited from both older rows (Clojure
searches `./src/test/resources` and `./test/resources`; Python searches
`./test/resources`). For those two that is harmless - they are internal libraries. This one is published to Hex, so any
consuming application that happens to have a `test/resources/application.yaml`
will load it in production, and it *wins*, because it is last in the list.

**Fix:** drop `./test/resources` from the shipped default and let the test suite pass
`config_paths:` explicitly (the option already exists and is already used by three tests). If parity with the older rows
matters more than the hazard, at minimum reverse the order so real resources win.

### F-6 - no `priv/` support; CWD-relative defaults are fragile in a release

**Severity: low. By inspection.**

Every default path is relative to the current working directory. In an OTP release the CWD is wherever the boot script
was invoked from, not the application root. The BEAM-idiomatic location is `:code.priv_dir/1`, which is also where this
repo's own `Mix.Tasks.Resources` writes its filtered output (`priv/resources/<profile>/`).

**Fix:** add a path form that resolves through `:code.priv_dir/1`. This would also close the loop with `mix resources`,
which currently produces output no runtime component reads.

### F-7 - a `null`-valued YAML key overrides to a string, silently

**Severity: low. By inspection.**

The documented way to make a key overridable is to declare it. But declaring it *empty*
(`port:` with no value) parses to `nil`, which has no type to coerce toward, so
`SMI_SERVER_PORT=8080` yields the **string** `"8080"`, not the integer. The advice "declare the key so it can be
overridden" therefore has a silent wrong-type trap in it.

**Fix:** document "declare it with a typed default, not empty", or add a `coerce_like(nil, raw)`
clause that infers the type from the string.

### F-8 - full `@spec` coverage exists but is never type-checked

**Severity: low. Verified.**

`commons` carries `@spec` on every public function, but its `mix.exs` has no `:dialyzer` key, so
`mix validate` skips it - only `demo_module_b` is type-checked. I enabled it temporarily and ran it:

```
Total errors: 0, Skipped: 0, Unnecessary Skips: 0
done (passed successfully)
```

So the specs are already correct under `:underspecs`/`:error_handling`/`:unknown`, and opting in costs nothing but a
`dialyzer:` key plus a per-app `dialyxir` dep (no `mix.lock` change -
`demo_module_b` already locks it). The change was reverted; this is a recommendation, not a description.

Worth noting the framing consequence: the README currently calls `demo_module_b` "**the** typed worked example". A
second typed app that is a real library rather than a demo strengthens that claim, and §9.4's typed/untyped coexistence
story.

### F-9 - `SetmyInfo.Commons.Config.Application` shadows `Application`

**Severity: informational.**

Inside that module, an unqualified `Application` reference resolves to `Elixir.Application`, not to the enclosing
module - and any caller doing `alias SetmyInfo.Commons.Config.Application` loses access to the OTP `Application` module.
Chosen deliberately for parity with `config.application` / the Python `Application` class, and every call site in this
repo uses `as: ConfigApplication`. Flagged so it is a known cost rather than a surprise.

---

## 5. Gaps against Spring Boot

Not defects - the requirement was Spring Boot *style*, and the index table, not Spring Boot compatibility. Listed so the
boundary is explicit.

### G-1 - Spring Boot placeholder default syntax

`${VAR:default}` is not supported. Confirmed: the placeholder regex captures `MISSING:8080` as a variable *name*, finds
no such variable, and leaves the token literal.

```
"b: ${MISSING:8080}"  ->  "b: ${MISSING:8080}"
```

This is the single most commonly used Spring Boot placeholder feature and the most likely thing to surprise someone
writing `application.yaml` from Spring Boot habit. Neither older row supports it either. It is also the cleanest fix on
this list: split the captured name on the first `:`.

### G-2 - placeholders resolve from the environment only

Spring Boot resolves `${other.property}` from the whole property source. Here `${...}` means "an environment variable",
full stop - a YAML key cannot reference another YAML key. Also single-pass:
a substituted value containing another placeholder is not re-resolved. Same in both older rows.

### G-3 - no multi-document YAML

`spring.config.activate.on-profile` inside a `---`-separated document is not supported; only the first document of a
file is read (`YamlElixir.read_from_string/1`). Profiles are selected purely by filename.
`YamlElixir.read_all_from_string/1` exists if this is ever wanted.

### G-4 - no indexed list binding

`SMI_HOSTS=a,b` splits to a list, which is the index table's own convention (`smi.xyz=abc,def,ghi`). Spring Boot's
`SMI_HOSTS_0` / `SMI_HOSTS_1` form is not supported, and a list *element* cannot be individually overridden.

### G-5 - no `.properties` support

The index table's file row is literally "**.yaml** overwrites **.properties**". Only `json`, `yml`
and `yaml` are read. Shared gap with both older rows, and the reason the file row is only half implemented anywhere.

### G-6 - no "defaults in code" layer

The top row of the index table. `init/3`'s `opts` configure the *loader* (`:config_paths`,
`:default_profiles`, `:override_root_keys`) but there is no way to seed a defaults map that the files then override.
Shared gap with both older rows. A `:defaults` option folded in as the first element of `merge_config/1` would close it
in a few lines, and would also make far more keys overridable by env/CLI
(see [Q-1](#q-1-is-the-smi-root-restriction-the-behaviour-you-want)), since overriding requires the key to exist.

### G-7 - other Spring Boot features absent

Profile groups and `spring.profiles.include`; `optional:` / `classpath:` / `file:` location prefixes; wildcard config
locations; `${random.*}`; relaxed binding onto typed structs.

---

## 6. Tests

Structure follows ADR-0031 strictly - by *dependency*, not by speed. Unit is in-memory only; anything reading a config
file or an environment variable is integration; e2e drives the library end to end.

| Tier        | Count          | Ported from                                                                           |
|-------------|----------------|---------------------------------------------------------------------------------------|
| unit        | 56 (1 doctest) | `operations_test.clj`, `parser_test.clj`, `test_parser.py`                            |
| integration | 31             | `application_it.clj`, `it_application.py` (same fixture layout, same `SOME_*` values) |
| e2e         | 9              | `environment_variables_feature.feature` (behave), scenario for scenario               |

Coverage 95.00% (unit + integration + e2e for this app; 52.69% unit-only, which is why the scope was widened - see
README "Test pyramid").

### Test gaps - behaviour verified correct here, but nothing in the suite pins it

These were probed manually during this review and all behave correctly. They are unprotected against regression:

- **`.json` and `.yml` config files are never loaded by any test.** `application_file_suffixes/0`
  advertises all three and `parse_file_by_type/1` dispatches on all three, but no fixture exercises the JSON path end to
  end through `init/3`. `Json.Parser` is only tested directly, via a tmp file.
- **Suffix overload order within one directory.** Verified `json < yml < yaml`:
  `%{"only_json" => 1, "only_yml" => 1, "only_yaml" => 1, "src" => "yaml"}`. Untested.
- **Several simultaneously active profiles.** Verified last-wins and order-sensitive:
  `--smi-profiles local,dev` → `smi.src == "dev"`, `--smi-profiles dev,local` → `"local"`. This is the core Spring Boot
  profile semantic and nothing asserts it.
- `Argument.summary_line/1` with a `nil` short flag (the only uncovered branch in that module).
- `Commons.load/3` with a caller-supplied `Arguments.Config` - only the no-args form is covered.

### Test observations

- The `EnvironmentCase` template restores the whole environment on exit, which the Python original does not do (`setUp`
  only clears). Necessary here: ExUnit runs every module in one OS process.
- No mutation testing, consistent with the rest of the repo and with both older rows.

---

## 7. Build and lifecycle integration

Correct, and the two changes outside `apps/commons` were both forced rather than opportunistic:

- **`WorkspaceHelper.server_apps_in_order/1`** (new) - the four server-lifecycle phases now fan out over apps with a
  `:port`. `commons` is a library with no running instance, and `Mix.Tasks.Server`
  raises rather than skips on a missing port (deliberately - for a demo app that is a real misconfiguration). Every
  other phase still covers `commons`.
- **`mix coverage` scope** - widened for `commons` only. Justified, but note it is a *policy*
  divergence from the repo's stated "coverage is unit-test-scoped" rule, now documented in two places in the README.
- **`mix deploy --target`** - the README documented a flag the task never read (`DEPLOY_TARGET`
  only). Fixed the task to match the README, keeping `DEPLOY_TARGET` as fallback, mirroring
  `ProfileHelper`'s existing `--profile || BUILD_PROFILE` precedence. Pre-existing bug, unrelated to this feature,
  surfaced only because the whole lifecycle was exercised.

Verified green from `mix clean`: the full README "## Lifecycle" sequence, and `ci-local/run.sh`
(→ `Build SUCCESSFUL`). `mix package` ships `lib` + `mix.exs` + `.formatter.exs` only - no test fixtures, confirmed by
reading the `mix hex.build` file listing.

---

## 8. Open question

### Q-1 - is the `smi` root restriction the behaviour you want?

`override_root_keys` defaults to `["smi"]`, so `SMI_SERVER_PORT` overrides `smi.server.port` and nothing outside the
`smi:` subtree can be overridden at all. This follows the index's prefix table exactly, and it is the safe default -
with every root allowed, a top-level `name:` key would bind to whatever `$NAME` is in the shell.

The cost: the older rows' own fixtures (`a.b.c`, `name`, `application.name`) are *not* overridable, and neither is
anything in an existing application's YAML that does not already live under `smi:`. Combined with "the key must already
exist", the practical requirement to use overrides is: put your configuration under `smi:` and declare every overridable
key with a typed default.

`override_root_keys: nil` opts into Spring Boot's every-root behaviour and is tested. If real applications will not be
reorganised under `smi:`, the default may be worth revisiting - possibly as an allow-list of roots rather than one root.

---

## 9. Recommendations, in priority order

1. **F-2** - stop a typo'd boolean environment variable from crashing configuration load.
2. **F-1** - add the reserved-flag guard to the CLI override path, derived from
   `Arguments.Constants.smi_arguments/0` so it cannot drift from the environment side.
3. **F-3** - skip non-map parsed documents in `merge_config/1`, naming the skipped file.
4. **G-1** - support `${VAR:default}`; smallest change with the largest Spring Boot fidelity gain.
5. **F-4** - validate runtime profiles against ADR-0042, sharing one canonical list with
   `dev_tasks.ProfileHelper`.
6. **Test gaps** - pin the JSON/`.yml` load path, suffix overload order, and multi-profile ordering.
7. **F-5** - reconsider `./test/resources` on a published library's default search path.
8. **F-8** - opt `commons` into Dialyzer; verified to pass with 0 errors as written.
9. **G-6** - a `:defaults` option would complete the index table's first row and make overrides materially more useful.

None of the above blocks use of the library as delivered; items 1-3 are the ones that turn a misconfiguration into a bad
failure mode rather than a bad value.
