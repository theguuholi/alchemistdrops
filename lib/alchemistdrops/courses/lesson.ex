defmodule Alchemistdrops.Courses.Lesson do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lessons" do
    field :title, :string
    field :description, :string
    field :content, :string
    field :order, :integer, default: 0
    field :duration, :integer
    field :video_url, :string
    field :published, :boolean, default: false

    belongs_to :course, Alchemistdrops.Courses.Course

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lesson, attrs) do
    lesson
    |> cast(attrs, [
      :course_id,
      :title,
      :description,
      :content,
      :order,
      :duration,
      :video_url,
      :published
    ])
    |> validate_required([:course_id, :title])
    |> validate_length(:title, max: 255)
    |> trim_field(:title)
    |> validate_number(:order, greater_than_or_equal_to: 0)
    |> validate_number(:duration, greater_than: 0)
    |> foreign_key_constraint(:course_id)
  end

  defp trim_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
      _ -> changeset
    end
  end
end
