defmodule Alchemistdrops.Repo.Migrations.CreateCourses do
  use Ecto.Migration

  def change do
    create table(:courses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :body, :text
      add :price, :integer, default: 0
      add :stripe_product_id, :string
      add :stripe_price_id, :string
      add :published, :boolean, default: false
      add :thumbnail_url, :text

      timestamps(type: :utc_datetime)
    end

    create index(:courses, [:published])
    create index(:courses, [:title])
  end
end
