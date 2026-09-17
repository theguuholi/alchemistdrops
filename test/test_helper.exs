Mimic.copy(Alchemistdrops.Social.OpenRouterContentGenerator, type_check: true)
Mimic.copy(Alchemistdrops.Social.ReqLinkedInClient, type_check: true)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Alchemistdrops.Repo, :manual)

# ETS table for cross-process HTTP mock (LiveView runs in a different process)
:ets.new(:mock_http_ets, [:named_table, :public, :set])
