defmodule AlchemistdropsWeb.Admin.CourseLive.Index do
  @moduledoc """
  Admin LiveView for managing courses.

  Displays all courses with their status and price information.
  Mobile-first responsive design with proper accessibility.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Money

  @impl true
  def mount(_params, _session, socket) do
    courses = Courses.list_all_courses()

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

  defp price_free?(nil), do: true
  defp price_free?(%Money{amount: 0}), do: true
  defp price_free?(_), do: false

  defp format_price(nil), do: "Free"
  defp format_price(%Money{amount: 0}), do: "Free"
  defp format_price(price), do: Money.to_string(price)
end
