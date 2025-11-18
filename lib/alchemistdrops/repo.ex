defmodule Alchemistdrops.Repo do
  use Ecto.Repo,
    otp_app: :alchemistdrops,
    adapter: Ecto.Adapters.Postgres
end
