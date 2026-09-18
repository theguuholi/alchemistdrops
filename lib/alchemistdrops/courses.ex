defmodule Alchemistdrops.Courses do
  @moduledoc """
  Owns the course catalog and its ordered lesson curriculum.

  This boundary matters because publication visibility, Stripe association,
  lesson ownership, and curriculum ordering must remain consistent regardless
  of which controller, LiveView, or background process performs the operation.
  """

  import Ecto.Query, warn: false

  alias Alchemistdrops.Courses.{Course, Lesson}
  alias Alchemistdrops.Payments
  alias Alchemistdrops.Repo

  ## Course functions

  @doc """
  Returns the list of published courses ordered by title.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.published_course_fixture()
      iex> Enum.map(Alchemistdrops.Courses.list_courses(), & &1.id)
      [course.id]

  """
  @spec list_courses() :: [Course.t()]
  def list_courses do
    Course
    |> where([c], c.published == true)
    |> order_by([c], asc: c.title)
    |> Repo.all()
  end

  @doc """
  Returns the list of published courses ordered by title.
  Alias for list_courses/0.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.published_course_fixture()
      iex> Enum.map(Alchemistdrops.Courses.list_published_courses(), & &1.id)
      [course.id]

  """
  @spec list_published_courses() :: [Course.t()]
  def list_published_courses do
    list_courses()
  end

  @doc """
  Returns all courses including unpublished ones, ordered by title.
  Intended for admin use.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> Enum.map(Alchemistdrops.Courses.list_all_courses(), & &1.id)
      [course.id]

  """
  @spec list_all_courses() :: [Course.t()]
  def list_all_courses do
    Course
    |> order_by([c], asc: c.title)
    |> Repo.all()
  end

  @doc """
  Returns the total count of courses.

  ## Examples

      iex> _course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> Alchemistdrops.Courses.count_courses()
      1

  """
  @spec count_courses() :: non_neg_integer()
  def count_courses do
    Repo.aggregate(Course, :count)
  end

  @doc """
  Gets a single course with lessons preloaded.

  Raises `Ecto.NoResultsError` if the Course does not exist.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> Alchemistdrops.Courses.get_course!(course.id).id == course.id
      true

  """
  @spec get_course!(Ecto.UUID.t()) :: Course.t()
  def get_course!(id) do
    Course
    |> Repo.get!(id)
    |> Repo.preload(:lessons)
  end

  @doc """
  Gets a single course with lessons preloaded and ordered by the order field.

  Raises `Ecto.NoResultsError` if the Course does not exist.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> lesson = Alchemistdrops.CoursesFixtures.lesson_fixture(%{course: course})
      iex> loaded = Alchemistdrops.Courses.get_course_with_lessons!(course.id)
      iex> Enum.map(loaded.lessons, & &1.id)
      [lesson.id]

  """
  @spec get_course_with_lessons!(Ecto.UUID.t()) :: Course.t()
  def get_course_with_lessons!(id) do
    Course
    |> Repo.get!(id)
    |> Repo.preload(lessons: from(l in Lesson, order_by: [asc: l.order]))
  end

  @doc """
  Creates a course.

  ## Examples

      iex> {:ok, course} = Alchemistdrops.Courses.create_course(%{title: "Elixir", description: "OTP"})
      iex> course.title
      "Elixir"

      iex> {:error, changeset} = Alchemistdrops.Courses.create_course(%{})
      iex> changeset.valid?
      false

  """
  @spec create_course() :: {:ok, Course.t()} | {:error, Ecto.Changeset.t()}
  @spec create_course(map() | keyword()) :: {:ok, Course.t()} | {:error, Ecto.Changeset.t()}
  def create_course(attrs \\ %{}) do
    attrs = normalize_attrs(attrs)
    changeset = %Course{} |> Course.changeset(attrs)

    if changeset.valid? do
      case maybe_assign_stripe_ids(changeset, attrs) do
        {:ok, attrs_with_stripe} ->
          merged = merge_stripe_ids_into_attrs(attrs, attrs_with_stripe)

          changeset
          |> Course.changeset(merged)
          |> Repo.insert()

        {:error, reason} ->
          {:error, add_stripe_error(changeset, reason)}
      end
    else
      Repo.insert(changeset)
    end
  end

  @doc """
  Updates a course.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> {:ok, updated} = Alchemistdrops.Courses.update_course(course, %{title: "Updated"})
      iex> updated.title
      "Updated"

  """
  @spec update_course(Course.t(), map() | keyword()) ::
          {:ok, Course.t()} | {:error, Ecto.Changeset.t()}
  def update_course(%Course{} = course, attrs) do
    attrs = normalize_attrs(attrs)
    changeset = course |> Course.changeset(attrs)

    if changeset.valid? do
      case maybe_assign_stripe_ids(changeset, attrs, course) do
        {:ok, attrs_with_stripe} ->
          merged = merge_stripe_ids_into_attrs(attrs, attrs_with_stripe)

          course
          |> Course.changeset(merged)
          |> Repo.update()

        {:error, reason} ->
          {:error, add_stripe_error(changeset, reason)}
      end
    else
      Repo.update(changeset)
    end
  end

  @doc """
  Deletes a course.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> {:ok, deleted} = Alchemistdrops.Courses.delete_course(course)
      iex> deleted.id == course.id
      true

  """
  @spec delete_course(Course.t()) :: {:ok, Course.t()} | {:error, Ecto.Changeset.t()}
  def delete_course(%Course{} = course) do
    Repo.delete(course)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking course changes.

  ## Examples

      iex> changeset = Alchemistdrops.Courses.change_course(%Alchemistdrops.Courses.Course{})
      iex> match?(%Ecto.Changeset{}, changeset)
      true

  """
  @spec change_course(Course.t()) :: Ecto.Changeset.t()
  @spec change_course(Course.t(), map()) :: Ecto.Changeset.t()
  def change_course(%Course{} = course, attrs \\ %{}) do
    Course.changeset(course, attrs)
  end

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(attrs), do: Map.new(attrs || [])

  defp maybe_assign_stripe_ids(changeset, attrs, course \\ nil) do
    price = price_from_changeset(changeset)

    Payments.ensure_stripe_product_and_price_for_course(
      name: attr_or_course(attrs, :title, course) || "Course",
      description: attr_or_course(attrs, :description, course) || "",
      amount_cents: price_to_cents(price),
      currency: price_to_currency_string(price),
      stripe_product_id: attr_or_course(attrs, :stripe_product_id, course),
      stripe_price_id: attr_or_course(attrs, :stripe_price_id, course)
    )
  end

  defp price_from_changeset(changeset) do
    Ecto.Changeset.get_change(changeset, :price) ||
      Map.get(changeset.data, :price)
  end

  defp attr_or_course(attrs, key, course) when is_atom(key) do
    get_attr(attrs, key) || (course && Map.get(course, key))
  end

  defp get_attr(attrs, key) when is_atom(key),
    do: Map.get(attrs, key) || Map.get(attrs, to_string(key))

  defp price_to_cents(%Money{amount: amount}), do: amount
  defp price_to_cents(nil), do: nil

  defp price_to_currency_string(%Money{currency: currency}),
    do: currency |> to_string() |> String.downcase()

  defp price_to_currency_string(_), do: "usd"

  defp merge_stripe_ids_into_attrs(attrs, %{stripe_product_id: pid, stripe_price_id: price_id}) do
    # Use same key type as attrs so Ecto.Changeset.cast accepts the map (no mixed keys)
    stripe_map =
      if Enum.any?(Map.keys(attrs), &is_binary/1) do
        %{"stripe_product_id" => pid || "", "stripe_price_id" => price_id || ""}
      else
        %{stripe_product_id: pid || "", stripe_price_id: price_id || ""}
      end

    Map.merge(attrs, stripe_map)
  end

  defp merge_stripe_ids_into_attrs(attrs, %{}), do: attrs

  defp add_stripe_error(changeset, reason) do
    message = "Could not associate with Stripe: #{inspect(reason)}"
    Ecto.Changeset.add_error(changeset, :stripe_price_id, message)
  end

  ## Lesson functions

  @doc """
  Returns the list of lessons for a course, ordered by the order field.

  ## Options

  - `:only_published` - if true, only returns published lessons (default: false)

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> lesson = Alchemistdrops.CoursesFixtures.lesson_fixture(%{course: course})
      iex> Enum.map(Alchemistdrops.Courses.list_course_lessons(course.id), & &1.id)
      [lesson.id]

  """
  @spec list_course_lessons(Ecto.UUID.t()) :: [Lesson.t()]
  @spec list_course_lessons(Ecto.UUID.t(), keyword()) :: [Lesson.t()]
  def list_course_lessons(course_id, opts \\ []) do
    query =
      Lesson
      |> where([l], l.course_id == ^course_id)
      |> order_by([l], asc: l.order)

    query =
      if Keyword.get(opts, :only_published, false) do
        where(query, [l], l.published == true)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Creates a lesson for a course.

  If no order is specified, automatically assigns the next available order number.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> {:ok, lesson} = Alchemistdrops.Courses.create_lesson(course, %{title: "First lesson"})
      iex> {lesson.course_id == course.id, lesson.order}
      {true, 0}

  """
  @spec create_lesson(Course.t()) :: {:ok, Lesson.t()} | {:error, Ecto.Changeset.t()}
  @spec create_lesson(Course.t(), map()) :: {:ok, Lesson.t()} | {:error, Ecto.Changeset.t()}
  def create_lesson(%Course{} = course, attrs \\ %{}) do
    attrs =
      attrs
      |> stringify_keys()
      |> ensure_lesson_order(course)
      |> Map.put("course_id", course.id)

    %Lesson{}
    |> Lesson.changeset(attrs)
    |> Repo.insert()
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp ensure_lesson_order(attrs, course) do
    has_order? = Map.has_key?(attrs, "order")

    if has_order?,
      do: attrs,
      else: Map.put(attrs, "order", get_next_lesson_order(course))
  end

  defp get_next_lesson_order(course) do
    query =
      from l in Lesson,
        where: l.course_id == ^course.id,
        select: max(l.order)

    case Repo.one(query) do
      nil -> 0
      max_order -> max_order + 1
    end
  end

  @doc """
  Updates a lesson.

  ## Examples

      iex> lesson = Alchemistdrops.CoursesFixtures.lesson_fixture()
      iex> {:ok, updated} = Alchemistdrops.Courses.update_lesson(lesson, %{title: "Updated lesson"})
      iex> updated.title
      "Updated lesson"

  """
  @spec update_lesson(Lesson.t(), map()) :: {:ok, Lesson.t()} | {:error, Ecto.Changeset.t()}
  def update_lesson(%Lesson{} = lesson, attrs) do
    lesson
    |> Lesson.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lesson.

  ## Examples

      iex> lesson = Alchemistdrops.CoursesFixtures.lesson_fixture()
      iex> {:ok, deleted} = Alchemistdrops.Courses.delete_lesson(lesson)
      iex> deleted.id == lesson.id
      true

  """
  @spec delete_lesson(Lesson.t()) :: {:ok, Lesson.t()} | {:error, Ecto.Changeset.t()}
  def delete_lesson(%Lesson{} = lesson) do
    Repo.delete(lesson)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lesson changes.

  ## Examples

      iex> changeset = Alchemistdrops.Courses.change_lesson(%Alchemistdrops.Courses.Lesson{})
      iex> match?(%Ecto.Changeset{}, changeset)
      true

  """
  @spec change_lesson(Lesson.t()) :: Ecto.Changeset.t()
  @spec change_lesson(Lesson.t(), map()) :: Ecto.Changeset.t()
  def change_lesson(%Lesson{} = lesson, attrs \\ %{}) do
    Lesson.changeset(lesson, attrs)
  end

  @doc """
  Reorders lessons for a course.

  Takes a list of lesson IDs in the desired order and updates their order field accordingly.
  All lessons must belong to the specified course.

  ## Examples

      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> first = Alchemistdrops.CoursesFixtures.lesson_fixture(%{course: course, order: 0})
      iex> second = Alchemistdrops.CoursesFixtures.lesson_fixture(%{course: course, order: 1})
      iex> {:ok, reordered} = Alchemistdrops.Courses.reorder_lessons(course, [second.id, first.id])
      iex> Enum.map(reordered, &{&1.id, &1.order})
      [{second.id, 0}, {first.id, 1}]

  """
  @spec reorder_lessons(Course.t(), [Ecto.UUID.t()]) ::
          {:ok, [Lesson.t()]} | {:error, :invalid_lessons}
  def reorder_lessons(%Course{} = course, lesson_ids) when is_list(lesson_ids) do
    # Fetch all lessons for this course
    course_lessons =
      Lesson
      |> where([l], l.course_id == ^course.id)
      |> Repo.all()

    course_lesson_ids = MapSet.new(course_lessons, & &1.id)
    provided_lesson_ids = MapSet.new(lesson_ids)

    # Validate that all provided lesson IDs belong to this course
    # and that all course lessons are included
    if valid_lesson_ids?(course_lesson_ids, provided_lesson_ids) do
      update_lesson_order(course_lessons, lesson_ids)
    else
      {:error, :invalid_lessons}
    end
  end

  defp valid_lesson_ids?(course_lesson_ids, provided_lesson_ids) do
    MapSet.equal?(course_lesson_ids, provided_lesson_ids)
  end

  defp update_lesson_order(course_lessons, lesson_ids) do
    # Update each lesson with its new order
    # Since all lesson IDs are validated upstream, this should always succeed
    lessons =
      lesson_ids
      |> Enum.with_index()
      |> Enum.map(fn {lesson_id, index} ->
        lesson = Enum.find(course_lessons, &(&1.id == lesson_id))
        {:ok, updated} = update_lesson(lesson, %{order: index})
        updated
      end)

    {:ok, lessons}
  end
end
