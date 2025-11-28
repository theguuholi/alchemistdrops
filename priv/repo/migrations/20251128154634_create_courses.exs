defmodule Alchemistdrops.Repo.Migrations.CreateCourses do
  use Ecto.Migration

  def change do
    create table(:courses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :body, :text
      add :price, :decimal, precision: 10, scale: 2, default: 0.00
      add :currency, :string, size: 3, default: "USD"
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
