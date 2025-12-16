defmodule Alchemistdrops.Courses.Course do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "courses" do
    field :title, :string
    field :description, :string
    field :body, :string
    field :price, Money.Ecto.Amount.Type
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
      :stripe_product_id,
      :stripe_price_id,
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
