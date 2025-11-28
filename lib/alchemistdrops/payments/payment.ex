defmodule Alchemistdrops.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending completed failed refunded)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "payments" do
    field :amount, :decimal
    field :currency, :string, default: "USD"
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
      :currency,
      :stripe_payment_intent_id,
      :stripe_checkout_session_id,
      :status,
      :metadata
    ])
    |> validate_required([:user_id, :course_id, :amount])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_currency()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:course_id)
  end

  defp validate_currency(changeset) do
    case get_field(changeset, :currency) do
      nil ->
        changeset

      currency when is_binary(currency) ->
        if String.length(currency) == 3 and String.match?(currency, ~r/^[A-Z]{3}$/) do
          changeset
        else
          add_error(changeset, :currency, "must be a 3-letter currency code")
        end

      _ ->
        changeset
    end
  end
end
