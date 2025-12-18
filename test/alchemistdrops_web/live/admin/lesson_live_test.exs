defmodule AlchemistdropsWeb.Admin.LessonLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures

  @create_attrs %{
    title: "Test Lesson Title",
    description: "A comprehensive lesson description",
    content: "Full lesson content here",
    duration: "30",
    order: "0",
    published: true
  }
  @update_attrs %{
    title: "Updated Lesson Title",
    description: "Updated lesson description",
    content: "Updated lesson content",
    duration: "45",
    order: "1",
    published: false
  }
  @invalid_attrs %{title: nil}

  defp create_course_and_lesson(_) do
    course = course_fixture()
    lesson = lesson_fixture(%{course: course})
    %{course: course, lesson: lesson}
  end

  defp create_course(_) do
    course = course_fixture()
    %{course: course}
  end

  describe "Form - New Lesson" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "given admin user, when visiting new lesson page, then displays form", %{
      conn: conn,
      course: course
    } do
      {:ok, _view, html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert html =~ "New Lesson"
      assert html =~ "Lesson Title"
      assert html =~ "Short Description"
      assert html =~ course.title
    end

    test "given valid lesson data, when submitting form, then creates lesson", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert {:ok, show_live, _html} =
               form_live
               |> form("#lesson-form", lesson: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      html = render(show_live)
      assert html =~ "Lesson created successfully"
      assert html =~ "Test Lesson Title"
    end

    test "given invalid lesson data, when submitting form, then displays errors", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert form_live
             |> form("#lesson-form", lesson: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end

    test "given empty title, when validating form, then shows required error", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      html =
        form_live
        |> form("#lesson-form", lesson: %{title: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "given title exceeding max length, when validating form, then shows length error", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      long_title = String.duplicate("a", 300)

      html =
        form_live
        |> form("#lesson-form", lesson: %{title: long_title})
        |> render_change()

      assert html =~ "should be at most 255 character"
    end

    test "given negative order value, when validating form, then shows validation error", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      html =
        form_live
        |> form("#lesson-form", lesson: %{title: "Test", order: "-1"})
        |> render_change()

      assert html =~ "must be greater than or equal to 0"
    end

    test "given zero duration, when validating form, then shows validation error", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      html =
        form_live
        |> form("#lesson-form", lesson: %{title: "Test", duration: "0"})
        |> render_change()

      assert html =~ "must be greater than 0"
    end

    test "given user on form page, when clicking cancel, then returns to course show", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert {:ok, _show_live, _html} =
               form_live
               |> element("a", "Cancel")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")
    end

    test "given course exists, when viewing new lesson form, then shows course title in breadcrumb",
         %{
           conn: conn,
           course: course
         } do
      {:ok, _view, html} = live(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert html =~ course.title
    end
  end

  describe "Form - Edit Lesson" do
    setup [:register_and_log_in_admin_user, :create_course_and_lesson]

    test "given existing lesson, when visiting edit page, then displays form with data", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, _view, html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      assert html =~ "Edit Lesson"
      assert html =~ lesson.title
    end

    test "given valid update data, when submitting form, then updates lesson", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      assert {:ok, show_live, _html} =
               form_live
               |> form("#lesson-form", lesson: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      html = render(show_live)
      assert html =~ "Lesson updated successfully"
      assert html =~ "Updated Lesson Title"
    end

    test "given invalid update data, when submitting form, then displays errors", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      assert form_live
             |> form("#lesson-form", lesson: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end
  end

  describe "Form access control" do
    setup [:create_course_and_lesson]

    test "given unauthenticated user, when visiting new lesson page, then redirects", %{
      conn: conn,
      course: course
    } do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/#{course}/lessons/new")
    end

    test "given unauthenticated user, when visiting edit lesson page, then redirects", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:error, {:redirect, %{to: "/"}}} =
        live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")
    end

    test "given non-admin user, when visiting new lesson page, then redirects", %{
      conn: conn,
      course: course
    } do
      {:ok, conn: conn} = register_and_log_in_user(%{conn: conn})
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/#{course}/lessons/new")
    end

    test "given non-admin user, when visiting edit lesson page, then redirects", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, conn: conn} = register_and_log_in_user(%{conn: conn})

      {:error, {:redirect, %{to: "/"}}} =
        live(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")
    end
  end
end
