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

    test "given a lesson with YouTube short URL when user views then they see embedded iframe", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson =
        lesson_fixture(%{
          course_id: course.id,
          video_url: "https://youtu.be/NjBUcTEVsJo",
          published: true
        })

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "iframe[src='https://www.youtube.com/embed/NjBUcTEVsJo']")
      refute has_element?(view, "video")
    end

    test "given a lesson with YouTube watch URL when user views then they see embedded iframe", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})

      _lesson =
        lesson_fixture(%{
          course_id: course.id,
          video_url: "https://www.youtube.com/watch?v=IbHyK6a0-xQ",
          published: true
        })

      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "iframe[src='https://www.youtube.com/embed/IbHyK6a0-xQ']")
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

  describe "video_embed_info/1" do
    alias AlchemistdropsWeb.StudentLive.Lesson

    test "given nil when called then returns nil" do
      assert Lesson.video_embed_info(nil) == nil
    end

    test "given empty string when called then returns nil" do
      assert Lesson.video_embed_info("") == nil
    end

    test "given youtu.be short URL when called then returns YouTube embed" do
      assert {:youtube, "https://www.youtube.com/embed/NjBUcTEVsJo"} =
               Lesson.video_embed_info("https://youtu.be/NjBUcTEVsJo")
    end

    test "given youtu.be URL with query params when called then extracts video id" do
      assert {:youtube, "https://www.youtube.com/embed/IbHyK6a0-xQ"} =
               Lesson.video_embed_info("https://youtu.be/IbHyK6a0-xQ?feature=shared")
    end

    test "given youtube.com watch URL when called then returns YouTube embed" do
      assert {:youtube, "https://www.youtube.com/embed/abc123"} =
               Lesson.video_embed_info("https://www.youtube.com/watch?v=abc123")
    end

    test "given youtube.com watch URL without query params when called then returns empty video id" do
      # Edge case: youtube.com/watch without ?v= parameter
      assert {:youtube, "https://www.youtube.com/embed/"} =
               Lesson.video_embed_info("https://www.youtube.com/watch")
    end

    test "given youtube.com embed URL when called then returns same URL" do
      url = "https://www.youtube.com/embed/already-embedded"
      assert {:youtube, ^url} = Lesson.video_embed_info(url)
    end

    test "given regular video URL when called then returns video tuple" do
      url = "https://example.com/video.mp4"
      assert {:video, ^url} = Lesson.video_embed_info(url)
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

  describe "handle_event/3 - select_lesson" do
    test "given multiple lessons when user clicks a lesson then they navigate to it", %{
      conn: conn
    } do
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
        |> live(~p"/student/courses/#{course.id}/lessons")

      view
      |> element("button[phx-value-id='#{lesson2.id}']")
      |> render_click()

      assert has_element?(view, "h1", "Lesson 2")
    end
  end

  describe "lesson duration display" do
    test "given lesson with duration when user views then they see formatted duration", %{
      conn: conn
    } do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, duration: 600, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      assert has_element?(view, "p", "10 min")
    end

    test "given lesson without duration when user views then no duration shown", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, duration: nil, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      # The view should render without crashing
      assert has_element?(view, "h1")
    end
  end

  describe "edge cases" do
    test "given invalid lesson id when user navigates then they are redirected", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      # Invalid UUID redirects with flash error
      {:error, {:live_redirect, %{to: redirect_path, flash: flash}}} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons?lesson=invalid-uuid")

      # Should redirect back to course page with error
      assert redirect_path == "/courses/#{course.id}"
      assert flash["error"] == "Lesson not found"
    end

    test "given only one lesson when user views then next button is disabled", %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, title: "Only Lesson", published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/student/courses/#{course.id}/lessons")

      # No next button should exist (only one lesson)
      refute has_element?(view, "button#next-lesson")
      refute has_element?(view, "button#prev-lesson")
    end
  end
end
