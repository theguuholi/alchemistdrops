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

  @typedoc "Database identifier for the lesson. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Identifier of the course that owns the lesson. Nil before association."
  @type course_id :: Ecto.UUID.t() | nil

  @typedoc "Lesson title shown to learners. Nil before validation."
  @type title :: String.t() | nil

  @typedoc "Short lesson summary. Nil when it has not been provided."
  @type description :: String.t() | nil

  @typedoc "Long-form instructional content. Nil when it has not been provided."
  @type content :: String.t() | nil

  @typedoc "Zero-based lesson position within its course."
  @type order :: non_neg_integer()

  @typedoc "Lesson duration in minutes. Nil when duration is unknown."
  @type duration :: pos_integer() | nil

  @typedoc "Lesson video URL. Nil when the lesson has no video."
  @type video_url :: String.t() | nil

  @typedoc "Whether the lesson is visible to learners."
  @type published :: boolean()

  @typedoc "Timestamp when the lesson was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the lesson was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A lesson before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          course_id: course_id(),
          title: title(),
          description: description(),
          content: content(),
          order: order(),
          duration: duration(),
          video_url: video_url(),
          published: published(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
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
      iex> {changeset.valid?, changeset.changes.title}
      {true, "OTP"}

      iex> Alchemistdrops.Courses.Lesson.changeset(%Alchemistdrops.Courses.Lesson{}, %{course_id: Ecto.UUID.generate(), title: "Lesson", duration: 0}).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
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
