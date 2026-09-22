defmodule Alchemistdrops.Repo.Migrations.AddDevToFieldsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :dev_to_article_id, :bigint
      add :dev_to_url, :string
      add :dev_to_synced_at, :utc_datetime
    end

    create unique_index(:posts, [:dev_to_article_id])
  end
end
