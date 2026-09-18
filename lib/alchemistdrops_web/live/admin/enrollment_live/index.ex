defmodule AlchemistdropsWeb.Admin.EnrollmentLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Enrollments

  @impl true
  def mount(_params, _session, socket) do
    enrollments = Enrollments.list_enrollments_with_details()

    # Calculate stats
    stats = calculate_stats(enrollments)

    {:ok,
     socket
     |> assign(:page_title, "Enrollments")
     |> assign(:enrollments_empty?, enrollments == [])
     |> assign(:total_count, stats.total)
     |> assign(:active_count, stats.active)
     |> assign(:completed_count, stats.completed)
     |> assign(:cancelled_count, stats.cancelled)
     |> stream(:enrollments, enrollments)}
  end

  defp calculate_stats(enrollments) do
    Enum.reduce(enrollments, %{total: 0, active: 0, completed: 0, cancelled: 0}, fn enrollment,
                                                                                    acc ->
      acc = Map.update!(acc, :total, &(&1 + 1))

      case enrollment.status do
        "active" -> Map.update!(acc, :active, &(&1 + 1))
        "completed" -> Map.update!(acc, :completed, &(&1 + 1))
        "cancelled" -> Map.update!(acc, :cancelled, &(&1 + 1))
        _ -> acc
      end
    end)
  end

  defp status_badge_class("active"), do: "badge-success"
  defp status_badge_class("completed"), do: "badge-info"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
