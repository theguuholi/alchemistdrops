defmodule AlchemistdropsWeb.CourseLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Enrollments

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Courses.get_course!(id)

    if course.published do
      {:ok,
       socket
       |> assign(:course, course)
       |> assign_enrollment_status()
       |> load_lessons()}
    else
      raise Ecto.NoResultsError, queryable: Alchemistdrops.Courses.Course
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, socket.assigns.course.title)}
  end

  @impl true
  def handle_event("enroll_free", _params, socket) do
    current_user = socket.assigns.current_scope.user
    course = socket.assigns.course

    case Enrollments.enroll_user(current_user.id, course.id) do
      {:ok, _enrollment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully enrolled!")
         |> assign(:enrolled, true)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to enroll. Please try again.")}
    end
  end

  defp assign_enrollment_status(socket) do
    current_user =
      case socket.assigns do
        %{current_scope: %{user: user}} -> user
        _ -> nil
      end

    course = socket.assigns.course

    enrolled =
      if current_user do
        Enrollments.user_enrolled?(current_user.id, course.id)
      else
        false
      end

    assign(socket, :enrolled, enrolled)
  end

  defp load_lessons(socket) do
    course = socket.assigns.course
    lessons = Courses.list_course_lessons(course.id, only_published: true)

    socket
    |> assign(:lessons, lessons)
    |> assign(:total_duration, calculate_total_duration(lessons))
  end

  defp calculate_total_duration(lessons) do
    lessons
    |> Enum.map(& &1.duration)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.sum()
    |> seconds_to_minutes()
  end

  defp seconds_to_minutes(seconds) when is_integer(seconds) do
    div(seconds, 60)
  end

  defp seconds_to_minutes(_), do: 0

  defp format_price(%Money{amount: 0}), do: "Free"
  defp format_price(price), do: Money.to_string(price)

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end

  defp format_duration(_), do: ""
end
