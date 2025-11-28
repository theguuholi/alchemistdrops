defmodule Alchemistdrops.Courses.LessonTest do
  @moduledoc """
  Feature: Lesson Schema Validation
    As a course instructor
    I want to ensure lessons are properly validated
    So that only valid lesson data is stored in the database
  """
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Courses.{Course, Lesson}

  setup do
    # Given a course exists in the system
    course =
      %Course{}
      |> Course.changeset(%{
        title: "Test Course",
        description: "Test Description"
      })
      |> Repo.insert!()

    %{course: course}
  end

  describe "Feature: Lesson Changeset Validation" do
    test "Scenario: Creating a lesson with valid required fields", %{course: course} do
      # Given valid lesson attributes with course_id and title
      attrs = %{
        course_id: course.id,
        title: "Introduction to Lesson"
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating a lesson without a title" do
      # Given lesson attributes without a title
      attrs = %{content: "Content without title"}

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a title required error
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a lesson without a course_id", %{course: _course} do
      # Given lesson attributes without a course_id
      attrs = %{title: "Lesson without course"}

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a course_id required error
      assert %{course_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a lesson with a negative order", %{course: course} do
      # Given lesson attributes with a negative order value
      attrs = %{
        course_id: course.id,
        title: "Test Lesson",
        order: -1
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have an order validation error
      assert %{order: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a lesson with order zero", %{course: course} do
      # Given lesson attributes with order set to zero
      attrs = %{
        course_id: course.id,
        title: "First Lesson",
        order: 0
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating a lesson with a negative duration", %{course: course} do
      # Given lesson attributes with a negative duration
      attrs = %{
        course_id: course.id,
        title: "Test Lesson",
        duration: -5
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a duration validation error
      assert %{duration: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a lesson with zero duration", %{course: course} do
      # Given lesson attributes with zero duration
      attrs = %{
        course_id: course.id,
        title: "Test Lesson",
        duration: 0
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a duration validation error
      assert %{duration: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a lesson without duration (optional field)", %{course: course} do
      # Given lesson attributes without duration
      attrs = %{
        course_id: course.id,
        title: "Test Lesson"
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Default values are set when not provided", %{course: course} do
      # Given minimal lesson attributes without order or published status
      attrs = %{
        course_id: course.id,
        title: "Test Lesson"
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And default order should be 0
      assert Ecto.Changeset.get_field(changeset, :order) == 0

      # And default published status should be false
      assert Ecto.Changeset.get_field(changeset, :published) == false
    end

    test "Scenario: Title whitespace is trimmed", %{course: course} do
      # Given lesson attributes with whitespace around the title
      attrs = %{
        course_id: course.id,
        title: "  Test Lesson  "
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the title should be trimmed
      assert Ecto.Changeset.get_change(changeset, :title) == "Test Lesson"
    end

    test "Scenario: Title exceeds maximum length", %{course: course} do
      # Given lesson attributes with a title longer than 255 characters
      attrs = %{
        course_id: course.id,
        title: String.duplicate("a", 256)
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a title length error
      assert %{title: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "Scenario: Title at maximum length is accepted", %{course: course} do
      # Given lesson attributes with a title exactly 255 characters
      attrs = %{
        course_id: course.id,
        title: String.duplicate("a", 255)
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: All optional fields are accepted", %{course: course} do
      # Given lesson attributes with all optional fields populated
      attrs = %{
        course_id: course.id,
        title: "Complete Lesson",
        description: "Lesson description",
        content: "Full lesson content",
        order: 5,
        duration: 30,
        video_url: "https://example.com/video.mp4",
        published: true
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And all fields should be set correctly
      assert Ecto.Changeset.get_change(changeset, :description) == "Lesson description"
      assert Ecto.Changeset.get_change(changeset, :content) == "Full lesson content"
      assert Ecto.Changeset.get_change(changeset, :order) == 5
      assert Ecto.Changeset.get_change(changeset, :duration) == 30
      assert Ecto.Changeset.get_change(changeset, :video_url) == "https://example.com/video.mp4"
      assert Ecto.Changeset.get_change(changeset, :published) == true
    end

    test "Scenario: Foreign key constraint is enforced on insert" do
      # Given lesson attributes with a non-existent course_id
      attrs = %{
        course_id: Ecto.UUID.generate(),
        title: "Lesson with invalid course"
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid at this stage
      assert changeset.valid?

      # But when I try to insert it into the database
      # Then it should fail with a foreign key constraint error
      assert {:error, changeset} = Repo.insert(changeset)

      # And it should have a course_id constraint error
      assert %{course_id: ["does not exist"]} = errors_on(changeset)
    end

    test "Scenario: Published flag can be set to false explicitly", %{course: course} do
      # Given lesson attributes with published set to false
      attrs = %{
        course_id: course.id,
        title: "Draft Lesson",
        published: false
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And published should be false
      assert Ecto.Changeset.get_field(changeset, :published) == false
    end

    test "Scenario: Published flag can be set to true", %{course: course} do
      # Given lesson attributes with published set to true
      attrs = %{
        course_id: course.id,
        title: "Published Lesson",
        published: true
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And published should be true
      assert Ecto.Changeset.get_change(changeset, :published) == true
    end

    test "Scenario: Large order values are accepted", %{course: course} do
      # Given lesson attributes with a large order value
      attrs = %{
        course_id: course.id,
        title: "Last Lesson",
        order: 9999
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Large duration values are accepted", %{course: course} do
      # Given lesson attributes with a large duration
      attrs = %{
        course_id: course.id,
        title: "Long Lesson",
        duration: 240
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Empty string for optional fields is accepted", %{course: course} do
      # Given lesson attributes with empty strings for optional fields
      attrs = %{
        course_id: course.id,
        title: "Test Lesson",
        description: "",
        content: "",
        video_url: ""
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Nil values for optional fields are accepted", %{course: course} do
      # Given lesson attributes with nil for optional fields
      attrs = %{
        course_id: course.id,
        title: "Test Lesson",
        description: nil,
        content: nil,
        video_url: nil,
        duration: nil
      }

      # When I create a changeset with these attributes
      changeset = Lesson.changeset(%Lesson{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end
  end
end
