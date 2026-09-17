defmodule Alchemistdrops.Repo.Migrations.CreatePostTaxonomy do
  use Ecto.Migration

  def change do
    create table(:post_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:post_categories, [:slug])

    create unique_index(:post_categories, ["lower(name)"],
             name: :post_categories_lower_name_index
           )

    create table(:post_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:post_tags, [:slug])
    create unique_index(:post_tags, ["lower(name)"], name: :post_tags_lower_name_index)

    create table(:posts_tags, primary_key: false) do
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:post_tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:posts_tags, [:post_id, :tag_id])
    create index(:posts_tags, [:tag_id])
  end
end
