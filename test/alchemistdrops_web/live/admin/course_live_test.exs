defmodule AlchemistdropsWeb.Admin.CourseLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures

  @create_attrs %{
    title: "New Course Title",
    description: "A comprehensive course description",
    body: "Full course content",
    price_cents: "9900",
    published: false
  }
  @update_attrs %{
    title: "Updated Course Title",
    description: "Updated description",
    body: "Updated content",
    price_cents: "19900",
    published: true
  }
  @invalid_attrs %{title: nil, description: nil}

  defp create_course(_) do
    course = course_fixture()
    %{course: course}
  end

  describe "Admin access - unauthenticated" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      course = course_fixture()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/courses")
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/courses/new")

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/admin/courses/#{course}")

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/admin/courses/#{course}/edit")
    end
  end

  describe "Admin access - regular user" do
    setup :register_and_log_in_user

    test "redirects regular users to home", %{conn: conn} do
      course = course_fixture()

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses")
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/new")
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/#{course}")
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/#{course}/edit")
    end
  end

  describe "Index" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "lists all courses", %{conn: conn, course: course} do
      {:ok, view, html} = live(conn, ~p"/admin/courses")

      assert html =~ "Courses"
      assert has_element?(view, "#courses-#{course.id}")
    end

    test "displays course title in listing", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}", course.title)
    end

    test "shows draft badge for unpublished courses", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id} .badge", "Draft")
    end

    test "shows published badge for published courses", %{conn: conn} do
      published = published_course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{published.id} .badge", "Published")
    end

    test "shows Free for zero-price courses", %{conn: conn} do
      free = free_course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{free.id}", "Free")
    end

    test "displays empty state when no courses", %{conn: conn, course: course} do
      Alchemistdrops.Courses.delete_course(course)
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#no-courses", "No courses yet")
    end

    test "navigates to new course form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert {:ok, _form_view, html} =
               view
               |> element("a", "New Course")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/new")

      assert html =~ "New Course"
    end

    test "navigates to course show page", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert {:ok, _show_view, html} =
               view
               |> element("#courses-#{course.id} a", "View")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      assert html =~ course.title
    end

    test "navigates to edit course form", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert {:ok, _form_view, html} =
               view
               |> element("#courses-#{course.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}/edit")

      assert html =~ "Edit Course"
    end

    test "deletes course in listing", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}")

      view
      |> element("#courses-#{course.id} a", "Delete")
      |> render_click()

      refute has_element?(view, "#courses-#{course.id}")
    end
  end

  describe "New Course" do
    setup [:register_and_log_in_admin_user]

    test "renders new course form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/courses/new")

      assert html =~ "New Course"
      assert has_element?(view, "#course-form")
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/new")

      html =
        view
        |> form("#course-form", course: @invalid_attrs)
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "saves new course and redirects to index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/new")

      assert {:ok, index_view, html} =
               view
               |> form("#course-form", course: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses")

      assert html =~ "Course created successfully"
      assert has_element?(index_view, "td", "New Course Title")
    end

    test "shows errors when submitting invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/new")

      html =
        view
        |> form("#course-form", course: @invalid_attrs)
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert has_element?(view, "#course-form")
    end
  end

  describe "Edit Course" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "renders edit course form", %{conn: conn, course: course} do
      {:ok, view, html} = live(conn, ~p"/admin/courses/#{course}/edit")

      assert html =~ "Edit Course"
      assert has_element?(view, "#course-form")
    end

    test "validates form on change", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      html =
        view
        |> form("#course-form", course: @invalid_attrs)
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "updates course and redirects to index", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      assert {:ok, index_view, html} =
               view
               |> form("#course-form", course: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses")

      assert html =~ "Course updated successfully"
      assert has_element?(index_view, "td", "Updated Course Title")
    end

    test "updates course and returns to show when return_to=show", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/edit?return_to=show")

      assert {:ok, _show_view, html} =
               view
               |> form("#course-form", course: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      assert html =~ "Course updated successfully"
      assert html =~ "Updated Course Title"
    end

    test "shows errors when submitting invalid data", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      html =
        view
        |> form("#course-form", course: @invalid_attrs)
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert has_element?(view, "#course-form")
    end
  end

  describe "Show Course" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "displays course details", %{conn: conn, course: course} do
      {:ok, view, html} = live(conn, ~p"/admin/courses/#{course}")

      assert html =~ course.title
      assert html =~ course.description
      assert has_element?(view, ".badge", "Draft")
    end

    test "displays published badge for published course", %{conn: conn} do
      published = published_course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{published}")

      assert has_element?(view, ".badge", "Published")
    end

    test "shows empty lessons message when no lessons", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#no-lessons")
    end

    test "displays lessons when they exist", %{conn: conn, course: course} do
      lesson = lesson_fixture(%{course: course, title: "Test Lesson"})
      {:ok, view, html} = live(conn, ~p"/admin/courses/#{course}")

      assert html =~ "Lessons (1)"
      assert has_element?(view, "#lessons-#{lesson.id}", "Test Lesson")
    end

    test "navigates to edit course form", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert {:ok, _form_view, html} =
               view
               |> element("a", "Edit Course")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}/edit?return_to=show")

      assert html =~ "Edit Course"
    end

    test "navigates to add lesson form", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert {:ok, _form_view, html} =
               view
               |> element("a", "Add Lesson")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert html =~ "New Lesson"
    end

    test "deletes lesson from course", %{conn: conn, course: course} do
      lesson = lesson_fixture(%{course: course})
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "#lessons-#{lesson.id}")

      view
      |> element("#lessons-#{lesson.id} a", "Delete")
      |> render_click()

      refute has_element?(view, "#lessons-#{lesson.id}")
    end

    test "navigates back to courses list", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "a", "Back to courses")
    end
  end
end
