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

    # Calculate stats
    stats = calculate_stats(courses)

    {:ok,
     socket
     |> assign(:page_title, "Manage Courses")
     |> assign(:courses_empty?, courses == [])
     |> assign(:total_count, stats.total)
     |> assign(:published_count, stats.published)
     |> assign(:draft_count, stats.draft)
     |> assign(:free_count, stats.free)
     |> stream(:courses, courses)}
  end

  defp calculate_stats(courses) do
    Enum.reduce(courses, %{total: 0, published: 0, draft: 0, free: 0}, fn course, acc ->
      acc = Map.update!(acc, :total, &(&1 + 1))

      acc =
        if course.published,
          do: Map.update!(acc, :published, &(&1 + 1)),
          else: Map.update!(acc, :draft, &(&1 + 1))

      if Money.zero?(course.price),
        do: Map.update!(acc, :free, &(&1 + 1)),
        else: acc
    end)
  end
end
