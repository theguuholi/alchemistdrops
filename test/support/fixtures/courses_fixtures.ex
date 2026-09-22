defmodule Alchemistdrops.CoursesFixtures do
  @moduledoc """
  This module defines test fixtures for the Courses context.
  """

  import Ecto.Query

  alias Alchemistdrops.Courses.{Course, Lesson}
  alias Alchemistdrops.Repo

  @doc """
  Generate a course with default or custom attributes.
  """
  def course_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Test Course #{System.unique_integer([:positive])}",
        description: "A comprehensive course on testing",
        body: "Full course content goes here",
        price: 99,
        published: false
      })

    %Course{}
    |> Course.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate a published course.
  """
  def published_course_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :published, true)
    course_fixture(attrs)
  end

  @doc """
  Generate a free course.
  """
  def free_course_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :price, Money.new(0, :USD))
    course_fixture(attrs)
  end

  @doc """
  Generate a course without a price, matching legacy data.
  """
  def course_without_price_fixture(attrs \\ %{}) do
    course = course_fixture(attrs)
    Repo.update_all(from(record in Course, where: record.id == ^course.id), set: [price: nil])
    %{course | price: nil}
  end

  @doc """
  Generate a lesson with default or custom attributes.
  """
  def lesson_fixture(attrs \\ %{}) do
    course_id =
      case attrs do
        %{course_id: id} -> id
        %{course: course} -> course.id
        _ -> course_fixture().id
      end

    attrs =
      attrs
      |> Map.delete(:course)
      |> Map.put(:course_id, course_id)
      |> Enum.into(%{
        title: "Test Lesson #{System.unique_integer([:positive])}",
        description: "A lesson on testing",
        content: "Full lesson content goes here",
        order: 0,
        duration: 30,
        published: false
      })

    %Lesson{}
    |> Lesson.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate a published lesson.
  """
  def published_lesson_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :published, true)
    lesson_fixture(attrs)
  end

  @doc """
  Generate multiple lessons for a course.
  """
  def lessons_fixture(course, count \\ 3) do
    Enum.map(1..count, fn order ->
      lesson_fixture(%{
        course: course,
        title: "Lesson #{order}",
        order: order - 1
      })
    end)
  end
end
