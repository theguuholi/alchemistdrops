defmodule Alchemistdrops.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :course_id, references(:courses, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, size: 3, default: "USD"
      add :stripe_payment_intent_id, :string
      add :stripe_checkout_session_id, :string
      add :status, :string, default: "pending"
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:payments, [:user_id])
    create index(:payments, [:course_id])
    create index(:payments, [:status])
    create index(:payments, [:stripe_checkout_session_id])
  end
end
