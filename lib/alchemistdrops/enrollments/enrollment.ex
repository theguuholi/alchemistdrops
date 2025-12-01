defmodule Alchemistdrops.Enrollments.Enrollment do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active completed cancelled)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "enrollments" do
    field :status, :string, default: "active"
    field :enrolled_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :user, Alchemistdrops.Accounts.User
    belongs_to :course, Alchemistdrops.Courses.Course

    timestamps(type: :utc_datetime)
  end

  @doc false
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

