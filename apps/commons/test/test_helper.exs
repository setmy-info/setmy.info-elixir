# Shared ExUnit.CaseTemplate for the tiers ADR-0031 lets touch the
# environment. A `.exs` required from here rather than a `.ex` under an
# extra elixirc_path: this app's `elixirc_paths/1` stays `["lib"]` in every
# Mix env so `mix hex.build`'s file list and the compiled app never depend
# on test-only code, matching every other app in this umbrella.
Code.require_file("support/environment_case.exs", __DIR__)

ExUnit.start()
