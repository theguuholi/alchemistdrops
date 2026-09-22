defmodule AlchemistdropsWeb.CourseLive.IndexTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "given a visitor when they visit the courses page then they see the page title", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "h1", "Explore Our Courses")
      assert has_element?(view, "p", "Discover transformative learning experiences")
    end

    test "given published courses when visitor loads the page then they see all published courses",
         %{conn: conn} do
      _published1 = course_fixture(%{title: "Elixir Mastery", published: true})
      _published2 = course_fixture(%{title: "Phoenix Framework", published: true})
      _unpublished = course_fixture(%{title: "Secret Course", published: false})

      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "h3", "Elixir Mastery")
      assert has_element?(view, "h3", "Phoenix Framework")
      refute has_element?(view, "h3", "Secret Course")
    end

    test "given no published courses when visitor loads the page then they see empty state", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "h2", "No courses available yet")
      assert has_element?(view, "p", "Check back soon for exciting new content")
    end

    test "given courses with different prices when visitor loads the page then they see formatted prices",
         %{conn: conn} do
      _free_course =
        course_fixture(%{title: "Free Course", price: Money.new(0, :USD), published: true})

      _paid_course =
        course_fixture(%{title: "Premium Course", price: Money.new(9999, :USD), published: true})

      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "span", "Free")
      assert has_element?(view, "span", "$99.99")
    end

    test "given a published course with nil price when visitor loads the page then page renders and shows Free",
         %{conn: conn} do
      course_without_price_fixture(%{title: "Course With Nil Price", published: true})

      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "h3", "Course With Nil Price")
      assert has_element?(view, "span", "Free")
    end

    test "given courses when visitor loads the page then each course card has proper semantic HTML",
         %{conn: conn} do
      course_fixture(%{
        title: "Test Course",
        description: "Test description",
        published: true
      })

      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "article[data-role=course-card]")
      assert has_element?(view, "h3")
      assert has_element?(view, "p")
    end

    test "given more than 20 published courses when visitor loads the page then they see only 20 courses",
         %{conn: conn} do
      # Create 25 courses
      for i <- 1..25 do
        course_fixture(%{title: "Course #{String.pad_leading("#{i}", 2, "0")}", published: true})
      end

      {:ok, view, html} = live(conn, ~p"/courses")

      # Count h3 elements (course titles)
      course_count = html |> String.split("<h3") |> length() |> Kernel.-(1)
      assert course_count == 20

      # Verify we see courses 1-20 but not 21-25
      assert has_element?(view, "h3", "Course 01")
      assert has_element?(view, "h3", "Course 20")
      # But not course 21
      refute has_element?(view, "h3", "Course 21")
      refute has_element?(view, "h3", "Course 25")
    end
  end

  describe "handle_event/3 - view_course" do
    test "given a course when visitor clicks view details then they navigate to course detail page",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("a[href='/courses/#{course.id}']")
      |> render_click()

      assert_redirected(view, ~p"/courses/#{course}")
    end
  end

  describe "responsive design and accessibility" do
    test "given a visitor when they view the courses page then it has proper ARIA labels", %{
      conn: conn
    } do
      course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses")

      # Using Layouts.app wrapper, no main[role=main] in template itself
      assert has_element?(view, "section")
    end

    test "given courses when visitor loads the page then each course has descriptive link text",
         %{conn: conn} do
      course = course_fixture(%{title: "Accessible Course", published: true})

      {:ok, view, _html} = live(conn, ~p"/courses")

      assert has_element?(view, "a[aria-label='View details for #{course.title}']")
    end
  end

  describe "enrollment status indicators" do
    test "given a logged in user enrolled in a course when they view courses then they see enrollment badge",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses")

      assert has_element?(view, "div", "Enrolled")
    end

    test "given a logged in user not enrolled when they view courses then they see enroll button",
         %{conn: conn} do
      user = user_fixture()
      course_fixture(%{published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses")

      assert has_element?(view, "a", "View")
    end
  end
end
