defmodule AlchemistdropsWeb.Admin.CourseLiveTest do
  @moduledoc """
  Tests for the admin courses LiveView.

  Covers:
  - Page rendering and accessibility
  - Course listing with proper data display
  - Empty state handling
  - Authorization (admin-only access)
  """
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures

  describe "Index" do
    setup [:register_and_log_in_admin_user]

    test "renders page with correct heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/courses")

      assert html =~ "Manage Courses"
      assert has_element?(view, "h1#courses-heading", "Manage Courses")
    end

    test "displays empty state when no courses exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "[role=status]", "No courses yet")
    end

    test "lists all courses with correct data", %{conn: conn} do
      course = course_fixture(%{title: "Elixir Basics", published: true})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-table")
      assert has_element?(view, "#courses-#{course.id}")
      assert has_element?(view, "#courses-#{course.id}", "Elixir Basics")
      assert has_element?(view, "#courses-#{course.id} [role=status]", "Published")
    end

    test "displays draft status for unpublished courses", %{conn: conn} do
      course = course_fixture(%{title: "Draft Course", published: false})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id} [role=status]", "Draft")
    end

    test "displays free badge for free courses", %{conn: conn} do
      course = course_fixture(%{title: "Free Course", price: Money.new(0, :USD)})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}", "Free")
    end

    test "displays price for paid courses", %{conn: conn} do
      course = course_fixture(%{title: "Paid Course", price: Money.new(4999, :USD)})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}", "$49.99")
    end

    test "has view link for each course", %{conn: conn} do
      course = course_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(
               view,
               "#courses-#{course.id} a[aria-label='View course: #{course.title}']"
             )
    end

    test "sets correct page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/courses")

      assert html =~ "Manage Courses"
      assert html =~ "Phoenix Framework"
    end
  end

  describe "Authorization" do
    test "redirects non-admin users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/courses")
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/courses")
    end
  end
end
