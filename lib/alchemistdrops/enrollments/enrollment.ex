defmodule Alchemistdrops.Enrollments.Enrollment do
  @moduledoc """
  Represents a user's access and progress relationship with a course.

  An enrollment is the domain boundary between a learner and purchased course
  content. Its changeset enforces one enrollment per user/course pair and keeps
  lifecycle status and enrollment timestamps consistent.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @statuses ~w(active completed cancelled)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Lifecycle state of a course enrollment: active, completed, or cancelled."
  @type status :: String.t()

  @typedoc "Database identifier for the enrollment. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Identifier of the enrolled user. Nil before association."
  @type user_id :: Ecto.UUID.t() | nil

  @typedoc "Identifier of the enrolled course. Nil before association."
  @type course_id :: Ecto.UUID.t() | nil

  @typedoc "Timestamp when access to the course began. Nil before enrollment."
  @type enrolled_at :: DateTime.t() | nil

  @typedoc "Timestamp when the course was completed. Nil until completion."
  @type completed_at :: DateTime.t() | nil

  @typedoc "Timestamp when the enrollment was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the enrollment was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "An enrollment before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          user_id: user_id(),
          course_id: course_id(),
          status: status(),
          enrolled_at: enrolled_at(),
          completed_at: completed_at(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

  schema "enrollments" do
    field :status, :string, default: "active"
    field :enrolled_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :user, Alchemistdrops.Accounts.User
    belongs_to :course, Alchemistdrops.Courses.Course

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds an enrollment changeset and supplies an enrollment timestamp when absent.

  ## Examples

      iex> attrs = %{user_id: Ecto.UUID.generate(), course_id: Ecto.UUID.generate()}
      iex> changeset = Alchemistdrops.Enrollments.Enrollment.changeset(%Alchemistdrops.Enrollments.Enrollment{}, attrs)
      iex> {changeset.valid?, Ecto.Changeset.get_field(changeset, :status), is_struct(changeset.changes.enrolled_at, DateTime)}
      {true, "active", true}

      iex> Alchemistdrops.Enrollments.Enrollment.changeset(%Alchemistdrops.Enrollments.Enrollment{}, %{status: "unknown"}).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:user_id, :course_id, :status, :enrolled_at, :completed_at])
    |> validate_required([:user_id, :course_id])
    |> validate_inclusion(:status, @statuses)
    |> put_enrolled_at()
    |> unique_constraint([:user_id, :course_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:course_id)
  end

  defp put_enrolled_at(changeset) do
    case get_field(changeset, :enrolled_at) do
      nil -> put_change(changeset, :enrolled_at, DateTime.utc_now(:second))
      _ -> changeset
    end
  end
end
