defmodule Alchemistdrops.Courses.Course do
  @moduledoc """
  Represents a course offered through AlchemistDrops.

  A course owns its lessons and acts as the purchasable and enrollable learning
  unit. Its changeset protects the title and monetary invariants used by the
  catalog and checkout flows.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Database identifier for the course. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Course title shown in the catalog. Nil before validation."
  @type title :: String.t() | nil

  @typedoc "Short course summary. Nil before validation."
  @type description :: String.t() | nil

  @typedoc "Long-form course content. Nil when it has not been provided."
  @type body :: String.t() | nil

  @typedoc "Course price. Nil when the course has no configured price."
  @type price :: Money.t() | nil

  @typedoc "Stripe product identifier. Nil before the course is synchronized with Stripe."
  @type stripe_product_id :: String.t() | nil

  @typedoc "Stripe price identifier. Nil before the course is synchronized with Stripe."
  @type stripe_price_id :: String.t() | nil

  @typedoc "Whether the Stripe price is recurring."
  @type price_recurring :: boolean()

  @typedoc "Whether the course is visible in the public catalog."
  @type published :: boolean()

  @typedoc "Course thumbnail URL. Nil when no custom thumbnail has been provided."
  @type thumbnail_url :: String.t() | nil

  @typedoc "Timestamp when the course was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the course was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A course before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          title: title(),
          description: description(),
          body: body(),
          price: price(),
          stripe_product_id: stripe_product_id(),
          stripe_price_id: stripe_price_id(),
          price_recurring: price_recurring(),
          published: published(),
          thumbnail_url: thumbnail_url(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

  schema "courses" do
    field :title, :string
    field :description, :string
    field :body, :string
    field :price, Money.Ecto.Amount.Type
    field :stripe_product_id, :string
    field :stripe_price_id, :string
    field :price_recurring, :boolean, default: false
    field :published, :boolean, default: false
    field :thumbnail_url, :string

    has_many :lessons, Alchemistdrops.Courses.Lesson
    has_many :enrollments, Alchemistdrops.Enrollments.Enrollment
    has_many :payments, Alchemistdrops.Payments.Payment

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a course changeset and validates its catalog fields.

  ## Examples

      iex> changeset = Alchemistdrops.Courses.Course.changeset(%Alchemistdrops.Courses.Course{}, %{title: "  Elixir  ", description: "OTP"})
      iex> {changeset.valid?, Ecto.Changeset.get_change(changeset, :title)}
      {true, "Elixir"}

      iex> Alchemistdrops.Courses.Course.changeset(%Alchemistdrops.Courses.Course{}, %{title: "", description: ""}).valid?
      false
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(course, attrs) do
    course
    |> cast(attrs, [
      :title,
      :description,
      :body,
      :price,
      :stripe_product_id,
      :stripe_price_id,
      :price_recurring,
      :published,
      :thumbnail_url
    ])
    |> validate_required([:title, :description])
    |> validate_length(:title, max: 255)
    |> trim_field(:title)
    |> validate_money(:price)
  end

  defp trim_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
    end
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn
      ^field, %Money{amount: amount} when amount < 0 ->
        [{field, "must be greater than or equal to 0"}]

      ^field, %Money{} ->
        []
    end)
  end
end
