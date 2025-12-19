defmodule AlchemistdropsWeb.Admin.EnrollmentLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Enrollments
  alias Alchemistdrops.Enrollments.Enrollment
  alias Alchemistdrops.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    enrollments = list_enrollments()
    stats = calculate_stats()

    {:ok,
     socket
     |> assign(:page_title, "Manage Enrollments")
     |> assign(:stats, stats)
     |> assign(:enrollments_empty?, enrollments == [])
     |> stream(:enrollments, enrollments)}
  end

  @impl true
  def handle_event("complete", %{"id" => id}, socket) do
    enrollment = Enrollments.get_enrollment!(id)
    {:ok, updated} = Enrollments.complete_enrollment(enrollment)
    updated = Repo.preload(updated, [:user, :course])

    {:noreply,
     socket
     |> assign(:stats, calculate_stats())
     |> stream_insert(:enrollments, updated)}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    enrollment = Enrollments.get_enrollment!(id)
    {:ok, updated} = Enrollments.cancel_enrollment(enrollment)
    updated = Repo.preload(updated, [:user, :course])

    {:noreply,
     socket
     |> assign(:stats, calculate_stats())
     |> stream_insert(:enrollments, updated)}
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    enrollment = Enrollments.get_enrollment!(id)

    {:ok, updated} =
      enrollment
      |> Enrollment.changeset(%{status: "active", completed_at: nil})
      |> Repo.update()

    updated = Repo.preload(updated, [:user, :course])

    {:noreply,
     socket
     |> assign(:stats, calculate_stats())
     |> stream_insert(:enrollments, updated)}
  end

  defp list_enrollments do
    Enrollment
    |> join(:inner, [e], u in assoc(e, :user))
    |> join(:inner, [e], c in assoc(e, :course))
    |> preload([e, u, c], user: u, course: c)
    |> order_by([e], desc: e.enrolled_at)
    |> Repo.all()
  end

  defp calculate_stats do
    total = Repo.aggregate(Enrollment, :count)

    active =
      Enrollment
      |> where([e], e.status == "active")
      |> Repo.aggregate(:count)

    completed =
      Enrollment
      |> where([e], e.status == "completed")
      |> Repo.aggregate(:count)

    cancelled =
      Enrollment
      |> where([e], e.status == "cancelled")
      |> Repo.aggregate(:count)

    %{
      total: total,
      active: active,
      completed: completed,
      cancelled: cancelled
    }
  end

  def format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
