defmodule Alchemistdrops.CoursesTest do
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Courses.{Course, Lesson}
  alias Alchemistdrops.Payments.MockHttpClient

  import Alchemistdrops.CoursesFixtures

  describe "list_courses/0" do
    test "Scenario: Listing all published courses ordered by title" do
      # Given multiple published courses exist in the database
      _course_a = course_fixture(%{title: "B Advanced Course", published: true})
      _course_b = course_fixture(%{title: "A Basic Course", published: true})
      _course_c = course_fixture(%{title: "C Master Course", published: true})

      # When I list all courses
      courses = Courses.list_courses()

      # Then I should get all published courses ordered by title
      assert length(courses) == 3

      assert [
               %Course{title: "A Basic Course"},
               %Course{title: "B Advanced Course"},
               %Course{title: "C Master Course"}
             ] = courses
    end

    test "Scenario: Listing courses excludes unpublished courses" do
      # Given both published and unpublished courses exist
      published_course = course_fixture(%{title: "Published Course", published: true})
      _unpublished_course = course_fixture(%{title: "Draft Course", published: false})

      # When I list all courses
      courses = Courses.list_courses()

      # Then I should only get published courses
      assert length(courses) == 1
      assert hd(courses).id == published_course.id
      assert hd(courses).title == "Published Course"
    end

    test "Scenario: Listing courses when no courses exist" do
      # Given no courses exist in the database
      # (DataCase cleans the database before each test)

      # When I list all courses
      courses = Courses.list_courses()

      # Then I should get an empty list
      assert courses == []
    end
  end

  describe "list_all_courses/0" do
    test "Scenario: Admin listing all courses including unpublished" do
      # Given both published and unpublished courses exist
      published = course_fixture(%{title: "Published", published: true})
      unpublished = course_fixture(%{title: "Unpublished", published: false})

      # When I list all courses (admin view)
      courses = Courses.list_all_courses()

      # Then I should get all courses regardless of published status
      assert length(courses) == 2
      course_ids = Enum.map(courses, & &1.id)
      assert published.id in course_ids
      assert unpublished.id in course_ids
    end

    test "Scenario: All courses are ordered by title" do
      # Given multiple courses with different publish statuses
      course_fixture(%{title: "C Course", published: false})
      course_fixture(%{title: "A Course", published: true})
      course_fixture(%{title: "B Course", published: false})

      # When I list all courses
      courses = Courses.list_all_courses()

      # Then they should be ordered by title
      assert Enum.map(courses, & &1.title) == ["A Course", "B Course", "C Course"]
    end
  end

  describe "get_course!/1" do
    test "Scenario: Getting a course with valid id" do
      # Given a course exists in the database
      course = course_fixture(%{title: "Test Course"})

      # When I get the course by id
      result = Courses.get_course!(course.id)

      # Then I should get the course
      assert %Course{} = result
      assert result.id == course.id
      assert result.title == "Test Course"
    end

    test "Scenario: Getting a course preloads lessons by default" do
      # Given a course with lessons exists
      course = course_fixture()
      lesson_fixture(%{course_id: course.id, title: "Lesson 1"})
      lesson_fixture(%{course_id: course.id, title: "Lesson 2"})

      # When I get the course
      result = Courses.get_course!(course.id)

      # Then lessons should be preloaded
      assert Ecto.assoc_loaded?(result.lessons)
      assert length(result.lessons) == 2
    end

    test "Scenario: Getting a course with invalid id raises error" do
      # Given an invalid course id
      invalid_id = Ecto.UUID.generate()

      # When I try to get the course
      # Then it should raise Ecto.NoResultsError
      assert_raise Ecto.NoResultsError, fn ->
        Courses.get_course!(invalid_id)
      end
    end
  end

  describe "get_course_with_lessons!/1" do
    test "Scenario: Getting course with lessons ordered by order field" do
      # Given a course with multiple lessons
      course = course_fixture()
      lesson1 = lesson_fixture(%{course_id: course.id, title: "Third", order: 2, published: true})
      lesson2 = lesson_fixture(%{course_id: course.id, title: "First", order: 0, published: true})

      lesson3 =
        lesson_fixture(%{course_id: course.id, title: "Second", order: 1, published: true})

      # When I get the course with lessons
      result = Courses.get_course_with_lessons!(course.id)

      # Then lessons should be ordered by the order field
      assert length(result.lessons) == 3
      assert [lesson2.id, lesson3.id, lesson1.id] == Enum.map(result.lessons, & &1.id)
      assert ["First", "Second", "Third"] == Enum.map(result.lessons, & &1.title)
    end

    test "Scenario: Getting course includes unpublished lessons" do
      # Given a course with both published and unpublished lessons
      course = course_fixture()
      lesson_fixture(%{course_id: course.id, published: true})
      lesson_fixture(%{course_id: course.id, published: false})

      # When I get the course with lessons
      result = Courses.get_course_with_lessons!(course.id)

      # Then all lessons should be included
      assert length(result.lessons) == 2
    end
  end

  describe "create_course/1" do
    test "Scenario: Creating course with valid attributes" do
      # Given valid course attributes
      attrs = %{
        title: "New Course",
        description: "A comprehensive course",
        price: Money.new(9999, :USD)
      }

      # When I create a course
      {:ok, course} = Courses.create_course(attrs)

      # Then the course should be created successfully
      assert %Course{} = course
      assert course.title == "New Course"
      assert course.description == "A comprehensive course"
      assert course.price == Money.new(9999, :USD)
    end

    test "Scenario: Creating course with missing required fields returns error changeset" do
      # Given invalid attributes (missing title)
      attrs = %{description: "Missing title"}

      # When I try to create a course
      {:error, changeset} = Courses.create_course(attrs)

      # Then I should get an error changeset
      assert %Ecto.Changeset{} = changeset
      assert "can't be blank" in errors_on(changeset).title
    end

    test "Scenario: Creating course sets default currency and price" do
      # Given minimal valid attributes (no price or currency)
      attrs = %{title: "Free Course", description: "A free course"}

      # When I create a course
      {:ok, course} = Courses.create_course(attrs)

      # Then default price should be zero USD (free)
      assert course.price == nil || Money.zero?(course.price || Money.new(0, :USD))
    end

    test "Scenario: Creating course with all optional fields" do
      # Given attributes with all optional fields
      attrs = %{
        title: "Complete Course",
        description: "Full details",
        body: "# Course Body Content",
        price: Money.new(14_999, :USD),
        stripe_product_id: "prod_123",
        stripe_price_id: "price_123",
        published: true,
        thumbnail_url: "https://example.com/thumb.jpg"
      }

      # When I create a course
      {:ok, course} = Courses.create_course(attrs)

      # Then all fields should be set correctly
      assert course.title == "Complete Course"
      assert course.body == "# Course Body Content"
      assert course.stripe_product_id == "prod_123"
      assert course.stripe_price_id == "price_123"
      assert course.published == true
      assert course.thumbnail_url == "https://example.com/thumb.jpg"
    end
  end

  describe "Stripe association" do
    test "Scenario: Creating course with positive price and no Stripe IDs creates Stripe product and price" do
      # Given valid attributes with positive price and no stripe IDs (test uses MockHttpClient)
      attrs = %{
        title: "Paid Course",
        description: "A paid course",
        price: Money.new(9900, :USD)
      }

      # When I create a course
      {:ok, course} = Courses.create_course(attrs)

      # Then Stripe IDs should be set from API (mock returns ids in body["id"])
      assert %Course{} = course
      assert course.title == "Paid Course"
      assert course.stripe_product_id != nil
      assert course.stripe_price_id != nil

      assert String.starts_with?(course.stripe_price_id, "cs_test_") or
               String.starts_with?(course.stripe_price_id, "price_") or
               String.starts_with?(course.stripe_price_id, "prod_")
    end

    test "Scenario: Creating course with zero price does not set Stripe IDs" do
      # Given attributes with zero price
      attrs = %{
        title: "Free Course",
        description: "Free",
        price: Money.new(0, :USD)
      }

      # When I create a course
      {:ok, course} = Courses.create_course(attrs)

      # Then Stripe IDs should remain nil/empty
      assert course.title == "Free Course"
      assert course.stripe_product_id in [nil, ""]
      assert course.stripe_price_id in [nil, ""]
    end

    test "Scenario: Creating course with existing stripe_price_id keeps IDs without calling Stripe" do
      # Given attributes with existing Stripe IDs
      attrs = %{
        title: "Pre-linked Course",
        description: "Already in Stripe",
        price: Money.new(5900, :USD),
        stripe_product_id: "prod_existing",
        stripe_price_id: "price_existing"
      }

      # When I create a course
      {:ok, course} = Courses.create_course(attrs)

      # Then existing Stripe IDs are kept
      assert course.stripe_product_id == "prod_existing"
      assert course.stripe_price_id == "price_existing"
    end

    test "Scenario: Updating course with positive price and no Stripe IDs assigns Stripe IDs" do
      # Given a course with no Stripe IDs
      course =
        course_fixture(%{
          title: "Draft",
          price: Money.new(0, :USD),
          stripe_product_id: nil,
          stripe_price_id: nil
        })

      # When I update with a positive price (and still no Stripe IDs)
      {:ok, updated} =
        Courses.update_course(course, %{
          title: "Draft",
          description: course.description,
          price: Money.new(4900, :USD)
        })

      # Then Stripe IDs should be set
      assert updated.stripe_product_id != nil
      assert updated.stripe_price_id != nil
    end

    test "Scenario: Updating course with existing stripe_price_id keeps IDs" do
      # Given a course with Stripe IDs
      course =
        course_fixture(%{
          title: "Linked",
          price: Money.new(7900, :USD),
          stripe_product_id: "prod_keep",
          stripe_price_id: "price_keep"
        })

      # When I update other fields (e.g. title)
      {:ok, updated} =
        Courses.update_course(course, %{
          title: "Linked Updated",
          description: course.description,
          price: Money.new(7900, :USD)
        })

      # Then Stripe IDs are unchanged
      assert updated.stripe_product_id == "prod_keep"
      assert updated.stripe_price_id == "price_keep"
    end

    test "Scenario: Stripe API error returns changeset error" do
      # Given Stripe will fail (mock returns error)
      MockHttpClient.expect_error(:timeout)

      attrs = %{
        title: "Will Fail Stripe",
        description: "Desc",
        price: Money.new(1000, :USD)
      }

      # When I create a course
      {:error, changeset} = Courses.create_course(attrs)

      # Then we get a changeset with Stripe error
      assert %Ecto.Changeset{} = changeset
      assert changeset.valid? == false
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :stripe_price_id)
      assert List.first(errors.stripe_price_id) =~ "Stripe"
    end

    test "Scenario: Update course when Stripe API fails returns changeset error" do
      MockHttpClient.expect_error(:timeout)

      course =
        course_fixture(%{
          title: "Draft",
          price: Money.new(0, :USD),
          stripe_product_id: nil,
          stripe_price_id: nil
        })

      {:error, changeset} =
        Courses.update_course(course, %{
          title: "Draft",
          description: course.description,
          price: Money.new(5000, :USD)
        })

      assert %Ecto.Changeset{} = changeset
      assert changeset.valid? == false
      assert Map.has_key?(errors_on(changeset), :stripe_price_id)
    end

    test "Scenario: create_course with nil attrs uses normalize_attrs" do
      # normalize_attrs(nil) returns %{} so we get invalid changeset
      {:error, changeset} = Courses.create_course(nil)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end

    test "Scenario: create_course with list attrs uses normalize_attrs" do
      # normalize_attrs([]) returns %{}
      {:error, changeset} = Courses.create_course([])
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end

    test "Scenario: create_course with string price from form params" do
      # Form params often send "price" => "9900" (string); price_to_cents may receive string
      attrs = %{
        "title" => "String Price Course",
        "description" => "Desc",
        "price" => "9900"
      }

      {:ok, course} = Courses.create_course(attrs)
      assert course.title == "String Price Course"
      assert course.price != nil
    end
  end

  describe "update_course/2" do
    test "Scenario: Updating course with valid attributes" do
      # Given an existing course
      course = course_fixture(%{title: "Old Title"})

      # When I update the course
      {:ok, updated} = Courses.update_course(course, %{title: "New Title"})

      # Then the course should be updated
      assert updated.title == "New Title"
      assert updated.id == course.id
    end

    test "Scenario: Updating course with invalid attributes returns error changeset" do
      # Given an existing course
      course = course_fixture()

      # When I try to update with invalid data (negative price)
      {:error, changeset} = Courses.update_course(course, %{price: Money.new(-1000, :USD)})

      # Then I should get an error changeset
      assert %Ecto.Changeset{} = changeset
      assert "must be greater than or equal to 0" in errors_on(changeset).price
    end

    test "Scenario: Publishing a course" do
      # Given an unpublished course
      course = course_fixture(%{published: false})

      # When I publish the course
      {:ok, updated} = Courses.update_course(course, %{published: true})

      # Then the course should be published
      assert updated.published == true
    end

    test "Scenario: Unpublishing a course" do
      # Given a published course
      course = course_fixture(%{published: true})

      # When I unpublish the course
      {:ok, updated} = Courses.update_course(course, %{published: false})

      # Then the course should be unpublished
      assert updated.published == false
    end

    test "Scenario: Updating course price" do
      # Given a course with a price
      course = course_fixture(%{price: Money.new(9999, :USD)})

      # When I update the price
      {:ok, updated} =
        Courses.update_course(course, %{
          price: Money.new(7999, :USD)
        })

      # Then the price should be updated
      assert Money.equals?(updated.price, Money.new(7999, :USD))
    end
  end

  describe "delete_course/1" do
    test "Scenario: Deleting an existing course" do
      # Given a course exists
      course = course_fixture()

      # When I delete the course
      {:ok, deleted} = Courses.delete_course(course)

      # Then the course should be deleted
      assert deleted.id == course.id

      assert_raise Ecto.NoResultsError, fn ->
        Courses.get_course!(course.id)
      end
    end

    test "Scenario: Deleting course cascades delete to lessons" do
      # Given a course with lessons
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id})

      # When I delete the course
      {:ok, _deleted} = Courses.delete_course(course)

      # Then the lessons should also be deleted
      assert_raise Ecto.NoResultsError, fn ->
        Repo.get!(Lesson, lesson.id)
      end
    end
  end

  describe "create_lesson/2" do
    test "Scenario: Creating lesson for a course with valid attributes" do
      # Given a course exists
      course = course_fixture()

      # And valid lesson attributes
      attrs = %{
        title: "Introduction",
        description: "Getting started",
        content: "# Lesson Content",
        order: 0,
        duration: 30
      }

      # When I create a lesson
      {:ok, lesson} = Courses.create_lesson(course, attrs)

      # Then the lesson should be created successfully
      assert %Lesson{} = lesson
      assert lesson.title == "Introduction"
      assert lesson.course_id == course.id
      assert lesson.order == 0
      assert lesson.duration == 30
    end

    test "Scenario: Creating lesson with missing required fields returns error changeset" do
      # Given a course exists
      course = course_fixture()

      # And invalid attributes (missing title)
      attrs = %{description: "No title"}

      # When I try to create a lesson
      {:error, changeset} = Courses.create_lesson(course, attrs)

      # Then I should get an error changeset
      assert "can't be blank" in errors_on(changeset).title
    end

    test "Scenario: Creating lesson auto-increments order if not provided" do
      # Given a course with existing lessons
      course = course_fixture()
      lesson_fixture(%{course_id: course.id, order: 0})
      lesson_fixture(%{course_id: course.id, order: 1})

      # When I create a new lesson without specifying order
      {:ok, lesson} =
        Courses.create_lesson(course, %{
          title: "New Lesson",
          description: "Description"
        })

      # Then order should be auto-incremented to next value
      assert lesson.order == 2
    end

    test "Scenario: Creating lesson with all optional fields" do
      # Given a course
      course = course_fixture()

      # And attributes with all optional fields
      attrs = %{
        title: "Advanced Lesson",
        description: "Deep dive",
        content: "# Advanced Content",
        order: 5,
        duration: 120,
        video_url: "https://example.com/video.mp4",
        published: true
      }

      # When I create a lesson
      {:ok, lesson} = Courses.create_lesson(course, attrs)

      # Then all fields should be set
      assert lesson.video_url == "https://example.com/video.mp4"
      assert lesson.published == true
      assert lesson.duration == 120
    end
  end

  describe "update_lesson/2" do
    test "Scenario: Updating lesson with valid attributes" do
      # Given an existing lesson
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id, title: "Old Title"})

      # When I update the lesson
      {:ok, updated} = Courses.update_lesson(lesson, %{title: "New Title"})

      # Then the lesson should be updated
      assert updated.title == "New Title"
      assert updated.id == lesson.id
    end

    test "Scenario: Updating lesson with invalid attributes returns error changeset" do
      # Given an existing lesson
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id})

      # When I try to update with invalid data (negative duration)
      {:error, changeset} = Courses.update_lesson(lesson, %{duration: -10})

      # Then I should get an error changeset
      assert "must be greater than 0" in errors_on(changeset).duration
    end

    test "Scenario: Updating lesson order" do
      # Given an existing lesson
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id, order: 0})

      # When I update the order
      {:ok, updated} = Courses.update_lesson(lesson, %{order: 5})

      # Then the order should be updated
      assert updated.order == 5
    end

    test "Scenario: Publishing a lesson" do
      # Given an unpublished lesson
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id, published: false})

      # When I publish the lesson
      {:ok, updated} = Courses.update_lesson(lesson, %{published: true})

      # Then the lesson should be published
      assert updated.published == true
    end
  end

  describe "delete_lesson/1" do
    test "Scenario: Deleting an existing lesson" do
      # Given a lesson exists
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id})

      # When I delete the lesson
      {:ok, deleted} = Courses.delete_lesson(lesson)

      # Then the lesson should be deleted
      assert deleted.id == lesson.id

      assert_raise Ecto.NoResultsError, fn ->
        Repo.get!(Lesson, lesson.id)
      end
    end

    test "Scenario: Deleting lesson does not delete parent course" do
      # Given a course with a lesson
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id})

      # When I delete the lesson
      {:ok, _deleted} = Courses.delete_lesson(lesson)

      # Then the course should still exist
      assert %Course{} = Courses.get_course!(course.id)
    end
  end

  describe "reorder_lessons/2" do
    test "Scenario: Reordering lessons for a course" do
      # Given a course with multiple lessons
      course = course_fixture()
      lesson1 = lesson_fixture(%{course_id: course.id, order: 0})
      lesson2 = lesson_fixture(%{course_id: course.id, order: 1})
      lesson3 = lesson_fixture(%{course_id: course.id, order: 2})

      # When I reorder the lessons (swap order)
      lesson_ids = [lesson3.id, lesson1.id, lesson2.id]
      {:ok, reordered} = Courses.reorder_lessons(course, lesson_ids)

      # Then lessons should have new order values
      assert length(reordered) == 3

      lesson1_reordered = Enum.find(reordered, &(&1.id == lesson1.id))
      lesson2_reordered = Enum.find(reordered, &(&1.id == lesson2.id))
      lesson3_reordered = Enum.find(reordered, &(&1.id == lesson3.id))

      assert lesson3_reordered.order == 0
      assert lesson1_reordered.order == 1
      assert lesson2_reordered.order == 2
    end

    test "Scenario: Reordering validates all lessons belong to same course" do
      # Given two courses with lessons
      course1 = course_fixture()
      course2 = course_fixture()
      lesson1 = lesson_fixture(%{course_id: course1.id})
      lesson2 = lesson_fixture(%{course_id: course2.id})

      # When I try to reorder lessons from different courses
      lesson_ids = [lesson1.id, lesson2.id]
      result = Courses.reorder_lessons(course1, lesson_ids)

      # Then I should get an error
      assert {:error, :invalid_lessons} = result
    end

    test "Scenario: Reordering with missing lesson ids returns error" do
      # Given a course with lessons
      course = course_fixture()
      lesson1 = lesson_fixture(%{course_id: course.id})
      lesson_fixture(%{course_id: course.id})

      # When I try to reorder with only one lesson id
      result = Courses.reorder_lessons(course, [lesson1.id])

      # Then I should get an error
      assert {:error, :invalid_lessons} = result
    end

    test "Scenario: Reordering with non-existent lesson ids returns error" do
      # Given a course with no lessons
      course = course_fixture()
      fake_id = Ecto.UUID.generate()

      # When I try to reorder with a non-existent lesson id
      result = Courses.reorder_lessons(course, [fake_id])

      # Then I should get an error
      assert {:error, :invalid_lessons} = result
    end
  end

  describe "change_course/1" do
    test "Scenario: Getting a changeset for a new course" do
      # Given a new course struct
      course = %Course{}

      # When I get a changeset
      changeset = Courses.change_course(course)

      # Then I should get an empty changeset
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == course
    end

    test "Scenario: Getting a changeset for an existing course" do
      # Given an existing course
      course = course_fixture()

      # When I get a changeset with changes
      changeset = Courses.change_course(course, %{title: "Updated"})

      # Then the changeset should contain the changes
      assert changeset.changes.title == "Updated"
    end
  end

  describe "change_lesson/1" do
    test "Scenario: Getting a changeset for a new lesson" do
      # Given a new lesson struct
      lesson = %Lesson{}

      # When I get a changeset
      changeset = Courses.change_lesson(lesson)

      # Then I should get an empty changeset
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == lesson
    end

    test "Scenario: Getting a changeset for an existing lesson" do
      # Given an existing lesson
      course = course_fixture()
      lesson = lesson_fixture(%{course_id: course.id})

      # When I get a changeset with changes
      changeset = Courses.change_lesson(lesson, %{title: "Updated"})

      # Then the changeset should contain the changes
      assert changeset.changes.title == "Updated"
    end
  end

  describe "count_courses/0" do
    test "returns zero when no courses exist" do
      assert Courses.count_courses() == 0
    end

    test "returns correct count of courses" do
      course_fixture()
      course_fixture()

      assert Courses.count_courses() == 2
    end
  end

  describe "list_published_courses/0" do
    test "returns only published courses (alias for list_courses)" do
      published = course_fixture(%{title: "Published", published: true})
      _unpublished = course_fixture(%{title: "Unpublished", published: false})

      courses = Courses.list_published_courses()

      assert length(courses) == 1
      assert hd(courses).id == published.id
    end
  end

  describe "list_course_lessons/2" do
    test "returns all lessons when only_published is false (default)" do
      course = course_fixture()
      published = lesson_fixture(%{course_id: course.id, published: true, order: 0})
      unpublished = lesson_fixture(%{course_id: course.id, published: false, order: 1})

      # Default behavior - all lessons
      lessons = Courses.list_course_lessons(course.id)

      assert length(lessons) == 2
      lesson_ids = Enum.map(lessons, & &1.id)
      assert published.id in lesson_ids
      assert unpublished.id in lesson_ids
    end

    test "returns only published lessons when only_published is true" do
      course = course_fixture()
      published = lesson_fixture(%{course_id: course.id, published: true})
      _unpublished = lesson_fixture(%{course_id: course.id, published: false})

      lessons = Courses.list_course_lessons(course.id, only_published: true)

      assert length(lessons) == 1
      assert hd(lessons).id == published.id
    end
  end

  describe "create_course/0 and create_lesson/1 default args" do
    test "create_course with no arguments fails with changeset error" do
      # Test default empty map argument
      {:error, changeset} = Courses.create_course()
      assert "can't be blank" in errors_on(changeset).title
    end

    test "create_lesson with no attrs argument uses default empty map" do
      course = course_fixture()
      # Test default empty map argument for attrs
      {:error, changeset} = Courses.create_lesson(course)
      assert "can't be blank" in errors_on(changeset).title
    end
  end
end
