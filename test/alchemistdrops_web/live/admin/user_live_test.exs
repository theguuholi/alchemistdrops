defmodule AlchemistdropsWeb.Admin.UserLiveTest do
  @moduledoc """
  Tests for the admin users LiveView.
  """
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.AccountsFixtures

  describe "Index" do
    setup [:register_and_log_in_admin_user]

    test "renders page with correct heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Users"
      assert has_element?(view, "h1", "Users")
    end

    test "displays stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Total"
      assert html =~ "Admins"
      assert html =~ "Confirmed"
      assert html =~ "Pending"
    end

    test "lists all users with correct data", %{conn: conn, user: admin_user} do
      regular_user = user_fixture(%{email: "regular@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-table")
      assert has_element?(view, "#users-#{admin_user.id}")
      assert has_element?(view, "#users-#{admin_user.id}", admin_user.email)
      assert has_element?(view, "#users-#{regular_user.id}")
      assert has_element?(view, "#users-#{regular_user.id}", "regular@example.com")
    end

    test "displays admin role badge for admin users", %{conn: conn, user: admin_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{admin_user.id} .badge-warning", "Admin")
    end

    test "displays user role badge for regular users", %{conn: conn} do
      regular_user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{regular_user.id} .badge-ghost", "User")
    end

    test "displays student role badge for student users", %{conn: conn} do
      student_user = user_fixture(%{role: :student})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{student_user.id} .badge-info", "Student")
    end

    test "displays confirmed status badge for confirmed users", %{conn: conn, user: admin_user} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{admin_user.id} .badge-success", "Confirmed")
    end

    test "displays pending status badge for unconfirmed users", %{conn: conn} do
      unconfirmed_user = user_fixture(%{confirmed_at: nil})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{unconfirmed_user.id} .badge-ghost", "Pending")
    end
  end

  describe "Role Management" do
    setup [:register_and_log_in_admin_user]

    test "can make a regular user an admin", %{conn: conn} do
      regular_user = user_fixture(%{email: "promote@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("#users-#{regular_user.id} button", "Make Admin")
      |> render_click()

      assert render(view) =~ "is now an admin"
      assert has_element?(view, "#users-#{regular_user.id} .badge-warning", "Admin")
    end

    test "can remove admin role from a user", %{conn: conn} do
      admin_to_demote = user_fixture(%{email: "demote@example.com", role: :admin})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("#users-#{admin_to_demote.id} button", "Remove Admin")
      |> render_click()

      assert render(view) =~ "Admin role removed"
      assert has_element?(view, "#users-#{admin_to_demote.id} .badge-ghost", "User")
    end

    test "shows 'Make Admin' button for regular users", %{conn: conn} do
      regular_user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{regular_user.id} button", "Make Admin")
      refute has_element?(view, "#users-#{regular_user.id} button", "Remove Admin")
    end

    test "shows 'Remove Admin' button for admin users", %{conn: conn} do
      other_admin = user_fixture(%{role: :admin})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{other_admin.id} button", "Remove Admin")
      refute has_element?(view, "#users-#{other_admin.id} button", "Make Admin")
    end
  end

  describe "Authorization" do
    test "redirects non-admin users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/users")
    end
  end
end
