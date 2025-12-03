defmodule AlchemistdropsWeb.StudentLive.LessonTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures

  describe "mount/3" do
    test "given an enrolled user when they visit lesson page then they see lesson content", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson =
        lesson_fixture(%{
          course_id: course.id,
          title: "Introduction to Elixir",
          content: "Welcome to Elixir programming",
          published: true
        })

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "h1", "Introduction to Elixir")
      assert has_element?(view, "div", "Welcome to Elixir programming")
    end

    test "given a non-enrolled user when they try to access lessons then they are redirected", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})

      assert {:error, {:redirect, %{to: redirect_path}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/student/courses/#{course.id}/lessons")

      assert redirect_path == "/courses/#{course.id}"
    end

    test "given a guest user when they try to access lessons then they need to login", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/student/courses/#{course.id}/lessons")
    end

    test "given an enrolled user with multiple lessons when they visit then they see lesson navigation",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "nav")
      assert has_element?(view, "button", "Lesson 1")
      assert has_element?(view, "button", "Lesson 2")
    end
  end

  describe "handle_params/3 - lesson selection" do
    test "given a specific lesson id when user navigates then they see that lesson", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      lesson2 =
        lesson_fixture(%{
          course_id: course.id,
          title: "Lesson 2",
          content: "Second lesson content",
          order: 2,
          published: true
        })

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons?lesson=#{lesson2.id}")

      assert has_element?(view, "h1", "Lesson 2")
      assert has_element?(view, "div", "Second lesson content")
    end

    test "given no lesson param when user visits then they see first lesson", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "First Lesson", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Second Lesson", order: 2, published: true})

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "h1", "First Lesson")
    end
  end

  describe "handle_event/3 - next_lesson" do
    test "given current lesson when user clicks next then they see next lesson", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      view
      |> element("button#next-lesson")
      |> render_click()

      assert has_element?(view, "h1", "Lesson 2")
    end

    test "given last lesson when user clicks next then button is disabled", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})

      lesson =
        lesson_fixture(%{course_id: course.id, title: "Last Lesson", order: 1, published: true})

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons?lesson=#{lesson.id}")

      refute has_element?(view, "button#next-lesson")
    end
  end

  describe "handle_event/3 - prev_lesson" do
    test "given second lesson when user clicks prev then they see first lesson", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons?lesson=#{lesson2.id}")

      view
      |> element("button#prev-lesson")
      |> render_click()

      assert has_element?(view, "h1", "Lesson 1")
    end

    test "given first lesson when viewing then prev button is disabled", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson =
        lesson_fixture(%{course_id: course.id, title: "First Lesson", order: 1, published: true})

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      refute has_element?(view, "button#prev-lesson")
    end
  end

  describe "lesson video display" do
    test "given a lesson with video url when user views then they see video player", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson =
        lesson_fixture(%{
          course_id: course.id,
          video_url: "https://example.com/video.mp4",
          published: true
        })

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "video")
    end

    test "given a lesson without video when user views then they see content only", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, video_url: nil, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      refute has_element?(view, "video")
    end
  end

  describe "responsive design and accessibility" do
    test "given lesson page when user views then it has proper semantic HTML", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "main[role=main]")
      assert has_element?(view, "nav")
      assert has_element?(view, "article")
    end
  end
end
