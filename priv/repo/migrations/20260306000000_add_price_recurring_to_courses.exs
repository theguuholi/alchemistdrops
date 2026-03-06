defmodule Alchemistdrops.Repo.Migrations.AddPriceRecurringToCourses do
  use Ecto.Migration

  def change do
    alter table(:courses) do
      add :price_recurring, :boolean, default: false, null: false
    end
  end
end
