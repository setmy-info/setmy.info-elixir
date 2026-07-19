# :httpc (used by the e2e server test, §7.5's real-HTTP-request requirement)
# needs :inets running; not started by default for a plain library app.
{:ok, _} = Application.ensure_all_started(:inets)

ExUnit.start()
