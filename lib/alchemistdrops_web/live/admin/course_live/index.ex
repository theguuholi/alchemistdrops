defmodule AlchemistdropsWeb.Admin.CourseLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses

  @impl true
  def mount(_params, _session, socket) do
    courses = list_courses()

    {:ok,
     socket
     |> assign(:page_title, "Manage Courses")
     |> assign(:courses_empty?, courses == [])
     |> stream(:courses, courses)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    course = Courses.get_course!(id)
    {:ok, _} = Courses.delete_course(course)

    {:noreply, stream_delete(socket, :courses, course)}
  end

  defp list_courses do
    Courses.list_all_courses()
  end

  def format_price(nil), do: "Free"

  def format_price(%Money{} = money) do
    if Money.zero?(money) do
      "Free"
    else
      Money.to_string(money)
    end
  end

  def format_price(_), do: "Free"
end
