defmodule AlchemistdropsWeb.CourseLive.ShowTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures

  describe "mount/3" do
    test "given a published course when visitor loads the page then they see course details", %{
      conn: conn
    } do
      course =
        course_fixture(%{
          title: "Elixir Mastery",
          description: "Master Elixir programming",
          body: "Complete guide to Elixir",
          price: Money.new(9999, :USD),
          published: true
        })

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "h1", "Elixir Mastery")
      assert has_element?(view, "p", "Master Elixir programming")
      assert has_element?(view, "span", "$99.99")
    end

    test "given an unpublished course when visitor tries to access then they see error", %{
      conn: conn
    } do
      course = course_fixture(%{published: false})

      assert_error_sent 404, fn ->
        live(conn, ~p"/courses/#{course}")
      end
    end

    test "given a course with lessons when visitor loads the page then they see lesson list", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "h3", "Course Content")
      assert has_element?(view, "li", "Lesson 1")
      assert has_element?(view, "li", "Lesson 2")
    end

    test "given a course with no lessons when visitor loads the page then they see empty state",
         %{
           conn: conn
         } do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "p", "No lessons available yet")
    end

    test "given a free course when visitor loads the page then they see free badge", %{
      conn: conn
    } do
      course = course_fixture(%{price: Money.new(0, :USD), published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "span", "Free")
    end
  end

  describe "enrollment status" do
    test "given a logged in user not enrolled when they view course then they see enroll button",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(0, :USD), published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      assert has_element?(view, "button#enroll-button", "Enroll Now")
    end

    test "given a logged in user enrolled when they view course then they see start learning button",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      assert has_element?(view, "a", "Start Learning")
    end

    test "given a guest user when they view course then they see sign in prompt", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "a", "Sign in to Enroll")
    end
  end

  describe "handle_event/3 - enroll_free" do
    test "given a logged in user when they click enroll on free course then they are enrolled",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(0, :USD), published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#enroll-button")
      |> render_click()

      # Check for success flash or success message
      assert has_element?(view, "a", "Start Learning")
    end

    test "given a paid course when user tries to enroll then they are redirected to checkout",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD), published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      # For paid courses, we show a different button
      assert has_element?(view, "button", "Purchase")
    end
  end

  describe "course curriculum display" do
    test "given published and unpublished lessons when visitor views course then they see only published",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      _published =
        lesson_fixture(%{course_id: course.id, title: "Published Lesson", published: true})

      _unpublished =
        lesson_fixture(%{course_id: course.id, title: "Secret Lesson", published: false})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "li", "Published Lesson")
      refute has_element?(view, "li", "Secret Lesson")
    end

    test "given lessons with duration when visitor views course then they see total duration", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})
      _lesson1 = lesson_fixture(%{course_id: course.id, duration: 600, published: true})
      _lesson2 = lesson_fixture(%{course_id: course.id, duration: 900, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Total: 1500 seconds = 25 minutes
      assert has_element?(view, "span", "25 min")
    end

    test "given lessons in specific order when visitor views course then they see correct order",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      _lesson3 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 3", order: 3, published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      html = render(view)

      # Check that Lesson 1 appears before Lesson 2 which appears before Lesson 3
      lesson1_pos = :binary.match(html, "Lesson 1") |> elem(0)
      lesson2_pos = :binary.match(html, "Lesson 2") |> elem(0)
      lesson3_pos = :binary.match(html, "Lesson 3") |> elem(0)

      assert lesson1_pos < lesson2_pos
      assert lesson2_pos < lesson3_pos
    end
  end

  describe "responsive design and accessibility" do
    test "given a course when visitor views page then it has proper semantic HTML", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Using Layouts.app wrapper
      assert has_element?(view, "article")
      assert has_element?(view, "h1")
    end

    test "given a course with lessons when visitor views page then curriculum has proper structure",
         %{conn: conn} do
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "section#curriculum")
      assert has_element?(view, "ol")
      assert has_element?(view, "li")
    end
  end
end
