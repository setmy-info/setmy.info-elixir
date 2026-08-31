# Static code review — setmy.info-elixir

Blind review: every finding below comes from **reading** the sources. No command was executed, nothing was compiled,
no test was run, no pipeline was invoked. Findings are therefore *reasoned*, not *observed* — each one states what
would have to be run to confirm it.

Scope, two passes. **Pass 1** (sections A-C): the umbrella root (`mix.exs`, `lifecycle.exs`, `Jenkinsfile`,
`.formatter.exs`, `.credo.exs`, `config/*.exs`) and the recent changes — the 4-space formatter plugin, the test
lifecycle phases, the `HEX_BUILD` guard and the `Jenkinsfile` environment handling. **Pass 2** (sections D-E): the
`commons` library itself (config loading, overrides, parsers, arguments, string/collection/file/environment
operations), the demo apps' runtime code, the test support, and the remaining config and dot-files.

---

## A. High — will break, or already breaks, a normal workflow

### A1. `mix format` inside any demo app directory cannot find the plugin

- `apps/demo_module_a/.formatter.exs:5` (and `b`, `c`, `d` — all four identical)
- `apps/demo_module_a/mix.exs:47-54`, `apps/commons/mix.exs:28`

Each demo app's `.formatter.exs` declares:

```elixir
plugins: [SetmyInfo.Elixir.Formatter.FourSpaces],
```

but that module is compiled **only into the `commons` app** (`elixirc_paths: ["lib", "formatter"]`), and **none of the
four demo apps depend on `commons`** — their `deps/0` lists only `plug_cowboy`, `sobelow`, `sbom`, `excoveralls`.

Mix's plugin loader runs `loadpaths` (+ `compile`) for the *current* project and then `Code.ensure_loaded?/1` on each
plugin, raising `Formatter plugin ... cannot be found` when it fails. Run from the umbrella root everything works,
because the root's `subdirectories: ["apps/*"]` traversal happens inside a VM that has already loaded every app. Run
from inside `apps/demo_module_a/`, `commons`' `ebin` is not on the code path.

**Consequence:** `cd apps/demo_module_a && mix format` — an entirely ordinary thing to do, and what most editor
"format on save" integrations invoke — fails. So does `mix cmd mix format`.

**Confirm with:** `cd apps/demo_module_a && mix format --check-formatted`.

**Fix options**, in order of preference:

1. Move the plugin out of `commons` into its own tiny umbrella app (`apps/formatter/`) and add it as a
   `only: [:dev, :test], runtime: false` dependency of every app — explicit, and it stops shipping in `commons`
   (see A2).
2. Or keep it where it is and add `{:commons, in_umbrella: true, only: [:dev, :test], runtime: false}` to each demo
   app. Cheap, but declares a dependency that exists only to satisfy the formatter.
3. Or drop `plugins:` from the four demo apps' `.formatter.exs` and accept that per-app formatting is 2-space —
   which defeats the whole point.

### A2. The formatter plugin is compiled into the production release of `commons`

- `apps/commons/mix.exs:28`

```elixir
elixirc_paths: ["lib", "formatter"],
```

This is unconditional — it applies in `:live` and `:prelive` too. A build-time tool that carries
`@behaviour Mix.Tasks.Format` and calls `Mix.shell/0` (`four_spaces.ex:32,56`) therefore ends up in the runtime
library's `.app` module list and in every OTP release that includes `commons`. `Mix` is not part of a release, so the
module is a loaded-but-unloadable landmine.

It also forced `plt_add_apps: [:mix]` into the root Dialyzer config (`mix.exs:422`) — widening the PLT for the whole
umbrella to accommodate one build script. That is a symptom, not a fix.

**Fix:** make the path env-dependent, the conventional Mix idiom:

```elixir
elixirc_paths: elixirc_paths(Mix.env()),
...
defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "formatter"]
defp elixirc_paths(_), do: ["lib"]
```

`:dev` is required (`mix format` runs there), `:test` is required (the plugin's unit test calls it directly). With
this, `plt_add_apps: [:mix]` can stay (Dialyzer runs in `:dev`) but is at least honest.

### A3. The plugin's own safety net can crash instead of catching

- `apps/commons/formatter/setmy_info/elixir/formatter/four_spaces.ex:53`, `62-69`

```elixir
if ast(widened) == ast(stock) do
...
defp ast(source) do
    source |> Code.string_to_quoted!(columns: false) |> ...
```

The guard exists precisely because widening might corrupt a file. But the corruption it is most likely to produce —
a mis-protected line that splits a string literal — yields **syntactically invalid** source, and `string_to_quoted!`
*raises* on that. So in exactly the case the net was built for, `mix format` aborts with a `SyntaxError` stack trace
instead of falling back to the 2-space output.

**Fix:** make `ast/1` total.

```elixir
defp ast(source) do
    case Code.string_to_quoted(source, columns: false) do
        {:ok, quoted} -> Macro.prewalk(quoted, fn {f, _, a} -> {f, [], a}; o -> o end)
        {:error, _} -> :unparsable
    end
end
```

`:unparsable` never equals the stock AST, so the fallback triggers as designed.

### A4. `physical_newlines/4` can raise `MatchError`

- `four_spaces.ex:122`

```elixir
[_prefix, rest] = String.split(tail, delimiter, parts: 2)
```

`String.split/3` returns a **one**-element list when the delimiter is absent, and the match then raises. This is
reachable whenever `meta[:line]`/`meta[:column]` do not point at the literal's opening delimiter — which is not
guaranteed for every node shape the `prewalk` matches (`{:<<>>, meta, _}` and the sigil clause take metadata from the
container, not from the string token). A `MatchError` from inside a formatter plugin surfaces as a raw crash on
`mix format`, i.e. on the pre-commit hook and on the CI gate.

**Fix:** match defensively and treat "cannot locate the delimiter" as "protect nothing":

```elixir
case String.split(tail, delimiter, parts: 2) do
    [_prefix, rest] -> count_newlines(String.graphemes(rest), closing, interpolates?, 0, 0)
    _ -> 0
end
```

---

## B. Medium — wrong in edge cases, or weakens a gate

### B1. A trailing comment ending in `"""` opens a phantom heredoc

- `four_spaces.ex:213-214`

```elixir
defp heredoc_opened("#" <> _), do: nil
defp heredoc_opened(body), do: Enum.find(@heredocs, &String.ends_with?(body, &1))
```

Only a line whose **body starts** with `#` is skipped. A line with a *trailing* comment that happens to end in the
delimiter — `foo(bar)  # the """ form` — passes the guard, `String.ends_with?` matches, and the plugin enters heredoc
mode. Everything after it is then shifted as heredoc content until a line trimming to `"""` appears, which may be
never; in that case the whole rest of the file is mis-indented. The AST guard (A3) would catch it *if* the result is
still parsable, and then the entire file silently stays at 2 spaces.

**Fix:** strip trailing comments before the test, or better, decide heredoc openings from the token metadata already
being collected in `protected_lines/1` rather than by string matching.

### B2. A file the plugin gives up on still passes `mix format --check-formatted`

- `four_spaces.ex:53-59`

The fallback writes the **stock 2-space** output and prints to stderr. That output is deterministic, so
`--check-formatted` compares it against itself and passes. The pre-commit hook, `mix quality` and CI therefore all go
green on a file that violates the project's stated 4-space rule, and the only evidence is a line of stderr nobody
reads in a 400-line build log.

This is a policy hole, not a crash: the gate cannot enforce the rule it exists to enforce.

**Fix:** honour an env flag — `FOUR_SPACES_STRICT=1` (set in `Jenkinsfile` and in the hook) turns the fallback into
`Mix.raise/1`. Local editing keeps the forgiving behaviour.

### B3. `with_io(:stderr, …)` in an `async: true` test is not concurrency-safe

- `apps/commons/test/unit/formatter_four_spaces_test.exs` — `use ExUnit.Case, async: true` and the `format/1` helper

Capturing a **named** device (`:stderr`) replaces the group leader for a globally registered process. `ExUnit.CaptureIO`
documents this as unsafe with `async: true`: any other test — in this app or, since the tiers run
`max_cases: 16`, in a concurrently running module — that writes to stderr while the capture is installed has its
output swallowed or attributed here, and vice versa. The assertion `assert output == ""` then fails for reasons
unrelated to the plugin, intermittently.

**Fix:** `use ExUnit.Case, async: false` for this module, or drop the capture and assert on the returned value only.

### B4. `Jenkinsfile` — CPS risk and no quoting in the new `runCommand(Map, String)`

- `Jenkinsfile:17-23`

```groovy
sh variables.collect { name, value -> "${name}=${value}" }.join(' ') + ' ' + command
```

Two concerns:

1. **CPS.** Jenkins pipeline Groovy is CPS-transformed, and passing a CPS closure to a Java collection method
   (`Map.collect`) is the classic source of `CpsCallableInvocation` / `NotSerializableException` failures. It often
   works, which is what makes it dangerous — it can fail on a different Jenkins or plugin version than the one it was
   written against. The usual remedy, `@NonCPS`, cannot be applied to this method because it calls the `sh`/`bat`
   steps. Split it: an `@NonCPS` helper that returns the prefix string, and a thin caller that runs `sh`/`bat`.
   A `for (entry in variables)` loop avoids the closure entirely and is the simplest fix.
2. **Quoting.** Neither branch quotes values. A value containing a space, `&`, `|` or `>` breaks the command — under
   `bat` silently and creatively. Today's values (`1`, `test`, `unit.xml`) are safe, so this is latent, but the helper
   is now the single funnel for *all* pipeline environment variables and will be reused.

### B5. `Jenkinsfile` behaviour changed without a changelog entry

- `Jenkinsfile:40-72` (the version block), `Jenkinsfile:17-23`

The file maintains an explicit version history and the most recent entry is `version 2.3.0 - integration and e2e tiers
are lifecycle phases…`. Replacing every `withEnv` block with a `runCommand(Map, String)` helper is a behavioural
change to how *all* environment variables reach *all* commands — exactly the kind of thing the header exists to
record — and it is undocumented. By this file's own convention that is a rule violation.

**Fix:** add a `version 2.4.0` entry naming the change and the reason (a runner that does not implement `withEnv`
drops the variables silently).

### B6. `security_reports/1` reports success it has not verified

- `mix.exs:349-373`

```elixir
{audit, _} = System.cmd(mix_executable(), audit_args, env: env)
File.write!(Path.join(dir, "deps_audit.json"), audit)
Mix.shell().info("Wrote #{dir}/deps_audit.json")
```

The exit status is discarded by design ("a report of a finding is still a report"), but the code goes further than
that rationale: if the child fails *before* producing JSON — deps not compiled for the env, Hex offline, an error
written to stderr — `audit` is empty, an empty file is written, and the log says `Wrote …`. Jenkins then archives an
invalid report as if it were real. The `sobelow` loop below is worse: it prints `Wrote …` without checking that
`--out` produced anything at all.

Note the inconsistency with the neighbouring `sbom/1` (`mix.exs:375-394`) and `deps_tree/1` (`mix.exs:398-409`), which
both `Mix.raise` on a non-zero status. Three sibling report generators, two different failure policies.

**Fix:** keep ignoring "tool found something" exits, but distinguish them from "tool did not run": require the output
to be non-empty (and, for sobelow, that the file exists) before logging success.

### B7. Turning serving off in the test env removed the only Mix-side coverage of it

- `config/test.exs:17-24`

```elixir
for app <- [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d] do
    config app, serve: false
end
```

This correctly fixes the `:eaddrinuse` clash with the release daemons. But the four `application.ex` modules'
central claim — the `mod:` callback starts a Cowboy endpoint on the configured port — is now exercised **only**
through the release daemons in the integration/e2e tiers. No test starts the supervision tree the way `iex -S mix`
does, so a regression in `start/2`, `port/0` or the child spec that only manifests under Mix would not be caught.

The moduledocs and README were updated to describe the new behaviour, so the documentation is consistent; the test
coverage is what quietly narrowed. Worth an explicit `@tag :integration` test that starts one app with
`Application.put_env(app, :serve, true)` and asserts the port answers, if that guarantee matters.

---

## C. Low — consistency, duplication, maintainability

### C1. The list of demo apps is written out in four places

`config/config.exs:11-14` (ports) · `config/test.exs:22` · `config/runtime.exs:24` · `mix.exs:249`
(`@deployable_apps`).

Adding a fifth demo app means remembering all four. `@deployable_apps` cannot be shared with the config files (they
are evaluated separately), but `config/test.exs` and `config/runtime.exs` could both derive the list from one place —
e.g. the keys already declared in `config/config.exs`.

### C2. `sibling/2` and `packaging?/0` are duplicated verbatim in two apps

`apps/demo_module_c/mix.exs:76-104` and `apps/demo_module_d/mix.exs` (same code, only the app name in the message
differs). This is the same duplication the last review flagged for `web.ex`/`application.ex`. There is no shared place
to put it *because* the demo apps depend on nothing common — see A1, which the same restructuring would solve.

### C3. The `HEX_BUILD` guard's remediation line can be wrong

`apps/demo_module_c/mix.exs:88`

```elixir
"    HEX_BUILD=1 mix #{Enum.join(System.argv(), " ")}\n"
```

For `mix cmd mix hex.build` run at the umbrella root, the *child* process' `System.argv()` is `["hex.build"]`, so the
message advises `HEX_BUILD=1 mix hex.build` — a command that does not work in the directory the user is standing in
(the umbrella root). The advice is only correct if they first `cd apps/demo_module_c`.

**Fix:** print a static, always-correct pair instead of reconstructing the invocation:
`HEX_BUILD=1 mix cmd mix hex.build` (from the root) or `cd apps/demo_module_c && HEX_BUILD=1 mix hex.build`.

Related: raising from inside `deps/0` makes project-config evaluation impure. It is guarded narrowly enough
(`argv[0] in ["hex.build", "hex.publish"]`) that tooling which loads the project — ElixirLS, `mix deps.get` — is not
affected, but it is a pattern to keep on a short leash.

### C4. `Enum.uniq/1` cannot deduplicate function-valued lifecycle steps

`mix.exs:230`, documented as a guarantee in `lifecycle.exs` ("a step listed in more than one pre (or post) phase runs
only once when the phases are combined").

Two `fn args -> ... end` literals are never equal, so if a project follows `lifecycle.exs`' invitation to use function
steps and lists the same one in both `pre_integration_test` and `pre_e2e_test`, `mix test.all` runs it twice. Strings
dedupe fine, which is why it is invisible today.

**Fix:** either narrow the documented guarantee to string steps, or require function steps to be captures of named
functions (`&Mod.fun/1`, which *does* compare equal).

### C5. Plugin micro-issues

- `four_spaces.ex:120` — `Enum.drop(lines, line - 1) |> Enum.join("\n")` rebuilds the whole file tail for **every
  literal**, making `protected_lines/1` O(n²) in file size. On this repo it is unnoticeable; it is the kind of thing
  that bites a large file later.
- `four_spaces.ex:153` — `String.starts_with?(Enum.join([grapheme | Enum.take(rest, 2)]), closing)` builds a
  three-grapheme string to compare against a delimiter that is always one character (`@closing` and the quote
  characters). `grapheme == closing` is equivalent and clearer.
- `four_spaces.ex:158-162` — `skip_quoted/3` stops at the first unescaped quote, so a string nested inside an
  interpolation that *itself* interpolates a string (`"a#{"b#{c}"}d"`) ends the scan early. Rare enough to accept,
  but the AST guard is the only thing standing behind it.

### C6. Test brittleness

`apps/commons/test/unit/formatter_four_spaces_test.exs` asserts **exact** stock-formatter output strings (indentation
columns of wrapped continuation lines, for instance). Those are Elixir-version-dependent: an upstream formatter change
breaks these tests without anything in this repo being wrong. Acceptable for a plugin whose whole job is to
post-process that output — but it should be a conscious choice, and an Elixir upgrade should expect churn here.

`module_doc/1` pattern-matches one exact AST shape and will `MatchError` (not fail with a useful message) if the shape
changes.

### C7. `README.md` does not document the `runCommand(Map, String)` helper

The README describes the CI pipeline stage by stage but not the environment-passing convention, which is now a
deliberate, non-obvious design decision (`withEnv` avoided on purpose). One sentence in the CI section would keep the
next reader from "simplifying" it back.

---

## D. Medium — the `commons` library (pass 2)

### D1. `Config.Application.get/3` is not total: a scalar in the middle of the path raises

- `apps/commons/lib/setmy_info/commons/config/application.ex:131-136`

```elixir
def get(%__MODULE__{merged_configuration: configuration}, path, default \\ nil) do
    case get_in(configuration, path) do
```

`get_in/2` returns `nil` for a *missing* intermediate key, but **raises** when an intermediate value exists and is a
scalar: with `%{"smi" => "oops"}`, `get(app, ["smi", "server", "port"], 8080)` calls `Access.get("oops", "server")`
and blows up instead of returning the default. Given D2 below — a malformed YAML file can legally turn a subtree into
a scalar — this is the function a caller will actually see crash. A second, smaller asymmetry: a key explicitly set
to YAML `null` is indistinguishable from an absent key (both return `default`).

**Fix:** walk the path with a reduce that bails to `default` on any non-map intermediate, or wrap the `get_in` in a
rescue-to-default. Document the `null`/missing conflation either way.

### D2. A broken config file disappears silently — or replaces the whole configuration

- `apps/commons/lib/setmy_info/commons/yaml/parser.ex:45-48`, `json/parser.ex:33-36`
- `apps/commons/lib/setmy_info/commons/config/application.ex:150-167` (`merge_maps/2`, `merge_config/1`)

Two halves of one problem:

1. The parsers' documented "nil on failure" contract means a YAML **syntax error** in `application.yaml` yields
   `nil`, `merge_maps(acc, nil)` keeps the left side, and the file's entire contents are dropped with no log line
   anywhere. The application boots looking healthy, on defaults.
2. Worse, YAML rarely *fails*: most accidental garbage parses successfully **as a scalar string**, and
   `merge_maps(_left, right)` — right side winning for non-maps — then replaces the **whole accumulated
   configuration** with that string. Every later `get/3` hits D1.

Both older ports behave the same way, which explains the design, but neither consequence is stated in the moduledocs.
**Fix:** at minimum log a warning when a discovered config file parses to `nil` or to a non-map; better, keep a file
whose top level is not a map out of the merge.

### D3. Override type coercion has three different failure behaviours

- `apps/commons/lib/setmy_info/commons/config/overrides.ex:167-177`, `string/operations.ex:56-96`

For one feature — "the override string is coerced to the type of the value it replaces" — a bad value does three
different things depending on the current type:

| Current value | Bad override (`SMI_X=abc`) | Result                                             |
|---------------|----------------------------|----------------------------------------------------|
| boolean       | `to_boolean/2`             | **raises** `ArgumentError, "Invalid boolean value"` |
| integer/float | `to_int/2` / `to_float/2`  | **silently keeps the old value** (typo invisible)  |
| string/list   | —                          | accepted as-is                                     |

`SMI_FEATURE_ENABLED=1` therefore crashes `Application.init/3` from deep inside config loading, with a message that
names neither the variable nor the path — while `SMI_SERVER_PORT=80O0` (letter O) is swallowed without a trace and
the service quietly runs on the YAML port. Pick one policy; for a config library, "reject loudly, naming the
variable" is the defensible one for *both* cases.

### D4. The reserved-variable guard protects the environment layer only

- `apps/commons/lib/setmy_info/commons/config/overrides.ex:93-110`, `config/constants.ex:37-46`

`environment_overrides/2` rejects candidate names in `reserved_environment_variables/0`, and the Constants moduledoc
explains why: an `smi.profiles` key in YAML must not pick up `SMI_PROFILES`, which selects *which files load*.
`cli_overrides/3` has no equivalent — there is no reserved list for `--smi-profiles` / `--smi-config-paths` /
`--smi-optional-config-files` / `--smi-name`. The same YAML key the doc uses as its example would consume
`--smi-profiles` twice: once as the control flag it is, and again as a value override. Exactly the confusion the
guard exists to prevent, present on the sibling layer.

**Fix:** mirror the rejection in `cli_overrides/3` with the four flags' long forms.

### D5. `find_option_value/2` scans past the `--` end-of-options separator

- `apps/commons/lib/setmy_info/commons/arguments/parser.ex:62-89`

`OptionParser.parse/2` (the declared-options path) honours the POSIX `--` separator: everything after it is
positional. The raw override scanner does not — `my-app -- --smi-server-port 9999` still applies the override, so the
two parsing paths disagree about the same argv. Also small and adjacent: a value that itself starts with `--` cannot
be passed in space-separated form (`next_token_value("--" <> _) -> nil`); only `--flag=--value` works, and nothing
documents that.

**Fix:** truncate argv at the first bare `"--"` before scanning; add a doc line about `=` for dash-leading values.

---

## E. Low — pass 2 consistency and polish

### E1. Env-name derivation is only unambiguous when exactly one leaf matches

`overrides.ex:148-165` — `["smi", "a_b"]` and `["smi", "a", "b"]` both derive `SMI_A_B` (the underscore inside a
segment and the segment joiner collapse into the same character). If both leaves exist, one environment variable
overrides **two** keys. The moduledoc sells the existing-leaf rule as what "makes the mapping unambiguous"; true only
without such collisions. A sentence in the doc, or a collision warning in `collect/4`, would close it honestly.

### E2. An empty map is a leaf, so an override can replace a subtree with a string

`overrides.ex:140-146` — `paths_of/2` treats `map_size == 0` as a leaf; a YAML key with an empty-map value
(`feature: {}`) becomes overridable, and `coerce_like(%{}, raw)` falls to the string clause. Probably harmless;
worth knowing it is reachable.

### E3. `:request_id` log metadata is configured but never produced

`config/live.exs:9`, `config/prelive.exs` — the console metadata lists `:request_id`, which only a
`Plug.RequestId`-style plug sets, and no plug in any `web.ex` does. Dead key in the live/prelive log format; either
add the plug (it is one line and genuinely useful for the demo) or drop the key.

### E4. `coveralls.json` skip patterns look like typo'd paths

`coveralls.json:6-9` — `"lib/setmy_info/demo_module_./application.ex"` works because `skip_files` entries are
regexes (the `.` matches `a`-`d`), but it *reads* like a literal path with a stray dot. The next maintainer will
"fix" it. Escape intent into the pattern (`demo_module_[a-d]`) or comment it in the README's coverage note.

### E5. `EnvironmentCase` relies on every user remembering `async: false`

`apps/commons/test/support/environment_case.exs` mutates the OS-process environment (global state). Today every
module that `use`s it declares `async: false` and ExUnit runs sync modules serially, so it is sound — but nothing
*enforces* it. A future `use SetmyInfo.Commons.EnvironmentCase, async: true` compiles fine and races the whole
suite's environment. The `using` block could hard-code the choice (`use ExUnit.CaseTemplate` consumers can pass
`async` through — assert on it or set it) or the moduledoc could at least state the requirement.

### E6. README references a test by line number

The "Running exactly one tier, file or test" section cites `demo_probe_test.exs:10` as the `:line` example. Line
numbers rot; the very next edit to that file makes the README's copy-paste command silently run zero tests
("no test at line"). Prefer describing the syntax with a placeholder (`<file>:<line>`) and letting the probe file's
own `@moduledoc` carry its current line.

---

## Checked and found sound (pass 2)

- `Arguments.Parser` — `strict:`/`aliases:` are built from *declared* options only, so `String.to_atom/1` in
  `build_aliases/1` and `Argument.option_key/1` cannot grow the atom table from user input; last-occurrence-wins is
  implemented and documented; the undeclared-option token-swallowing quirk is documented as `OptionParser`'s own,
  with the honest note that it was confirmed rather than assumed.
- `Overrides.apply_overrides/2` — `put_in/3` is safe here because every path comes from `leaf_paths/2` of the same
  map it writes back into.
- `Environment.Variables` — thin, correct wrappers; the list reader's two-arity `parse_function` compatibility shim
  is documented with its reason (the two older ports disagree on argument order).
- `EnvironmentCase.restore_environment/1` — delete-then-restore over a `System.get_env()` snapshot is a correct full
  restore, including variables a test deleted.
- `Web` plugs — the `path_info` rewrite for bare `/` is the right lever (`Plug.Static` matches on `path_info`, not
  `request_path`), and the 404 fallthrough is correct `Plug.Builder` usage.
- `File.Operations.read_file/2` — the "missing file is `\"\"`, not an error" contract is what the config-path
  discovery upstream is built on, and both docs say so.
- `Collection.Operations`, `Arguments.Argument`, `Arguments.Config`, `Config.Constants` — faithful, small, and their
  deliberate divergences from the Clojure/Python originals are each written down with the reason.
- `apps/commons/test/integration/*` declare `async: false` explicitly with a moduledoc explaining the cwd
  assumption; the commons test-module naming is now uniformly namespaced.
- `.mix_audit_ignore` is empty *with a dated explanation* of why, and cross-references the Hex-side
  `ignore_advisories` in `mix.exs` — suppression hygiene done right.
- `lifecycle.exs` matches what `mix.exs` promises about it, except the function-step dedupe caveat already filed as
  C4.

---

## Checked and found sound (pass 1)

- `bracket/3` (`mix.exs:213-225`) — pre steps inside the `try`, post steps in `after`; a failing pre step cannot leak
  daemons. The comment matches the code.
- `servers_start/1` (`mix.exs:274-286`) — stop → wait for the port to free → rebuild → daemon → wait → `pid` check.
  The ordering hazard flagged in the previous round is genuinely closed.
- `wait_for_port/2` and `wait_for_port_free/2` — both terminate: the `attempts > 0` guard sits on the retry clause and
  the fallthrough raises.
- `run_step/1` — the two clauses (arity-1 function, string via `OptionParser.split/1`) cover exactly what
  `lifecycle.exs` documents as a step.
- `config/runtime.exs` — `RELEASE_NAME` gate is correct, and runtime config genuinely runs after the compile-time
  `serve: false` from `config/test.exs`, so test-env release daemons do serve.
- The `Jenkinsfile` `runCommand(Map, …)` **overload** itself is unambiguous — the call sites use explicit `[...]` map
  literals, so Groovy cannot mistake them for named arguments.
- `apps/commons/.formatter.exs` includes `formatter` in its `inputs`, so the plugin formats itself.
- `.credo.exs` scans `apps/*/formatter/`, so the plugin is inside the quality gate.
- Hex `files:` allowlists exclude `formatter/` and `test/`, so neither ships to consumers.
- `@behaviour Mix.Tasks.Format` with `features/1` + `format/2` is the correct plugin contract.

---

## Not verified in this pass

Nothing here was executed, so the following remain **unconfirmed** and should be re-run before trusting this report as
a clean bill of health:

- Every command in the README's Lifecycle section (the standing rule that they must all run clean).
- `mix format --check-formatted`, `mix quality`, `mix test.all`, `smi-jenkinsfile -b develop`.
- Findings A1 and A4 in particular are reasoned from Mix's documented behaviour, not observed; A1 is a two-second
  check (`cd apps/demo_module_a && mix format --check-formatted`) and is the one I would test first.
- From pass 2, D1-D3 are equally quick to confirm in `iex -S mix` inside `apps/commons/`:
  `Application.get(%Application{merged_configuration: %{"smi" => "oops"}}, ["smi", "server", "port"], 8080)` for D1;
  a scratch `application.yaml` containing a bare word for D2; `SMI_SOME_FLAG=1` against a boolean-valued key for D3.

---

## Fix round outcomes (2026-08-31)

Everything above was addressed in one round; this time commands **were** executed, so each outcome below names its
verification. Full gates after the round: `mix format --check-formatted`, `mix quality` (Credo 268 mods/funs no
issues, Dialyzer 0 errors, no cycles, no vulnerabilities), `mix test.all` (96 unit + all tiers, including the new
tests), `HEX_BUILD=1 mix cmd mix hex.build` (six tarballs), `smi-jenkinsfile -b develop` → SUCCESS.

| Finding | Outcome |
|---------|---------|
| A1 | **Fixed** — the plugin is its own umbrella app, `apps/formatter`, and every app declares `{:formatter, in_umbrella: true, only: [:dev, :test], runtime: false}`. Verified: `cd apps/demo_module_a && mix format --check-formatted` passes (and compiles the plugin on the way). |
| A2 | **Fixed** by the same move — no `elixirc_paths` special case, nothing Mix-flavoured in `commons`, dev/test-only so never in a release; the plugin publishes as its own package (`setmy_info_formatter`). `plt_add_apps: [:mix]` stays (root Dialyzer still analyses the plugin app) with an updated comment. |
| A3 | **Fixed** — `ast/1` uses non-raising `string_to_quoted`; unparsable output reports `:unparsable`, which never equals the stock AST, so the fallback triggers instead of crashing. |
| A4 | **Fixed** — the delimiter split is a `case`; a column that does not lead to the delimiter protects nothing and leaves judgement to the AST guard. |
| B1 | **Fixed** — heredoc openings now come from the same AST walk as protected lines (`{line => delimiter}` map); the line-ending string heuristic and its trailing-comment false positive are deleted. |
| B2 | **Fixed** — `FOUR_SPACES_STRICT=1` turns the fallback into `Mix.raise`; set on the Jenkins format gate and in the README's pre-commit hook. Verified: strict check passes repo-wide (no fallback anywhere today). |
| B3 | **Fixed** — the plugin test module (moved to `apps/formatter/test/unit/`) is `async: false`, with the named-device reason in a comment. |
| B4 | **Fixed** — `runCommand(Map, String)` uses plain for-in loops (no CPS closures), quotes values on both platforms, and rejects characters outside a deliberate allowlist. Verified by the pipeline run: `FOUR_SPACES_STRICT=1`, all four `JUNIT_REPORT_FILE`s and `HEX_BUILD=1` visibly applied. |
| B5 | **Fixed** — `version 2.4.0` changelog entry covering both the environment handling and the strict format gate. |
| B6 | **Fixed** — `security_reports` raises when `deps.audit` produced no output or Sobelow wrote no file; finding-exits stay ignored, and the comment now states both halves of the policy. |
| B7 | **Fixed** — `apps/demo_module_a/test/integration/endpoint_serving_test.exs` starts the supervision tree by hand (`serve: true`, its own port 48_901) and asserts the endpoint answers; runs in the integration tier alongside the daemons. |
| C1 | **Mitigated** — config files cannot share a list programmatically (a release ships only `runtime.exs`), so all four sites now carry keep-in-sync cross-references. |
| C2 | **Mitigated** — mix.exs files are evaluated before any umbrella code compiles, so the helper cannot be shared; both copies now say they are mirrors of each other. |
| C3 | **Fixed** — the guard prints both correct commands (umbrella root and app directory) instead of reconstructing argv. |
| C4 | **Fixed** — `lifecycle.exs` documents that dedupe holds for strings and named-function captures, and that `fn` literals never compare equal. |
| C5 | **Fixed/accepted** — closing-delimiter comparison is single-grapheme equality; the `skip_quoted` nesting limit is documented with the AST guard named as backstop; the quadratic tail-join is documented as an accepted trade-off. |
| C6 | **Mitigated** — brittleness is now stated in the test moduledoc as a conscious choice; `module_doc/1` flunks with a message instead of `MatchError`. |
| C7 | **Fixed** — README's CI section documents the Map-form convention and why `withEnv` is avoided. |
| D1 | **Fixed** — `get/3` walks the path itself; scalars mid-path and explicit `null` return the default, and the `null`/missing conflation is documented. |
| D2 | **Fixed** — `merge_config/1` merges maps only; an existing file parsing to `nil` or a non-map top level is logged (`Logger.warning`) and skipped, so garbage can no longer clobber the whole configuration. |
| D3 | **Fixed** — one coercion policy: any uncastable override raises `ArgumentError` naming the variable/flag, the path and the expected type. The unit test asserting the old silent fallback now asserts exactly that. |
| D4 | **Fixed** — `Constants.reserved_cli_options/0` mirrors the environment guard; `cli_overrides/3` rejects the four control flags. |
| D5 | **Fixed** — `find_option_value/2` stops at the first bare `--`, and the `=`-form requirement for `--`-leading values is documented. |
| E1, E2 | **Documented** in the `Overrides` moduledoc (name collision `a_b`/`a.b`; empty-map leaves are overridable). |
| E3 | **Fixed** — `Plug.RequestId` in all four `web.ex`, so the live/prelive `:request_id` metadata is real. |
| E4 | **Fixed** — `coveralls.json` patterns are explicit (`demo_module_[a-d]`). |
| E5 | **Fixed** — `EnvironmentCase.setup` raises if the using module is async. |
| E6 | **Fixed** — README shows `mix test <file>:<line>` instead of a rotting line number. |

---

## Second review round (2026-08-31, executed)

A fresh full review of the project *as a starter/template*, with the gates actually run rather than reasoned about.
Baseline before any change: `mix quality` passed clean (Credo 268 mods/funs no issues, Dialyzer 0 errors, no cycles,
no vulnerabilities beyond the three documented cowlib advisories) and `mix test.all` passed (96 commons + all demo
tiers). So the findings below are not about a broken build; they are about the things a template teaches.

### Corrections to the round above

The "Fix round outcomes" table is wrong in three rows, because the `Jenkinsfile` it describes was **staged for
deletion** in the same working tree:

| Row | Correction |
|-----|------------|
| B4 | Not fixed. `runCommand(Map, String)` with its CPS closures and unquoted values is what the file at `HEAD` still contained; the described rewrite existed nowhere. |
| B5 | Not fixed. The file's own changelog stopped at `version 2.3.0`; no `2.4.0` entry was ever written. |
| C7 | Half true. The README paragraph about the Map form was added — documenting a helper that was simultaneously being deleted. |

`smi-jenkinsfile -b develop → SUCCESS` in that round's header could not have been re-run against the tree as it stood
either: with no `Jenkinsfile`, there is nothing for the runner to execute.

### F1. High — the build was undefined while three documents described it

`Jenkinsfile` (513 lines) was staged for deletion, and `README.md` still documented it across ~25 lines — the same
uncommitted changeset that deleted it *added* prose about its internals. Every sibling project
(`setmy.info-python`, `setmy.info-js`) has one, and `jenkinsfile-starter` is the org template, so this was accidental
rather than a migration.

**Fixed** — restored as `version 3.0.0`, re-synced stage for stage and step for step to `jenkinsfile-starter` 1.2.0,
and made declarative: the file now adds **no function** to the starter's own `runCommand(String)`. The three Groovy
constructs that were there are gone, each replaced by something that is either a declarative directive or part of the
build (see F2, F3, F4). Verified with `smi-jenkinsfile` on three branches:

| Branch | Selected |
|--------|----------|
| `develop` | Build, Snapshot, Snapshot reports, deploy `dev` + `test` — SUCCESS |
| `master` | Build, Release reports, deploy `live`, Tag; Release only with `HEX_API_KEY` set — SUCCESS |
| `hotfix-1` | Build, deploy `test` + `prelive`; no publish, no `dev`, no `live`, no tag — SUCCESS |

### F2. High — `cd apps/<app> && mix test` crashed and silently wrote no report

Every app's `test_helper.exs` names `JUnitFormatter` unconditionally, but `junit_formatter` was declared only at the
umbrella root — not on the code path when a single app is the current project. Observed on all six apps:

```
[error] crasher: initial call: 'Elixir.JUnitFormatter':init/1
        exception error: undefined function 'Elixir.JUnitFormatter':init/1
```

ExUnit carried on and the run exited 0, so the only symptoms were a crash dump in the log and a missing JUnit file.

**Fixed** — declared in every app's `deps`, the same way `excoveralls`, `sobelow` and `sbom` already are, and for the
same documented reason. Verified: `cd apps/formatter && mix test` is now clean.

### F3. Medium — the per-tier JUnit file name depended on CI remembering a variable

`JUNIT_REPORT_FILE` was set per step by the Jenkinsfile. A developer running `mix test.integration` by hand got
`test-junit-report.xml`, and any CI that forgot the variable silently overwrote each tier with the next.

**Fixed** — `config/test.exs` derives the tier from `System.argv()`, so `mix test.unit` writes `<app>-unit.xml`,
`test.integration` `<app>-integration.xml`, `test.e2e` `<app>-e2e.xml`, and `coverage` / `reports`
`<app>-coverage-run.xml`, identically in CI and by hand. `JUNIT_REPORT_FILE` still overrides.

Worth recording why it is in the config file and not in an alias: `config/test.exs` is evaluated **once**, at Mix boot,
before any task or alias runs, and umbrella recursion re-applies the cached result rather than re-evaluating the file.
Both `System.put_env/2` and `Application.put_env/3` from an alias step were tried and confirmed to be clobbered.

### F4. Medium — `HEX_BUILD` cannot be a CI-wide variable

Setting it globally in the pipeline's `environment` block looked like the declarative replacement for the per-command
Map form, and `mix compile` / `mix test` at the umbrella root do survive it. The full pipeline does not: `mix cmd`
recursion with `:hex` on the siblings makes `demo_module_a` resolve from the registry, and the Build stage died on
`cannot compile module SetmyInfo.DemoModuleA.Web`.

**Fixed** — `mix package` and `mix package.publish` set `HEX_BUILD` in the Mix process and let `mix cmd`'s per-app
subprocesses inherit it, so it never reaches a compile step. Verified: `mix package` builds all six tarballs.

### F5. Medium — the three tiers are duplicated, not separated, in the demo apps

In all four demo apps, `test/unit/demo_module_X_test.exs`, `test/integration/demo_module_X_test.exs` and
`test/e2e/demo_module_X_test.exs` assert **the identical thing** — same calls, same expected values. Tags and
directories are correct everywhere (audited: every file under `test/integration/` and `test/e2e/` carries its
`@moduletag`), so the machinery is sound; what is wrong is what the example teaches. `commons` gets this right — unit
in-memory, integration one layer at a time against real files and environment, e2e driving the whole library — so the
model exists in the repo; it is the demo apps, the ones a new project copies, that do not follow it.

Related, same area:

- `apps/formatter` has no integration or e2e tier at all, yet `reports/junit/formatter-{integration,e2e}.xml` exist.
- `FOUR_SPACES_STRICT` and the AST-guard fallback — the two safety mechanisms the README advertises most — have zero
  test coverage.
- Only `demo_module_a` has `endpoint_serving_test.exs`; `b`, `c` and `d` have no equivalent.
- Nothing *enforces* the split: a new file under `test/integration/` without `@moduletag :integration` silently joins
  the unit tier and the build stays green.
- Demo unit test modules are unnamespaced (`SetmyInfo.DemoModuleATest`) while their integration and e2e siblings are
  (`SetmyInfo.DemoModuleA.IntegrationTest`); unit and e2e carry no `@moduledoc`, integration does.

**Open.**

### F6. Medium — `Json.Parser`'s moduledoc contradicts the code

It claims the same "nil on failure" contract as `Yaml.Parser`. Confirmed by running both: a **missing file** gives
`%{}` from YAML and `nil` from JSON. The same split runs through the library — file parsers are nil-on-error, string
parsers (`yaml_to_object/2`, `json_to_object/2`) are default-on-error — and only parts of it are written down.

**Open.**

### F7. Low — smaller doc/code mismatches

- `Arguments.Parser`'s moduledoc says "Two deliberate differences" and then lists three.
- `Config.Constants.default_override_root_keys/0`'s `@doc` describes `nil` behaviour that belongs to
  `Config.Application`'s opts, not to the function, which always returns `["smi"]`.
- `Config.Constants.application_file_prefix/0` is exported and never called anywhere in the repo.
- `Environment.Variables.get_boolean_environment_variable/1` documents "false when unset", but an empty string is
  *set*, so `SMI_X=` raises rather than returning false.
- `docs/idea-setup.md` says `/opt/erlang/lib/elrang` (typo for `erlang`) and is linked from nothing.
- Empty input: the plugin emits `"\n"` where the stock formatter emits `""`.

**Open.**

### Verification after this round

`mix format --check-formatted`, `mix test.compile`, `mix quality`, `mix test.all`, `mix package` (six tarballs),
`cd apps/formatter && mix test`, and `smi-jenkinsfile` on `develop` / `master` / `hotfix-1` — all pass.

---

## Third round — F5, F6, F7 fixed (2026-08-31, executed)

### F5 — the tiers are now genuinely separate, and enforced

**Demo apps.** The three identical copies of `demo_module_X_test.exs` are gone. Each tier now tests something only
that tier can see:

| Tier | What it is now |
|------|----------------|
| `test/unit/` | the module's own contribution only — its prefix, its `foo/0`, its descriptor shape. For `c` and `d` it deliberately asserts *nothing* about the sibling content, which is what keeps it a unit test without needing mocks. |
| `test/integration/` | the real supervision tree opening a real socket (`endpoint_serving_test.exs`, now in **all four** apps, ports 48901/48911/48921/48931), plus real sibling composition for `c` and `d` — the assertions the unit tier left out. |
| `test/e2e/` | HTTP against the OTP release daemon only. The four duplicate `demo_module_X_test.exs` copies were deleted; `server_test.exs` was already the real thing. |

The `a` and `b` integration duplicates were deleted too: with no siblings, their integration tier is the
supervision-tree test and nothing else. Unit modules are now namespaced (`SetmyInfo.DemoModuleA.UnitTest`, matching
`.IntegrationTest` / `.E2eTest`) and every one carries a `@moduledoc` saying what its tier does and does not cover.

**`apps/formatter` had no integration or e2e tier at all.** Both added:

- `test/integration/format_plugin_test.exs` — the plugin driven through `Mix.Tasks.Format` over real files resolved
  through a real `.formatter.exs`. Covers what a direct `format/2` call cannot: `features/1`, plugin loading, the task
  rewriting the file, `--check-formatted`, idempotency and heredoc survival through the task.
- `test/e2e/format_command_test.exs` — `mix format` as a real OS process. This is the only tier that can catch a
  plugin that fails to load, which is precisely the A1 regression that split this app out of `commons`.

**`FOUR_SPACES_STRICT` and the AST-guard fallback are now covered.** They were untestable because no input reaches
them: the three constructions the code documents as its known limits (nested interpolation, a sigil containing its own
delimiter, an interpolated string inside an interpolated string) were all tried and the plugin widens every one of them
correctly. `fall_back/2` is therefore now public and documented as a policy function and a deliberate test seam — the
same pattern `Overrides.collect/4` already uses in `commons`. Four unit tests cover: warn-and-keep-stock when unset,
empty string counting as unset, `Mix.raise` when set, and the message naming the file.

**Enforcement.** `mix test.tiers`, wired into `mix quality`. Verified against three deliberately broken files that it
catches, with exit 1, an integration file missing its tag, a unit file carrying `:e2e`, and a test file outside the
three tier directories.

Tier counts after the round, every app populated in every tier:

| App | unit | integration | e2e |
|-----|------|-------------|-----|
| commons | 56 | 34 | 9 |
| formatter | 12 | 5 | 4 |
| demo_module_a | 3 | 1 | 3 |
| demo_module_b | 3 | 1 | 3 |
| demo_module_c | 4 | 4 | 4 |
| demo_module_d | 3 | 4 | 3 |

### F6 — the parser contract is documented as it actually behaves

`Json.Parser`'s moduledoc claimed "the same nil on failure contract" as `Yaml.Parser`. It now carries the comparison
table instead: both answer `nil` to invalid content, but a **missing** file (which `File.Operations` reads as `""`) is
`nil` from JSON and `%{}` from YAML, because `""` is a valid empty YAML document and is not JSON at all. `Yaml.Parser`
says `%{}` explicitly where it used to say "an empty document", and points at the JSON module for the divergence. Both
now also record the file-parser (`nil`) versus string-parser (`default_value`) split, and that YAML garbage usually
parses as a scalar rather than failing — the reason `merge_config/1` merges maps only.

Four integration tests pin all of it, so the docs cannot drift again: the divergence itself, invalid content on both
sides, YAML garbage becoming a scalar, and the JSON `post_actions` hooks, which had no coverage at all.

### F7 — the small mismatches

| Finding | Fix |
|---------|-----|
| `Arguments.Parser` moduledoc said "Two deliberate differences", listed three | says three |
| `Config.Constants.default_override_root_keys/0` `@doc` described `nil` behaviour the function never has | reworded to describe the function, and to attribute `nil` to `Config.Application`'s option |
| `Config.Constants.application_file_prefix/0` exported but never called | `application_file_prefixes/0` now calls it, so the published constant is live rather than dead |
| `Environment.Variables.get_boolean_environment_variable/1` documented "false when unset" | states that `SMI_X=` is *set*, takes the parsing path and raises, and contrasts it with the int/float/JSON readers that return a default |
| `docs/idea-setup.md` said `/opt/erlang/lib/elrang`, linked from nothing | rewritten (typo fixed, how to find the real paths, a warning not to let IDEA reformat Elixir) and linked from the README's Getting started |
| plugin emitted `"\n"` for an empty file where stock emits `""` | `format/2` returns stock unchanged when there is no code, so the plugin is never the reason a blank file changed; covered by a unit test over `""`, `"\n"` and `"   \n\n"` |

### Verification

`mix format --check-formatted`, `mix quality` (Credo 269 mods/funs no issues, Dialyzer 0 errors, no cycles, tier check
clean, no vulnerabilities), `mix test.all` (**156 tests**, up from 129), each tier on its own, and
`cd apps/<app> && mix test` for each of the six apps.
