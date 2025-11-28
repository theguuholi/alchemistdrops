defmodule Alchemistdrops.Courses.Course do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "courses" do
    field :title, :string
    field :description, :string
    field :body, :string
    field :price, :decimal, default: Decimal.new("0.00")
    field :currency, :string, default: "USD"
    field :stripe_product_id, :string
    field :stripe_price_id, :string
    field :published, :boolean, default: false
    field :thumbnail_url, :string

    has_many :lessons, Alchemistdrops.Courses.Lesson
    has_many :enrollments, Alchemistdrops.Enrollments.Enrollment
    has_many :payments, Alchemistdrops.Payments.Payment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(course, attrs) do
    course
    |> cast(attrs, [
      :title,
      :description,
      :body,
      :price,
      :currency,
      :stripe_product_id,
      :stripe_price_id,
      :published,
      :thumbnail_url
    ])
    |> validate_required([:title, :description])
    |> validate_length(:title, max: 255)
    |> trim_field(:title)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_currency()
  end

  defp trim_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
      _ -> changeset
    end
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
