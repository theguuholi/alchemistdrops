defmodule Alchemistdrops.Payments.Payment do
  @moduledoc """
  Represents money collected for a user's course purchase.

  Payments retain provider references and lifecycle metadata needed to reconcile
  checkout events with enrollments. The changeset protects positive amounts,
  supported statuses, and the user/course relationship.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @statuses ~w(pending completed failed refunded)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Lifecycle state reported for a payment: pending, completed, failed, or refunded."
  @type status :: String.t()

  @typedoc "Database identifier for the payment. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Identifier of the user that made the payment. Nil before association."
  @type user_id :: Ecto.UUID.t() | nil

  @typedoc "Identifier of the purchased course. Nil before association."
  @type course_id :: Ecto.UUID.t() | nil

  @typedoc "Amount charged for the course. Nil before payment construction."
  @type amount :: Money.t() | nil

  @typedoc "Stripe PaymentIntent identifier. Nil before Stripe creates one."
  @type stripe_payment_intent_id :: String.t() | nil

  @typedoc "Stripe Checkout Session identifier. Nil before checkout creation."
  @type stripe_checkout_session_id :: String.t() | nil

  @typedoc "Provider metadata stored with the payment. Nil when unavailable."
  @type metadata :: map() | nil

  @typedoc "Timestamp when the payment was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the payment was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A payment before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          user_id: user_id(),
          course_id: course_id(),
          amount: amount(),
          stripe_payment_intent_id: stripe_payment_intent_id(),
          stripe_checkout_session_id: stripe_checkout_session_id(),
          status: status(),
          metadata: metadata(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

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

  @doc """
  Builds a payment changeset and validates ownership, amount, and status.

  ## Examples

      iex> attrs = %{user_id: Ecto.UUID.generate(), course_id: Ecto.UUID.generate(), amount: Money.new(100, :USD)}
      iex> Alchemistdrops.Payments.Payment.changeset(%Alchemistdrops.Payments.Payment{}, attrs).valid?
      true

      iex> attrs = %{user_id: Ecto.UUID.generate(), course_id: Ecto.UUID.generate(), amount: Money.new(0, :USD)}
      iex> Alchemistdrops.Payments.Payment.changeset(%Alchemistdrops.Payments.Payment{}, attrs).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
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
    end)
  end
end
