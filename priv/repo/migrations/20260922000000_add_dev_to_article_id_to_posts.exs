defmodule Alchemistdrops.Repo.Migrations.AddDevToArticleIdToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :dev_to_article_id, :bigint
    end

    create unique_index(:posts, [:dev_to_article_id])
  end
end
