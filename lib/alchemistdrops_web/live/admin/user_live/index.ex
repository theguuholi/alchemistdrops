defmodule AlchemistdropsWeb.Admin.UserLive.Index do
  @moduledoc """
  Admin LiveView for managing users.

  Displays all users with their roles and registration dates.
  Mobile-first responsive design with proper accessibility.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Accounts

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:users_empty?, users == [])
     |> stream(:users, users)}
  end

  @impl true
  def handle_event("make_admin", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, updated_user} = Accounts.update_user_role(user, :admin)

    {:noreply,
     socket
     |> stream_insert(:users, updated_user)
     |> put_flash(:info, "User #{user.email} is now an admin")}
  end

  def handle_event("remove_admin", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, updated_user} = Accounts.update_user_role(user, :user)

    {:noreply,
     socket
     |> stream_insert(:users, updated_user)
     |> put_flash(:info, "Admin role removed from #{user.email}")}
  end

  defp role_class(:admin), do: "badge-warning"
  defp role_class(:user), do: "badge-info"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
