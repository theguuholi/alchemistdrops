defmodule Alchemistdrops.Repo.Migrations.MigrateCoursesToMoney do
  use Ecto.Migration

  def up do
    # Add new money column
    alter table(:courses) do
      add :price_money, :money_with_currency
    end

    # Migrate existing data: Convert Decimal to integer cents
    execute """
    UPDATE courses
    SET price_money = ROW(
      (price * 100)::integer,
      COALESCE(currency, 'USD')
    )::money_with_currency
    WHERE price IS NOT NULL
    """

    # Handle NULL prices (treat as zero/free)
    execute """
    UPDATE courses
    SET price_money = ROW(0, 'USD')::money_with_currency
    WHERE price IS NULL
    """

    # Remove old columns
    alter table(:courses) do
      remove :price
      remove :currency
    end

    # Rename new column
    rename table(:courses), :price_money, to: :price
  end

  def down do
    # Add back old columns
    alter table(:courses) do
      add :price_decimal, :decimal, precision: 10, scale: 2
      add :currency_string, :string, size: 3, default: "USD"
    end

    # Migrate data back
    execute """
    UPDATE courses
    SET
      price_decimal = ((price).amount / 100.0)::decimal(10,2),
      currency_string = (price).currency
    WHERE price IS NOT NULL
    """

    # Remove money column
    alter table(:courses) do
      remove :price
    end

    # Rename back
    rename table(:courses), :price_decimal, to: :price
    rename table(:courses), :currency_string, to: :currency
  end
end
