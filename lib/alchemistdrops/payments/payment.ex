defmodule Alchemistdrops.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending completed failed refunded)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "payments" do
    field :amount, Money.Ecto.Amount.Type
    field :stripe_payment_intent_id, :string
    field :stripe_checkout_session_id, :string
    field :status, :string, default: "pending"
    field :metadata, :map

    belongs_to :user, Alchemistdrops.Accounts.User
    belongs_to :course, Alchemistdrops.Courses.Course

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :user_id,
      :course_id,
      :amount,
      :stripe_payment_intent_id,
      :stripe_checkout_session_id,
      :status,
      :metadata
    ])
    |> validate_required([:user_id, :course_id, :amount])
    |> validate_money(:amount)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:course_id)
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn
      ^field, %Money{amount: amount} when amount <= 0 -> [{field, "must be greater than 0"}]
      ^field, %Money{} -> []
      ^field, nil -> []
      ^field, _ -> [{field, "must be a valid money amount"}]
    end)
  end
end
