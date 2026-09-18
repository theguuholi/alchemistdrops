defmodule AlchemistdropsWeb.Admin.UserLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Accounts

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    # Calculate stats
    stats = calculate_stats(users)

    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:users_empty?, users == [])
     |> assign(:total_count, stats.total)
     |> assign(:admin_count, stats.admin)
     |> assign(:confirmed_count, stats.confirmed)
     |> assign(:pending_count, stats.pending)
     |> stream(:users, users)}
  end

  @impl true
  def handle_event("make_admin", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, updated_user} = Accounts.update_user_role(user, :admin)

    {:noreply,
     socket
     |> update_stats_on_role_change(:user, :admin)
     |> stream_insert(:users, updated_user)
     |> put_flash(:info, "User #{user.email} is now an admin")}
  end

  def handle_event("remove_admin", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, updated_user} = Accounts.update_user_role(user, :user)

    {:noreply,
     socket
     |> update_stats_on_role_change(:admin, :user)
     |> stream_insert(:users, updated_user)
     |> put_flash(:info, "Admin role removed from #{user.email}")}
  end

  defp calculate_stats(users) do
    Enum.reduce(users, %{total: 0, admin: 0, confirmed: 0, pending: 0}, fn user, acc ->
      acc = Map.update!(acc, :total, &(&1 + 1))

      acc =
        if user.role == :admin,
          do: Map.update!(acc, :admin, &(&1 + 1)),
          else: acc

      if user.confirmed_at,
        do: Map.update!(acc, :confirmed, &(&1 + 1)),
        else: Map.update!(acc, :pending, &(&1 + 1))
    end)
  end

  defp update_stats_on_role_change(socket, :user, :admin) do
    socket
    |> update(:admin_count, &(&1 + 1))
  end

  defp update_stats_on_role_change(socket, :admin, :user) do
    socket
    |> update(:admin_count, &(&1 - 1))
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp role_badge_class(:admin), do: "badge-warning"
  defp role_badge_class(:student), do: "badge-info"
  defp role_badge_class(:user), do: "badge-ghost"
end
