defmodule AlchemistdropsWeb.Admin.CourseLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures

  @create_attrs %{
    title: "Test Course Title",
    description: "A comprehensive test course description",
    body: "Full course content here",
    price: "9900",
    published: true
  }
  @update_attrs %{
    title: "Updated Course Title",
    description: "Updated course description",
    body: "Updated course content",
    price: "19900",
    published: false
  }
  @invalid_attrs %{title: nil, description: nil}

  defp create_course(_) do
    course = course_fixture()
    %{course: course}
  end

  defp create_course_with_lessons(_) do
    course = course_fixture()
    lessons = lessons_fixture(course, 3)
    %{course: course, lessons: lessons}
  end

  describe "Index as admin" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "given admin user, when visiting courses index, then lists all courses", %{
      conn: conn,
      course: course
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "h1", "Manage Courses")
      assert has_element?(view, "#courses-#{course.id}")
    end

    test "given course exists, when viewing index, then displays course title and status", %{
      conn: conn,
      course: course
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}")
      assert render(view) =~ course.title
    end

    test "given admin on index page, when clicking new course, then navigates to form", %{
      conn: conn
    } do
      {:ok, index_live, _html} = live(conn, ~p"/admin/courses")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Course")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/new")

      assert render(form_live) =~ "New Course"
    end

    test "given course in listing, when clicking delete, then removes course", %{
      conn: conn,
      course: course
    } do
      {:ok, index_live, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(index_live, "#courses-#{course.id}")
      assert index_live |> element("#courses-#{course.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#courses-#{course.id}")
    end

    test "given no courses exist, when visiting index, then shows empty state", %{
      conn: conn,
      course: course
    } do
      Alchemistdrops.Courses.delete_course(course)

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "p", "No courses yet")
    end
  end

  describe "Index access control" do
    setup [:create_course]

    test "given unauthenticated user, when visiting admin courses, then redirects", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses")
    end

    test "given non-admin user, when visiting admin courses, then redirects", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses")
    end
  end

  describe "Form - New Course" do
    setup [:register_and_log_in_admin_user]

    test "given admin user, when visiting new course page, then displays form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/new")

      assert has_element?(view, "h1", "New Course")
      assert has_element?(view, "label", "Course Title")
      assert has_element?(view, "label", "Short Description")
    end

    test "given valid course data, when submitting form, then creates course", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      assert {:ok, index_live, _html} =
               form_live
               |> form("#course-form", course: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses")

      assert has_element?(index_live, "[role=alert]", "Course created successfully")
      assert has_element?(index_live, "td", "Test Course Title")
    end

    test "given invalid course data, when submitting form, then displays errors", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      form_live
      |> form("#course-form", course: @invalid_attrs)
      |> render_change()

      assert has_element?(form_live, "p.text-error", "can't be blank")
    end

    test "given empty required fields, when validating form, then shows required errors", %{
      conn: conn
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      form_live
      |> form("#course-form", course: %{title: "", description: ""})
      |> render_change()

      assert has_element?(form_live, "p.text-error", "can't be blank")
    end

    test "given title exceeding max length, when validating form, then shows length error", %{
      conn: conn
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      long_title = String.duplicate("a", 300)

      form_live
      |> form("#course-form", course: %{title: long_title, description: "Valid description"})
      |> render_change()

      assert has_element?(form_live, "p.text-error", "should be at most 255 character(s)")
    end

    test "given price of zero, when submitting form, then creates free course", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      attrs = Map.put(@create_attrs, :price, "0")

      assert {:ok, index_live, _html} =
               form_live
               |> form("#course-form", course: attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses")

      assert has_element?(index_live, "[role=alert]", "Course created successfully")
    end

    test "given user on form page, when clicking cancel, then returns to index", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      assert {:ok, _index_live, _html} =
               form_live
               |> element("a", "Cancel")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses")
    end
  end

  describe "Form - Edit Course" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "given existing course, when visiting edit page, then displays form with data", %{
      conn: conn,
      course: course
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      assert has_element?(view, "h1", "Edit Course")
      assert has_element?(view, "input[value='#{course.title}']")
    end

    test "given valid update data, when submitting form, then updates course", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      assert {:ok, index_live, _html} =
               form_live
               |> form("#course-form", course: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses")

      assert has_element?(index_live, "[role=alert]", "Course updated successfully")
      assert has_element?(index_live, "td", "Updated Course Title")
    end

    test "given invalid update data, when submitting form, then displays errors", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      form_live
      |> form("#course-form", course: @invalid_attrs)
      |> render_change()

      assert has_element?(form_live, "p.text-error", "can't be blank")
    end

    test "given return_to=show param, when submitting form, then returns to show page", %{
      conn: conn,
      course: course
    } do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/edit?return_to=show")

      assert {:ok, show_live, _html} =
               form_live
               |> form("#course-form", course: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}")

      assert has_element?(show_live, "[role=alert]", "Course updated successfully")
      assert has_element?(show_live, "h1", "Updated Course Title")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_admin_user, :create_course_with_lessons]

    test "given course exists, when visiting show page, then displays course details", %{
      conn: conn,
      course: course
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "h1", course.title)
      assert has_element?(view, "p", course.description)
      assert has_element?(view, "h3.card-title", "Description")
    end

    test "given course has lessons, when visiting show page, then displays lessons", %{
      conn: conn,
      course: course,
      lessons: lessons
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "h3.card-title", "Lessons")
      assert has_element?(view, ".badge", "#{length(lessons)}")

      for lesson <- lessons do
        assert has_element?(view, "#lesson-#{lesson.id}")
      end
    end

    test "given user on show page, when clicking add lesson, then navigates to lesson form", %{
      conn: conn,
      course: course
    } do
      {:ok, show_live, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert {:ok, form_live, _html} =
               show_live
               |> element("a", "Add Lesson")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}/lessons/new")

      assert render(form_live) =~ "New Lesson"
    end

    test "given lesson exists, when clicking edit lesson, then navigates to edit form", %{
      conn: conn,
      course: course,
      lessons: [lesson | _]
    } do
      {:ok, show_live, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert {:ok, form_live, _html} =
               show_live
               |> element("#lesson-#{lesson.id} a[href*='edit']")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}/lessons/#{lesson}/edit")

      assert render(form_live) =~ "Edit Lesson"
    end

    test "given lesson exists, when clicking delete, then removes lesson from list", %{
      conn: conn,
      course: course,
      lessons: [lesson | _]
    } do
      {:ok, show_live, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(show_live, "#lesson-#{lesson.id}")

      show_live
      |> element("#lesson-#{lesson.id} button.text-error")
      |> render_click()

      refute has_element?(show_live, "#lesson-#{lesson.id}")
    end

    test "given course with no lessons, when visiting show page, then shows empty state", %{
      conn: conn
    } do
      course = course_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "p", "No lessons yet")
    end

    test "given course exists, when visiting show page, then displays Stripe integration section",
         %{
           conn: conn,
           course: course
         } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "h3.card-title", "Stripe Integration")
      assert has_element?(view, "dt", "Product ID")
      assert has_element?(view, "dt", "Price ID")
    end

    test "given course exists, when visiting show page, then displays metadata section", %{
      conn: conn,
      course: course
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert has_element?(view, "dt", "Created")
      assert has_element?(view, "dt", "Last Updated")
    end

    test "given user on show page, when clicking edit course, then navigates to edit form", %{
      conn: conn,
      course: course
    } do
      {:ok, show_live, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert {:ok, form_live, _html} =
               show_live
               |> element("a", "Edit Course")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses/#{course}/edit?return_to=show")

      assert render(form_live) =~ "Edit Course"
    end

    test "given user on show page, when clicking back to courses, then navigates to index", %{
      conn: conn,
      course: course
    } do
      {:ok, show_live, _html} = live(conn, ~p"/admin/courses/#{course}")

      assert {:ok, _index_live, _html} =
               show_live
               |> element("a", "Back to Courses")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/courses")
    end
  end

  describe "Show access control" do
    setup [:create_course]

    test "given unauthenticated user, when visiting course show, then redirects", %{
      conn: conn,
      course: course
    } do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/#{course}")
    end

    test "given non-admin user, when visiting course show, then redirects", %{
      conn: conn,
      course: course
    } do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses/#{course}")
    end
  end

  describe "Show delete_lesson with invalid lesson id" do
    setup [:register_and_log_in_admin_user, :create_course]

    test "given invalid lesson id, when clicking delete, then does nothing", %{
      conn: conn,
      course: course
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/courses/#{course}")

      # Send delete_lesson event with an invalid ID directly
      send(view.pid, {:event, "delete_lesson", %{"id" => Ecto.UUID.generate()}})

      # The view should remain unchanged (no crash)
      assert has_element?(view, "h1", course.title)
    end
  end

  describe "Form - Save Errors" do
    setup [:register_and_log_in_admin_user]

    test "given invalid data, when submitting new course form via render_submit, then shows error",
         %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/new")

      # Submit the form with invalid data that will fail on submission
      # (title that is too long to pass validation on submit)
      long_title = String.duplicate("a", 300)

      result =
        form_live
        |> form("#course-form", course: %{title: long_title, description: "Valid"})
        |> render_submit()

      # Should show error, not redirect
      assert result =~ "should be at most 255 character(s)"
    end

    test "given invalid data, when submitting edit course form via render_submit, then shows error",
         %{conn: conn} do
      course = course_fixture()
      {:ok, form_live, _html} = live(conn, ~p"/admin/courses/#{course}/edit")

      # Submit the form with invalid data
      long_title = String.duplicate("a", 300)

      result =
        form_live
        |> form("#course-form", course: %{title: long_title})
        |> render_submit()

      # Should show error, not redirect
      assert result =~ "should be at most 255 character(s)"
    end
  end

  describe "Index format_price helper" do
    alias AlchemistdropsWeb.Admin.CourseLive.Index

    test "given nil price, when formatting, then returns Free" do
      assert Index.format_price(nil) == "Free"
    end

    test "given Money zero, when formatting, then returns Free" do
      assert Index.format_price(Money.new(0, :USD)) == "Free"
    end

    test "given non-zero Money, when formatting, then returns formatted price" do
      result = Index.format_price(Money.new(9999, :USD))
      assert result == "$99.99"
    end

    test "given unexpected value, when formatting, then returns Free" do
      assert Index.format_price("invalid") == "Free"
      assert Index.format_price(123) == "Free"
    end
  end

  describe "Show format_price helper" do
    alias AlchemistdropsWeb.Admin.CourseLive.Show

    test "given nil price, when formatting, then returns Free" do
      assert Show.format_price(nil) == "Free"
    end

    test "given Money zero, when formatting, then returns Free" do
      assert Show.format_price(Money.new(0, :USD)) == "Free"
    end

    test "given non-zero Money, when formatting, then returns formatted price" do
      result = Show.format_price(Money.new(9999, :USD))
      assert result == "$99.99"
    end

    test "given unexpected value, when formatting, then returns Free" do
      assert Show.format_price("invalid") == "Free"
      assert Show.format_price(123) == "Free"
    end
  end

  describe "Form return_path helper" do
    alias AlchemistdropsWeb.Admin.CourseLive.Form

    test "given return_to index, when getting path, then returns admin courses path" do
      assert Form.return_path("index", %{id: "123"}) == "/admin/courses"
    end

    test "given return_to show, when getting path, then returns course show path" do
      course = course_fixture()
      assert Form.return_path("show", course) == "/admin/courses/#{course.id}"
    end
  end
end
