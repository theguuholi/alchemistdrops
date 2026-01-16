defmodule AlchemistdropsWeb.Admin.EnrollmentLiveTest do
  @moduledoc """
  Tests for the admin enrollments LiveView.

  Covers:
  - Page rendering and accessibility
  - Enrollment listing with user and course data
  - Status display with proper styling
  - Empty state handling
  - Authorization (admin-only access)
  """
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.EnrollmentsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.AccountsFixtures

  describe "Index" do
    setup [:register_and_log_in_admin_user]

    test "renders page with correct heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Enrollments"
      assert has_element?(view, "h1#enrollments-heading", "Enrollments")
    end

    test "displays empty state when no enrollments exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "[role=status]", "No enrollments yet")
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

    test "displays active status with success styling", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-success", "active")
    end

    test "displays completed status with info styling", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()

      enrollment =
        enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "completed"})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-info", "completed")
    end

    test "displays cancelled status with error styling", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()

      enrollment =
        enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "cancelled"})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id} .badge-error", "cancelled")
    end

    test "displays enrollment date", %{conn: conn} do
      user = user_fixture()
      course = course_fixture()
      enrollment = enrollment_fixture(%{user_id: user.id, course_id: course.id})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      # Check that a time element exists with datetime attribute
      assert has_element?(view, "#enrollments-#{enrollment.id} time[datetime]")
    end

    test "sets correct page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Enrollments"
      assert html =~ "Phoenix Framework"
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
