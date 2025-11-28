defmodule Alchemistdrops.EnrollmentsFixtures do
  @moduledoc """
  This module defines test fixtures for the Enrollments context.
  """

  alias Alchemistdrops.AccountsFixtures
  alias Alchemistdrops.CoursesFixtures
  alias Alchemistdrops.Enrollments.Enrollment
  alias Alchemistdrops.Repo

  @doc """
  Generate an enrollment with default or custom attributes.
  """
  def enrollment_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || AccountsFixtures.user_fixture()
    course = Map.get(attrs, :course) || CoursesFixtures.course_fixture()

    attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:course_id, course.id)
      |> Enum.into(%{
        status: "active",
        enrolled_at: DateTime.utc_now(:second)
      })

    %Enrollment{}
    |> Enrollment.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate a completed enrollment.
  """
  def completed_enrollment_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:status, "completed")
      |> Map.put(:completed_at, DateTime.utc_now(:second))

    enrollment_fixture(attrs)
  end

  @doc """
  Generate a cancelled enrollment.
  """
  def cancelled_enrollment_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :status, "cancelled")
    enrollment_fixture(attrs)
  end
end
