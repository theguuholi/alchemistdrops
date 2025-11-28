defmodule Alchemistdrops.Repo.Migrations.MigratePaymentsToMoney do
  use Ecto.Migration

  def up do
    # Add new money column
    alter table(:payments) do
      add :amount_money, :money_with_currency
    end

    # Migrate existing data
    execute """
    UPDATE payments
    SET amount_money = ROW(
      (amount * 100)::integer,
      COALESCE(currency, 'USD')
    )::money_with_currency
    WHERE amount IS NOT NULL
    """

    # Remove old columns
    alter table(:payments) do
      remove :amount
      remove :currency
    end

    # Rename new column
    rename table(:payments), :amount_money, to: :amount
  end

  def down do
    # Add back old columns
    alter table(:payments) do
      add :amount_decimal, :decimal, precision: 10, scale: 2
      add :currency_string, :string, size: 3, default: "USD"
    end

    # Migrate data back
    execute """
    UPDATE payments
    SET
      amount_decimal = ((amount).amount / 100.0)::decimal(10,2),
      currency_string = (amount).currency
    WHERE amount IS NOT NULL
    """

    # Remove money column
    alter table(:payments) do
      remove :amount
    end

    # Rename back
    rename table(:payments), :amount_decimal, to: :amount
    rename table(:payments), :currency_string, to: :currency
  end
end
