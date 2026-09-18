defmodule Alchemistdrops.Courses.Lesson do
  @moduledoc """
  Represents one ordered learning unit inside a course.

  Lessons carry the instructional content and publication state consumed by
  enrolled students. Their changeset keeps course ownership, ordering, and
  optional duration values valid.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "A lesson before or after persistence."
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          course_id: Ecto.UUID.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          content: String.t() | nil,
          order: non_neg_integer(),
          duration: pos_integer() | nil,
          video_url: String.t() | nil,
          published: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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

  @doc """
  Builds a lesson changeset and validates its course, title, order, and duration.

  ## Examples

      iex> course_id = Ecto.UUID.generate()
      iex> changeset = Alchemistdrops.Courses.Lesson.changeset(%Alchemistdrops.Courses.Lesson{}, %{course_id: course_id, title: "  OTP  ", order: 0})
      iex> {changeset.valid?, Ecto.Changeset.get_change(changeset, :title)}
      {true, "OTP"}

      iex> Alchemistdrops.Courses.Lesson.changeset(%Alchemistdrops.Courses.Lesson{}, %{course_id: Ecto.UUID.generate(), title: "Lesson", duration: 0}).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
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
    |> validate_duration()
    |> foreign_key_constraint(:course_id)
  end

  defp validate_duration(changeset) do
    case Ecto.Changeset.get_change(changeset, :duration) do
      nil -> changeset
      n when is_integer(n) and n > 0 -> changeset
      _ -> Ecto.Changeset.add_error(changeset, :duration, "must be greater than 0")
    end
  end

  defp trim_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
    end
  end
end
