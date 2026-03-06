defmodule Alchemistdrops.Enrollments do
  @moduledoc """
  The Enrollments context.

  Handles all operations related to user enrollments in courses including:
  - Enrolling users in courses
  - Checking enrollment status
  - Access control for courses and lessons
  - Managing enrollment lifecycle
  """

  import Ecto.Query, warn: false
  alias Alchemistdrops.Accounts.User
  alias Alchemistdrops.Courses.{Course, Lesson}
  alias Alchemistdrops.Enrollments.Enrollment
  alias Alchemistdrops.Repo
  alias Money

  ## Enrollment functions

  @doc """
  Enrolls a user in a course.

  Sets the enrolled_at timestamp and status to "active".

  Accepts either structs or IDs for both user and course.

  ## Examples

      iex> enroll_user(user, course)
      {:ok, %Enrollment{}}

      iex> enroll_user(user_id, course_id)
      {:ok, %Enrollment{}}

      iex> enroll_user(user, course)
      {:error, %Ecto.Changeset{}}

  """
  def enroll_user(user_id, course_id) when is_binary(user_id) and is_binary(course_id) do
    %Enrollment{}
    |> Enrollment.changeset(%{
      user_id: user_id,
      course_id: course_id,
      enrolled_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def enroll_user(%User{} = user, %Course{} = course) do
    enroll_user(user.id, course.id)
  end

  def enroll_user(%User{} = user, course) when is_map(course) do
    # Handle case where course is a map (for testing error cases)
    enroll_user(user.id, Map.get(course, :id))
  end

  @doc """
  Checks if a user is enrolled in a course.

  Returns true if the user has an active or completed enrollment.
  Returns false for cancelled enrollments or no enrollment.

  Accepts either structs or IDs for both user and course.

  ## Examples

      iex> user_enrolled?(user, course)
      true

      iex> user_enrolled?(user_id, course_id)
      false

  """
  def user_enrolled?(user_id, course_id) when is_binary(user_id) and is_binary(course_id) do
    query =
      from e in Enrollment,
        where: e.user_id == ^user_id,
        where: e.course_id == ^course_id,
        where: e.status in ["active", "completed"]

    Repo.exists?(query)
  end

  def user_enrolled?(%User{} = user, %Course{} = course) do
    user_enrolled?(user.id, course.id)
  end

  @doc """
  Checks if a user can access a course.

  Access is granted if:
  - User is an admin
  - User is enrolled in the course
  - Course is free (price = 0)

  ## Examples

      iex> can_access_course?(user, course)
      true

      iex> can_access_course?(user, course)
      false

  """
  def can_access_course?(%User{role: :admin}, _course), do: true

  def can_access_course?(%User{} = user, %Course{price: price} = course) do
    # Free courses (nil or zero price) are accessible to all authenticated users
    if price_zero_or_nil?(price) do
      true
    else
      user_enrolled?(user, course)
    end
  end

  defp price_zero_or_nil?(nil), do: true
  defp price_zero_or_nil?(%Money{amount: 0}), do: true
  defp price_zero_or_nil?(_), do: false

  @doc """
  Checks if a user can access a lesson.

  Access is based on whether the user can access the parent course.

  ## Examples

      iex> can_access_lesson?(user, lesson)
      true

      iex> can_access_lesson?(user, lesson)
      false

  """
  def can_access_lesson?(%User{} = user, %Lesson{} = lesson) do
    course = Repo.get!(Course, lesson.course_id)
    can_access_course?(user, course)
  end

  @doc """
  Returns the list of active enrollments for a user.

  Preloads course information and orders by enrolled_at desc (newest first).
  Does not include cancelled enrollments.

  ## Examples

      iex> list_user_enrollments(user)
      [%Enrollment{}, ...]

  """
  def list_user_enrollments(%User{} = user) do
    Enrollment
    |> where([e], e.user_id == ^user.id)
    |> where([e], e.status in ["active", "completed"])
    |> order_by([e], desc: e.enrolled_at)
    |> preload(:course)
    |> Repo.all()
  end

  @doc """
  Returns the list of all enrollments for a course.

  Preloads user information. Includes all enrollment statuses.

  ## Examples

      iex> list_course_enrollments(course)
      [%Enrollment{}, ...]

  """
  def list_course_enrollments(%Course{} = course) do
    Enrollment
    |> where([e], e.course_id == ^course.id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Gets a single enrollment.

  Raises `Ecto.NoResultsError` if the Enrollment does not exist.

  ## Examples

      iex> get_enrollment!(123)
      %Enrollment{}

      iex> get_enrollment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_enrollment!(id), do: Repo.get!(Enrollment, id)

  @doc """
  Marks an enrollment as completed.

  Sets the status to "completed" and completed_at timestamp.

  ## Examples

      iex> complete_enrollment(enrollment)
      {:ok, %Enrollment{}}

      iex> complete_enrollment(enrollment)
      {:error, %Ecto.Changeset{}}

  """
  def complete_enrollment(%Enrollment{} = enrollment) do
    enrollment
    |> Enrollment.changeset(%{
      status: "completed",
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Marks an enrollment as cancelled.

  Sets the status to "cancelled". Does not delete the record.

  ## Examples

      iex> cancel_enrollment(enrollment)
      {:ok, %Enrollment{}}

      iex> cancel_enrollment(enrollment)
      {:error, %Ecto.Changeset{}}

  """
  def cancel_enrollment(%Enrollment{} = enrollment) do
    enrollment
    |> Enrollment.changeset(%{status: "cancelled"})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking enrollment changes.

  ## Examples

      iex> change_enrollment(enrollment)
      %Ecto.Changeset{data: %Enrollment{}}

  """
  def change_enrollment(%Enrollment{} = enrollment, attrs \\ %{}) do
    Enrollment.changeset(enrollment, attrs)
  end

  @doc """
  Returns the total count of enrollments.

  ## Examples

      iex> count_enrollments()
      42

  """
  def count_enrollments do
    Repo.aggregate(Enrollment, :count)
  end

  @doc """
  Returns all enrollments with user and course details preloaded.

  Orders by most recent first.

  ## Examples

      iex> list_enrollments_with_details()
      [%Enrollment{user: %User{}, course: %Course{}}, ...]

  """
  def list_enrollments_with_details do
    Enrollment
    |> order_by([e], desc: e.inserted_at)
    |> preload([:user, :course])
    |> Repo.all()
  end
end
