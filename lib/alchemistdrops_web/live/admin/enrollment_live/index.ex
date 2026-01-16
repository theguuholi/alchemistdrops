defmodule AlchemistdropsWeb.Admin.EnrollmentLive.Index do
  @moduledoc """
  Admin LiveView for viewing enrollments.

  Displays all enrollments with user and course information.
  Mobile-first responsive design with proper accessibility.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Enrollments

  @impl true
  def mount(_params, _session, socket) do
    enrollments = Enrollments.list_enrollments_with_details()

    {:ok,
     socket
     |> assign(:page_title, "Enrollments")
     |> assign(:enrollments_empty?, enrollments == [])
     |> stream(:enrollments, enrollments)}
  end

  defp status_class("active"), do: "badge-success"
  defp status_class("completed"), do: "badge-info"
  defp status_class("cancelled"), do: "badge-error"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
