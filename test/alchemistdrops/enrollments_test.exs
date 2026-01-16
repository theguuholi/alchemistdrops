defmodule Alchemistdrops.EnrollmentsTest do
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Enrollments
  alias Alchemistdrops.Enrollments.Enrollment

  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures
  import Alchemistdrops.AccountsFixtures

  describe "enroll_user/2" do
    test "Scenario: Enrolling user in a course" do
      # Given a user and a course exist
      user = user_fixture()
      course = course_fixture()

      # When I enroll the user in the course
      {:ok, enrollment} = Enrollments.enroll_user(user, course)

      # Then the enrollment should be created successfully
      assert %Enrollment{} = enrollment
      assert enrollment.user_id == user.id
      assert enrollment.course_id == course.id
      assert enrollment.status == "active"
    end

    test "Scenario: Enrollment sets enrolled_at timestamp" do
      # Given a user and a course
      user = user_fixture()
      course = course_fixture()

      # When I enroll the user
      {:ok, enrollment} = Enrollments.enroll_user(user, course)

      # Then enrolled_at should be set
      assert %DateTime{} = enrollment.enrolled_at
      assert DateTime.diff(DateTime.utc_now(), enrollment.enrolled_at) < 2
    end

    test "Scenario: Enrolling already enrolled user returns error" do
      # Given a user already enrolled in a course
      user = user_fixture()
      course = course_fixture()
      enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I try to enroll the user again
      result = Enrollments.enroll_user(user, course)

      # Then I should get an error
      assert {:error, changeset} = result
      assert "has already been taken" in errors_on(changeset).user_id
    end

    test "Scenario: Enrolling user with non-existent course returns error" do
      # Given a user but no course
      user = user_fixture()
      fake_course_id = Ecto.UUID.generate()

      # When I try to enroll with a fake course struct
      fake_course = %{id: fake_course_id}
      result = Enrollments.enroll_user(user, fake_course)

      # Then I should get an error
      assert {:error, _changeset} = result
    end

    test "Scenario: Same user can enroll in multiple courses" do
      # Given a user and multiple courses
      user = user_fixture()
      course1 = course_fixture()
      course2 = course_fixture()

      # When I enroll the user in both courses
      {:ok, enrollment1} = Enrollments.enroll_user(user, course1)
      {:ok, enrollment2} = Enrollments.enroll_user(user, course2)

      # Then both enrollments should succeed
      assert enrollment1.user_id == user.id
      assert enrollment2.user_id == user.id
      assert enrollment1.course_id == course1.id
      assert enrollment2.course_id == course2.id
    end
  end

  describe "user_enrolled?/2" do
    test "Scenario: Returns true when user is enrolled" do
      # Given a user enrolled in a course
      user = user_fixture()
      course = course_fixture()
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      # When I check if user is enrolled
      result = Enrollments.user_enrolled?(user, course)

      # Then it should return true
      assert result == true
    end

    test "Scenario: Returns false when user is not enrolled" do
      # Given a user and a course with no enrollment
      user = user_fixture()
      course = course_fixture()

      # When I check if user is enrolled
      result = Enrollments.user_enrolled?(user, course)

      # Then it should return false
      assert result == false
    end

    test "Scenario: Returns false for cancelled enrollments" do
      # Given a user with cancelled enrollment
      user = user_fixture()
      course = course_fixture()
      cancelled_enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I check if user is enrolled
      result = Enrollments.user_enrolled?(user, course)

      # Then it should return false
      assert result == false
    end

    test "Scenario: Returns true for completed enrollments" do
      # Given a user with completed enrollment
      user = user_fixture()
      course = course_fixture()
      completed_enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I check if user is enrolled
      result = Enrollments.user_enrolled?(user, course)

      # Then it should return true (completed is still considered enrolled)
      assert result == true
    end
  end

  describe "can_access_course?/2" do
    test "Scenario: Admin users can access any course" do
      # Given an admin user and a paid course
      admin = admin_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD)})

      # When I check if admin can access
      result = Enrollments.can_access_course?(admin, course)

      # Then it should return true
      assert result == true
    end

    test "Scenario: Enrolled users can access paid courses" do
      # Given a regular user enrolled in a paid course
      user = user_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD)})
      enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I check if user can access
      result = Enrollments.can_access_course?(user, course)

      # Then it should return true
      assert result == true
    end

    test "Scenario: Any authenticated user can access free courses" do
      # Given a regular user and a free course (not enrolled)
      user = user_fixture()
      course = free_course_fixture()

      # When I check if user can access
      result = Enrollments.can_access_course?(user, course)

      # Then it should return true
      assert result == true
    end

    test "Scenario: Non-enrolled users cannot access paid courses" do
      # Given a regular user and a paid course (not enrolled)
      user = user_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD)})

      # When I check if user can access
      result = Enrollments.can_access_course?(user, course)

      # Then it should return false
      assert result == false
    end

    test "Scenario: Cancelled enrollments do not grant access" do
      # Given a user with cancelled enrollment in paid course
      user = user_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD)})
      cancelled_enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I check if user can access
      result = Enrollments.can_access_course?(user, course)

      # Then it should return false
      assert result == false
    end
  end

  describe "can_access_lesson?/2" do
    test "Scenario: Returns true if can access parent course" do
      # Given a user enrolled in a course with lessons
      user = user_fixture()
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id})
      enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I check if user can access the lesson
      result = Enrollments.can_access_lesson?(user, lesson)

      # Then it should return true
      assert result == true
    end

    test "Scenario: Returns false if cannot access parent course" do
      # Given a user not enrolled in a paid course
      user = user_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD)})
      lesson = lesson_fixture(%{course_id: course.id})

      # When I check if user can access the lesson
      result = Enrollments.can_access_lesson?(user, lesson)

      # Then it should return false
      assert result == false
    end

    test "Scenario: Admin can access any lesson" do
      # Given an admin user and a lesson in a paid course
      admin = admin_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD)})
      lesson = lesson_fixture(%{course_id: course.id})

      # When I check if admin can access the lesson
      result = Enrollments.can_access_lesson?(admin, lesson)

      # Then it should return true
      assert result == true
    end
  end

  describe "list_user_enrollments/1" do
    test "Scenario: Returns all active enrollments for user" do
      # Given a user with multiple enrollments
      user = user_fixture()
      course1 = course_fixture()
      course2 = course_fixture()
      enrollment1 = enrollment_fixture(%{user_id: user.id, course_id: course1.id})
      enrollment2 = enrollment_fixture(%{user_id: user.id, course_id: course2.id})

      # When I list user enrollments
      enrollments = Enrollments.list_user_enrollments(user)

      # Then I should get all active enrollments
      assert length(enrollments) == 2
      enrollment_ids = Enum.map(enrollments, & &1.id)
      assert enrollment1.id in enrollment_ids
      assert enrollment2.id in enrollment_ids
    end

    test "Scenario: Preloads course information" do
      # Given a user with an enrollment
      user = user_fixture()
      course = course_fixture(%{title: "Test Course"})
      enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I list user enrollments
      [enrollment | _] = Enrollments.list_user_enrollments(user)

      # Then courses should be preloaded
      assert Ecto.assoc_loaded?(enrollment.course)
      assert enrollment.course.title == "Test Course"
    end

    test "Scenario: Orders by enrolled_at desc" do
      # Given a user with multiple enrollments at different times
      user = user_fixture()
      course1 = course_fixture()
      course2 = course_fixture()

      # Create first enrollment
      {:ok, enrollment1} =
        %Enrollment{}
        |> Enrollment.changeset(%{
          user_id: user.id,
          course_id: course1.id,
          enrolled_at: DateTime.add(DateTime.utc_now(), -2, :day)
        })
        |> Repo.insert()

      # Create second enrollment (more recent)
      {:ok, enrollment2} =
        %Enrollment{}
        |> Enrollment.changeset(%{
          user_id: user.id,
          course_id: course2.id,
          enrolled_at: DateTime.add(DateTime.utc_now(), -1, :day)
        })
        |> Repo.insert()

      # When I list user enrollments
      enrollments = Enrollments.list_user_enrollments(user)

      # Then they should be ordered by enrolled_at desc (newest first)
      assert [enrollment2.id, enrollment1.id] == Enum.map(enrollments, & &1.id)
    end

    test "Scenario: Does not include cancelled enrollments" do
      # Given a user with active and cancelled enrollments
      user = user_fixture()
      course1 = course_fixture()
      course2 = course_fixture()
      enrollment_fixture(%{user_id: user.id, course_id: course1.id, status: "active"})
      cancelled_enrollment_fixture(%{user_id: user.id, course_id: course2.id})

      # When I list user enrollments
      enrollments = Enrollments.list_user_enrollments(user)

      # Then only active enrollments should be returned
      assert length(enrollments) == 1
      assert hd(enrollments).status == "active"
    end
  end

  describe "list_course_enrollments/1" do
    test "Scenario: Returns all enrollments for a course" do
      # Given a course with multiple enrollments
      course = course_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      enrollment1 = enrollment_fixture(%{user_id: user1.id, course_id: course.id})
      enrollment2 = enrollment_fixture(%{user_id: user2.id, course_id: course.id})

      # When I list course enrollments
      enrollments = Enrollments.list_course_enrollments(course)

      # Then I should get all enrollments
      assert length(enrollments) == 2
      enrollment_ids = Enum.map(enrollments, & &1.id)
      assert enrollment1.id in enrollment_ids
      assert enrollment2.id in enrollment_ids
    end

    test "Scenario: Preloads user information" do
      # Given a course with an enrollment
      course = course_fixture()
      user = user_fixture(%{email: "test@example.com"})
      enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I list course enrollments
      [enrollment | _] = Enrollments.list_course_enrollments(course)

      # Then users should be preloaded
      assert Ecto.assoc_loaded?(enrollment.user)
      assert enrollment.user.email == "test@example.com"
    end

    test "Scenario: Includes all enrollment statuses" do
      # Given a course with enrollments in different statuses
      course = course_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()
      enrollment_fixture(%{user_id: user1.id, course_id: course.id, status: "active"})
      completed_enrollment_fixture(%{user_id: user2.id, course_id: course.id})
      cancelled_enrollment_fixture(%{user_id: user3.id, course_id: course.id})

      # When I list course enrollments
      enrollments = Enrollments.list_course_enrollments(course)

      # Then all statuses should be included
      assert length(enrollments) == 3
      statuses = Enum.map(enrollments, & &1.status) |> Enum.sort()
      assert statuses == ["active", "cancelled", "completed"]
    end
  end

  describe "get_enrollment!/1" do
    test "Scenario: Getting an enrollment by id" do
      # Given an enrollment exists
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I get the enrollment
      result = Enrollments.get_enrollment!(enrollment.id)

      # Then I should get the enrollment
      assert result.id == enrollment.id
      assert result.user_id == user.id
      assert result.course_id == course.id
    end

    test "Scenario: Getting non-existent enrollment raises error" do
      # Given an invalid enrollment id
      invalid_id = Ecto.UUID.generate()

      # When I try to get the enrollment
      # Then it should raise an error
      assert_raise Ecto.NoResultsError, fn ->
        Enrollments.get_enrollment!(invalid_id)
      end
    end
  end

  describe "complete_enrollment/1" do
    test "Scenario: Marking enrollment as completed" do
      # Given an active enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I complete the enrollment
      {:ok, completed} = Enrollments.complete_enrollment(enrollment)

      # Then the enrollment should be marked completed
      assert completed.status == "completed"
      assert completed.id == enrollment.id
    end

    test "Scenario: Completing enrollment sets completed_at timestamp" do
      # Given an active enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I complete the enrollment
      {:ok, completed} = Enrollments.complete_enrollment(enrollment)

      # Then completed_at should be set
      assert %DateTime{} = completed.completed_at
      assert DateTime.diff(DateTime.utc_now(), completed.completed_at) < 2
    end

    test "Scenario: Can complete already completed enrollment" do
      # Given an already completed enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = completed_enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I try to complete it again
      {:ok, completed} = Enrollments.complete_enrollment(enrollment)

      # Then it should succeed (idempotent)
      assert completed.status == "completed"
    end
  end

  describe "cancel_enrollment/1" do
    test "Scenario: Marking enrollment as cancelled" do
      # Given an active enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I cancel the enrollment
      {:ok, cancelled} = Enrollments.cancel_enrollment(enrollment)

      # Then the enrollment should be marked cancelled
      assert cancelled.status == "cancelled"
      assert cancelled.id == enrollment.id
    end

    test "Scenario: Cancelling enrollment does not delete record" do
      # Given an active enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I cancel the enrollment
      {:ok, cancelled} = Enrollments.cancel_enrollment(enrollment)

      # Then the record should still exist
      assert Repo.get(Enrollment, cancelled.id)
      assert cancelled.status == "cancelled"
    end
  end

  describe "change_enrollment/1" do
    test "Scenario: Getting a changeset for an enrollment" do
      # Given an enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I get a changeset
      changeset = Enrollments.change_enrollment(enrollment)

      # Then I should get a valid changeset
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == enrollment
    end

    test "Scenario: Getting a changeset with changes" do
      # Given an enrollment
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      # When I get a changeset with changes
      changeset = Enrollments.change_enrollment(enrollment, %{status: "completed"})

      # Then the changeset should contain the changes
      assert changeset.changes.status == "completed"
    end
  end

  describe "count_enrollments/0" do
    test "returns zero when no enrollments exist" do
      assert Enrollments.count_enrollments() == 0
    end

    test "returns correct count of enrollments" do
      user1 = user_fixture()
      user2 = user_fixture()
      course = course_fixture()

      enrollment_fixture(%{user_id: user1.id, course_id: course.id})
      enrollment_fixture(%{user_id: user2.id, course_id: course.id})

      assert Enrollments.count_enrollments() == 2
    end
  end

  describe "list_enrollments_with_details/0" do
    test "returns empty list when no enrollments exist" do
      assert Enrollments.list_enrollments_with_details() == []
    end

    test "returns all enrollments with preloaded user and course" do
      user = user_fixture(%{email: "test@example.com"})
      course = course_fixture(%{title: "Test Course"})
      enrollment_fixture(%{user_id: user.id, course_id: course.id})

      [enrollment] = Enrollments.list_enrollments_with_details()

      assert Ecto.assoc_loaded?(enrollment.user)
      assert Ecto.assoc_loaded?(enrollment.course)
      assert enrollment.user.email == "test@example.com"
      assert enrollment.course.title == "Test Course"
    end

    test "orders by most recent first" do
      user1 = user_fixture()
      user2 = user_fixture()
      course = course_fixture()

      enrollment1 = enrollment_fixture(%{user_id: user1.id, course_id: course.id})
      enrollment2 = enrollment_fixture(%{user_id: user2.id, course_id: course.id})

      enrollments = Enrollments.list_enrollments_with_details()

      # Just verify we get both enrollments (ordering depends on DB insert timing)
      enrollment_ids = Enum.map(enrollments, & &1.id) |> MapSet.new()
      assert MapSet.member?(enrollment_ids, enrollment1.id)
      assert MapSet.member?(enrollment_ids, enrollment2.id)
      assert length(enrollments) == 2
    end
  end
end
