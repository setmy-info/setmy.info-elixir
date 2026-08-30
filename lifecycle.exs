# The PROJECT-SPECIFIC side of the test lifecycle.
#
# mix.exs defines the generic phases, the shape of Maven failsafe's
#
#     pre-integration-test -> integration-test -> post-integration-test
#     pre-e2e-test         -> e2e-test         -> post-e2e-test
#
# and guarantees their ordering: every pre step runs before the tier, every
# post step runs after it - also when the tier fails. From the point of view of
# the tiers (`mix test.integration`, `mix test.e2e`, `mix test.all`,
# `mix coverage`) and of CI there are only "pre" and "post"; WHAT those do is
# decided here, per project. A step is either a Mix task invocation as a
# string (`"server.start"`, `"cmd docker compose up -d"`, `"ecto.migrate"`) or
# a `fn args -> ... end`. Steps run in list order for pre and are given in the
# order they should run for post; a step listed in more than one pre (or
# post) phase runs only once when the phases are combined, as in
# `mix test.all`.
#
# In this project the running instances the integration and e2e tiers talk to
# are OTP release daemons, so the steps are `server.start` / `server.stop`
# (both defined in mix.exs). A project using this umbrella as its template
# adds what its own tiers need next to them: a database, a message broker, a
# mock of a third-party API, seeding test data, ...
defmodule SetmyInfo.Elixir.Lifecycle do
    @type step :: String.t() | (OptionParser.argv() -> any())

    @spec steps(:pre_integration_test | :post_integration_test | :pre_e2e_test | :post_e2e_test) ::
                    [step()]
    def steps(:pre_integration_test), do: ["server.start"]
    def steps(:post_integration_test), do: ["server.stop"]

    def steps(:pre_e2e_test), do: ["server.start"]
    def steps(:post_e2e_test), do: ["server.stop"]
end
