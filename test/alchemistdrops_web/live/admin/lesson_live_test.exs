defmodule AlchemistdropsWeb.Admin.LessonLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures

  @create_attrs %{
    title: "New Lesson Title",
    description: "Lesson description",
    content: "Full lesson content",
    duration: "30",
    order: "0",
    published: false
  }
  @update_attrs %{
    title: "Updated Lesson Title",
    description: "Updated description",
    content: "Updated content",
    duration: "45",
    order: "1",
    published: true
  }
  @invalid_attrs %{title: nil}

  defp create_course_with_lesson(_) do
    course = course_fixture()
    lesson = lesson_fixture(%{course: course})
    %{course: course, lesson: lesson}
  end

  describe "Admin access - unauthenticated" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      course = course_fixture()
      lesson = lesson_fixture(%{course: course})

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")
    end
  end

  describe "Admin access - regular user" do
    setup :register_and_log_in_user

    test "redirects regular users to home", %{conn: conn} do
      course = course_fixture()
      lesson = lesson_fixture(%{course: course})

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")
    end
  end

  describe "New Lesson" do
    setup [:register_and_log_in_admin_user]

    test "renders new lesson form", %{conn: conn} do
      course = course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert has_element?(view, "#admin-lesson-form", "New Lesson")
      assert has_element?(view, "#admin-lesson-form", course.title)
      assert has_element?(view, "#lesson-form")
    end

    test "validates form on change", %{conn: conn} do
      course = course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      view
      |> form("#lesson-form", lesson: @invalid_attrs)
      |> render_change()

      assert has_element?(view, "#lesson_title-error-0", "can't be blank")
    end

    test "saves new lesson and redirects to course show", %{conn: conn} do
      course = course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert {:ok, show_view, _html} =
               view
               |> form("#lesson-form", lesson: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      assert has_element?(show_view, "#flash-info", "Lesson created successfully")
      assert has_element?(show_view, "td", "New Lesson Title")
    end

    test "shows errors when submitting invalid data", %{conn: conn} do
      course = course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      view
      |> form("#lesson-form", lesson: @invalid_attrs)
      |> render_submit()

      assert has_element?(view, "#lesson_title-error-0", "can't be blank")
      assert has_element?(view, "#lesson-form")
    end

    test "cancel navigates back to course show", %{conn: conn} do
      course = course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert has_element?(view, "a", "Cancel")
    end
  end

  describe "Edit Lesson" do
    setup [:register_and_log_in_admin_user, :create_course_with_lesson]

    test "redirects when lesson not found in course", %{conn: conn, course: course} do
      invalid_id = Ecto.UUID.generate()

      assert {:ok, show_view, _html} =
               live(conn, ~p"/admin/courses/#{course}/lessons/#{invalid_id}/edit")
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      assert has_element?(show_view, "#flash-error", "Lesson not found")
    end

    test "renders edit lesson form", %{conn: conn, course: course, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      assert has_element?(view, "#admin-lesson-form", "Edit Lesson")
      assert has_element?(view, "#admin-lesson-form", course.title)
      assert has_element?(view, "#lesson-form")
    end

    test "validates form on change", %{conn: conn, course: course, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      view
      |> form("#lesson-form", lesson: @invalid_attrs)
      |> render_change()

      assert has_element?(view, "#lesson_title-error-0", "can't be blank")
    end

    test "updates lesson and redirects to course show", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      assert {:ok, show_view, _html} =
               view
               |> form("#lesson-form", lesson: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      assert has_element?(show_view, "#flash-info", "Lesson updated successfully")
      assert has_element?(show_view, "td", "Updated Lesson Title")
    end

    test "shows errors when submitting invalid data", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      view
      |> form("#lesson-form", lesson: @invalid_attrs)
      |> render_submit()

      assert has_element?(view, "#lesson_title-error-0", "can't be blank")
      assert has_element?(view, "#lesson-form")
    end
  end

  describe "Lesson ordering" do
    setup [:register_and_log_in_admin_user]

    test "displays lesson order number", %{conn: conn} do
      course = course_fixture()
      lesson1 = lesson_fixture(%{course: course, title: "First", order: 0})
      lesson2 = lesson_fixture(%{course: course, title: "Second", order: 1})

      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#lessons-#{lesson1.id}", "1")
      assert has_element?(view, "#lessons-#{lesson2.id}", "2")
    end
  end

  describe "Lesson status" do
    setup [:register_and_log_in_admin_user]

    test "shows draft badge for unpublished lesson", %{conn: conn} do
      course = course_fixture()
      lesson = lesson_fixture(%{course: course, published: false})

      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#lessons-#{lesson.id} .badge", "Draft")
    end

    test "shows published badge for published lesson", %{conn: conn} do
      course = course_fixture()
      lesson = published_lesson_fixture(%{course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#lessons-#{lesson.id} .badge", "Published")
    end
  end

  describe "Lesson duration" do
    setup [:register_and_log_in_admin_user]

    test "displays lesson duration when set", %{conn: conn} do
      course = course_fixture()
      lesson = lesson_fixture(%{course: course, duration: 45})

      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#lessons-#{lesson.id}", "45 min")
    end

    test "displays dash when duration not set", %{conn: conn} do
      course = course_fixture()
      lesson = lesson_fixture(%{course: course, duration: nil})

      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#lessons-#{lesson.id}", "—")
    end
  end
end
