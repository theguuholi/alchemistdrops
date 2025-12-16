defmodule AlchemistdropsWeb.CourseLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Enrollments

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Explore Our Courses")
     |> load_courses()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Explore Our Courses")
  end

  defp load_courses(socket) do
    current_user =
      case socket.assigns do
        %{current_scope: %{user: user}} -> user
        _ -> nil
      end

    courses =
      Courses.list_published_courses()
      |> Enum.take(20)
      |> maybe_load_enrollment_status(current_user)

    assign(socket, :courses, courses)
  end

  defp maybe_load_enrollment_status(courses, nil),
    do: Enum.map(courses, &Map.put(&1, :enrolled, false))

  defp maybe_load_enrollment_status(courses, user) do
    Enum.map(courses, fn course ->
      enrolled = Enrollments.user_enrolled?(user.id, course.id)
      Map.put(course, :enrolled, enrolled)
    end)
  end

  defp format_price(%Money{amount: 0}), do: "Free"
  defp format_price(price), do: Money.to_string(price)
end
