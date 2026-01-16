defmodule AlchemistdropsWeb.Admin.CourseLive.Index do
  @moduledoc """
  Admin LiveView for managing courses.

  Displays all courses with their status and price information.
  Mobile-first responsive design with proper accessibility.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses

  @impl true
  def mount(_params, _session, socket) do
    courses = Courses.list_all_courses()

    {:ok,
     socket
     |> assign(:page_title, "Manage Courses")
     |> assign(:courses_empty?, courses == [])
     |> stream(:courses, courses)}
  end
end
