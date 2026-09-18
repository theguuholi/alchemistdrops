defmodule AlchemistdropsWeb.Admin.EnrollmentLiveTest do
  @moduledoc """
  Tests for the admin enrollments LiveView.
  """
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures
  import Phoenix.LiveViewTest

  describe "Index" do
    setup [:register_and_log_in_admin_user]

    test "renders page with correct heading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "h1", "Enrollments")
    end

    test "displays stats", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#admin-enrollments", "Total")
      assert has_element?(view, "#admin-enrollments", "Active")
      assert has_element?(view, "#admin-enrollments", "Completed")
      assert has_element?(view, "#admin-enrollments", "Cancelled")
    end

    test "displays empty state when no enrollments exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#admin-enrollments", "No enrollments yet")
    end

    test "lists all enrollments with user and course data", %{conn: conn} do
      user = user_fixture(%{email: "student@example.com"})
      course = course_fixture(%{title: "Phoenix LiveView"})
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-table")
      assert has_element?(view, "#enrollments-#{enrollment.id}")
      assert has_element?(view, "#enrollments-#{enrollment.id}", "student@example.com")
      assert has_element?(view, "#enrollments-#{enrollment.id}", "Phoenix LiveView")
    end

    test "displays active status badge", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-success", "Active")
    end

    test "displays completed status badge", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()

      enrollment =
        enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "completed"})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-info", "Completed")
    end

    test "displays cancelled status badge", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()

      enrollment =
        enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "cancelled"})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-error", "Cancelled")
    end

    test "handles unknown status with ghost badge", %{conn: conn} do
      import Ecto.Query

      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      # Directly update the database to set an unknown status (bypassing changeset validation)
      from(e in Alchemistdrops.Enrollments.Enrollment, where: e.id == ^enrollment.id)
      |> Alchemistdrops.Repo.update_all(set: [status: "unknown_status"])

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      # Should render with ghost badge for unknown status
      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-ghost")
    end
  end

  describe "Authorization" do
    test "redirects non-admin users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/enrollments")
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/enrollments")
    end
  end
end
