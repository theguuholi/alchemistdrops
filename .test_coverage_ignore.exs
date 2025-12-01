[
  Alchemistdrops.Application,
  AlchemistdropsWeb.Layouts,
  Alchemistdrops.Repo,
  AlchemistdropsWeb.Telemetry,
  Mix.Tasks.Coverage.Index,
  AlchemistdropsWeb.ErrorHTML,
  # Ignore all modules in test/support/fixtures
  ~r/^Alchemistdrops\.[A-Za-z]+Fixtures$/,
  ~r/^Elixir\.Alchemistdrops\.[A-Za-z]+Fixtures$/,
  ~r/^Elixir\.AlchemistdropsWeb\.[A-Za-z]+Fixtures$/,
  ~r/^Elixir\.Alchemistdrops\.Test\.Support\.Fixtures\..*$/,
  ~r/^Elixir\.Alchemistdrops\.Test\.Support\.Fixtures$/,
  # For thoroughness: ignore everything in test/support/fixtures recursively
  ~r/^Elixir\.Alchemistdrops\.Test\.Support\.Fixtures(\..*)?$/
]
