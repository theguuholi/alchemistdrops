defmodule Alchemistdrops.Repo.Migrations.AddDevToArticleUrlToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :dev_to_article_url, :string
    end
  end
end
