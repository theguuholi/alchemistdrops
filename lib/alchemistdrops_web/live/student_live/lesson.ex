defmodule AlchemistdropsWeb.StudentLive.Lesson do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Enrollments

  @impl true
  def mount(%{"course_id" => course_id}, _session, socket) do
    current_user =
      case socket.assigns do
        %{current_scope: %{user: user}} -> user
        _ -> nil
      end

    if current_user && Enrollments.user_enrolled?(current_user.id, course_id) do
      course = Courses.get_course!(course_id)
      lessons = Courses.list_course_lessons(course_id, only_published: true)

      {:ok,
       socket
       |> assign(:course, course)
       |> assign(:lessons, lessons)
       |> assign(:current_user, current_user)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be enrolled in this course to view lessons.")
       |> redirect(to: ~p"/courses/#{course_id}")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    lesson_id = params["lesson"]
    lessons = socket.assigns.lessons

    current_lesson =
      if lesson_id do
        Enum.find(lessons, &(&1.id == lesson_id))
      else
        List.first(lessons)
      end

    if current_lesson do
      {:noreply,
       socket
       |> assign(:current_lesson, current_lesson)
       |> assign(:page_title, current_lesson.title)
       |> assign_navigation_state()}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Lesson not found")
       |> push_navigate(to: ~p"/courses/#{socket.assigns.course.id}")}
    end
  end

  @impl true
  def handle_event("select_lesson", %{"id" => lesson_id}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/student/courses/#{socket.assigns.course.id}/lessons?lesson=#{lesson_id}"
     )}
  end

  def handle_event("next_lesson", _params, socket) do
    next_lesson = find_next_lesson(socket.assigns.lessons, socket.assigns.current_lesson)

    if next_lesson do
      {:noreply,
       push_patch(socket,
         to: ~p"/student/courses/#{socket.assigns.course.id}/lessons?lesson=#{next_lesson.id}"
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("prev_lesson", _params, socket) do
    prev_lesson = find_prev_lesson(socket.assigns.lessons, socket.assigns.current_lesson)

    if prev_lesson do
      {:noreply,
       push_patch(socket,
         to: ~p"/student/courses/#{socket.assigns.course.id}/lessons?lesson=#{prev_lesson.id}"
       )}
    else
      {:noreply, socket}
    end
  end

  defp assign_navigation_state(socket) do
    current_lesson = socket.assigns.current_lesson
    lessons = socket.assigns.lessons

    has_next = find_next_lesson(lessons, current_lesson) != nil
    has_prev = find_prev_lesson(lessons, current_lesson) != nil

    socket
    |> assign(:has_next, has_next)
    |> assign(:has_prev, has_prev)
  end

  defp find_next_lesson(lessons, current_lesson) do
    current_index = Enum.find_index(lessons, &(&1.id == current_lesson.id))

    if current_index && current_index < length(lessons) - 1 do
      Enum.at(lessons, current_index + 1)
    else
      nil
    end
  end

  defp find_prev_lesson(lessons, current_lesson) do
    current_index = Enum.find_index(lessons, &(&1.id == current_lesson.id))

    if current_index && current_index > 0 do
      Enum.at(lessons, current_index - 1)
    else
      nil
    end
  end

  defp format_duration(nil), do: ""

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end

  @doc """
  Converts a YouTube URL to an embed URL if applicable.
  Returns {:youtube, embed_url} for YouTube videos or {:video, url} for others.
  """
  def video_embed_info(nil), do: nil

  def video_embed_info(url) when is_binary(url) do
    cond do
      # youtu.be short URL format
      String.contains?(url, "youtu.be/") ->
        video_id = url |> String.split("youtu.be/") |> List.last() |> String.split("?") |> hd()
        {:youtube, "https://www.youtube.com/embed/#{video_id}"}

      # youtube.com/watch?v= format
      String.contains?(url, "youtube.com/watch") ->
        video_id = extract_youtube_video_id(url)
        {:youtube, "https://www.youtube.com/embed/#{video_id}"}

      # youtube.com/embed/ format (already embedded)
      String.contains?(url, "youtube.com/embed/") ->
        {:youtube, url}

      # Regular video file
      true ->
        {:video, url}
    end
  end

  defp extract_youtube_video_id(url) do
    uri = URI.parse(url)

    case uri.query do
      nil -> ""
      query -> URI.decode_query(query) |> Map.get("v", "")
    end
  end
end
