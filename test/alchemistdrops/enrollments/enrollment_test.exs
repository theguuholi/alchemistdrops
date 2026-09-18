defmodule Alchemistdrops.Enrollments.EnrollmentTest do
  @moduledoc """
  Feature: Enrollment Schema Validation
    As a system
    I want to ensure enrollments are properly validated
    So that users can only enroll in courses with valid data
  """
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Accounts.User
  alias Alchemistdrops.Courses.Course
  alias Alchemistdrops.Enrollments.Enrollment

  doctest Alchemistdrops.Enrollments.Enrollment

  setup do
    # Given a user exists in the system
    user =
      %User{}
      |> User.email_changeset(%{email: "test@example.com", role: :user})
      |> User.password_changeset(%{password: "TestPassword123!"}, hash_password: false)
      |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt("TestPassword123!"))
      |> Repo.insert!()

    # And a course exists in the system
    course =
      %Course{}
      |> Course.changeset(%{
        title: "Test Course",
        description: "Test Description"
      })
      |> Repo.insert!()

    %{user: user, course: course}
  end

  describe "Feature: Enrollment Changeset Validation" do
    test "Scenario: Creating an enrollment with valid required fields", %{
      user: user,
      course: course
    } do
      # Given valid enrollment attributes with user_id, course_id, and enrolled_at
      enrolled_at = DateTime.utc_now(:second)

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        enrolled_at: enrolled_at
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating an enrollment without a user_id", %{course: course} do
      # Given enrollment attributes without a user_id
      attrs = %{
        course_id: course.id,
        enrolled_at: DateTime.utc_now(:second)
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a user_id required error
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating an enrollment without a course_id", %{user: user} do
      # Given enrollment attributes without a course_id
      attrs = %{
        user_id: user.id,
        enrolled_at: DateTime.utc_now(:second)
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a course_id required error
      assert %{course_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Enrolled_at timestamp is automatically set", %{user: user, course: course} do
      # Given enrollment attributes without enrolled_at timestamp
      attrs = %{
        user_id: user.id,
        course_id: course.id
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And enrolled_at should be automatically set
      enrolled_at = Ecto.Changeset.get_field(changeset, :enrolled_at)
      assert enrolled_at != nil

      # And enrolled_at should be within 2 seconds of now
      assert_in_delta DateTime.to_unix(enrolled_at), DateTime.to_unix(DateTime.utc_now()), 2
    end

    test "Scenario: Creating an enrollment with an invalid status", %{user: user, course: course} do
      # Given enrollment attributes with an invalid status
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        status: "invalid_status"
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a status validation error
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "Scenario: Valid status values are accepted", %{user: user, course: course} do
      # Given a list of valid status values
      valid_statuses = ["active", "completed", "cancelled"]

      # When I create changesets with each status
      for status <- valid_statuses do
        attrs = %{
          user_id: user.id,
          course_id: course.id,
          status: status
        }

        changeset = Enrollment.changeset(%Enrollment{}, attrs)

        # Then each changeset should be valid
        assert changeset.valid?, "Expected #{status} to be valid"
      end
    end

    test "Scenario: Default status is set to active", %{user: user, course: course} do
      # Given enrollment attributes without status
      attrs = %{
        user_id: user.id,
        course_id: course.id
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then default status should be active
      assert Ecto.Changeset.get_field(changeset, :status) == "active"
    end

    test "Scenario: Duplicate enrollment for same user and course is prevented", %{
      user: user,
      course: course
    } do
      # Given an enrollment already exists for this user and course
      %Enrollment{}
      |> Enrollment.changeset(%{
        user_id: user.id,
        course_id: course.id
      })
      |> Repo.insert!()

      # When I try to create another enrollment for the same user and course
      changeset =
        %Enrollment{}
        |> Enrollment.changeset(%{
          user_id: user.id,
          course_id: course.id
        })

      # Then inserting should fail
      assert {:error, changeset} = Repo.insert(changeset)

      # And it should have a unique constraint error
      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "Scenario: Same user can enroll in different courses", %{user: user, course: course} do
      # Given another course exists
      another_course =
        %Course{}
        |> Course.changeset(%{
          title: "Another Course",
          description: "Another Description"
        })
        |> Repo.insert!()

      # And user is enrolled in the first course
      %Enrollment{}
      |> Enrollment.changeset(%{
        user_id: user.id,
        course_id: course.id
      })
      |> Repo.insert!()

      # When I create an enrollment for the same user in the second course
      changeset =
        %Enrollment{}
        |> Enrollment.changeset(%{
          user_id: user.id,
          course_id: another_course.id
        })

      # Then it should succeed
      assert {:ok, _enrollment} = Repo.insert(changeset)
    end

    test "Scenario: Different users can enroll in the same course", %{user: user, course: course} do
      # Given another user exists
      another_user =
        %User{}
        |> User.email_changeset(%{email: "another@example.com", role: :user})
        |> User.password_changeset(%{password: "TestPassword123!"}, hash_password: false)
        |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt("TestPassword123!"))
        |> Repo.insert!()

      # And the first user is enrolled in the course
      %Enrollment{}
      |> Enrollment.changeset(%{
        user_id: user.id,
        course_id: course.id
      })
      |> Repo.insert!()

      # When I create an enrollment for the second user in the same course
      changeset =
        %Enrollment{}
        |> Enrollment.changeset(%{
          user_id: another_user.id,
          course_id: course.id
        })

      # Then it should succeed
      assert {:ok, _enrollment} = Repo.insert(changeset)
    end

    test "Scenario: Completed_at timestamp can be set", %{user: user, course: course} do
      # Given enrollment attributes with a completed_at timestamp
      completed_at = DateTime.utc_now(:second)

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        completed_at: completed_at
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And completed_at should be set correctly
      assert Ecto.Changeset.get_change(changeset, :completed_at) == completed_at
    end

    test "Scenario: Status can be set to completed", %{user: user, course: course} do
      # Given enrollment attributes with completed status
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        status: "completed"
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And status should be completed
      assert Ecto.Changeset.get_change(changeset, :status) == "completed"
    end

    test "Scenario: Status can be set to cancelled", %{user: user, course: course} do
      # Given enrollment attributes with cancelled status
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        status: "cancelled"
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And status should be cancelled
      assert Ecto.Changeset.get_change(changeset, :status) == "cancelled"
    end

    test "Scenario: Completed enrollment with both status and timestamp", %{
      user: user,
      course: course
    } do
      # Given enrollment attributes with completed status and completed_at
      completed_at = DateTime.utc_now(:second)

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        status: "completed",
        completed_at: completed_at
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And both fields should be set
      assert Ecto.Changeset.get_change(changeset, :status) == "completed"
      assert Ecto.Changeset.get_change(changeset, :completed_at) == completed_at
    end

    test "Scenario: Enrolled_at can be set to a past date", %{user: user, course: course} do
      # Given enrollment attributes with a past enrolled_at date
      past_date = DateTime.add(DateTime.utc_now(:second), -30, :day)

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        enrolled_at: past_date
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And enrolled_at should be set to the past date
      assert Ecto.Changeset.get_change(changeset, :enrolled_at) == past_date
    end

    test "Scenario: Nil completed_at is accepted", %{user: user, course: course} do
      # Given enrollment attributes with nil completed_at
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        completed_at: nil
      }

      # When I create a changeset with these attributes
      changeset = Enrollment.changeset(%Enrollment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end
  end
end
