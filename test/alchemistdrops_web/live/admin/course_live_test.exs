defmodule AlchemistdropsWeb.Admin.CourseLiveTest do
  @moduledoc """
  Tests for the admin courses LiveView.
  """
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures

  describe "Index" do
    setup [:register_and_log_in_admin_user]

    test "renders page with correct heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/courses")

      assert html =~ "Courses"
      assert has_element?(view, "h1", "Courses")
    end

    test "displays stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/courses")

      assert html =~ "Total"
      assert html =~ "Published"
      assert html =~ "Drafts"
      assert html =~ "Free"
    end

    test "displays empty state when no courses exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/courses")

      assert html =~ "No courses yet"
    end

    test "lists all courses with correct data", %{conn: conn} do
      course = course_fixture(%{title: "Phoenix LiveView Course", published: true})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}")
      assert has_element?(view, "#courses-#{course.id}", "Phoenix LiveView Course")
    end

    test "displays published badge for published courses", %{conn: conn} do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id} .badge-success", "Published")
    end

    test "displays draft badge for unpublished courses", %{conn: conn} do
      course = course_fixture(%{published: false})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id} .badge-warning", "Draft")
    end

    test "displays Free label for free courses", %{conn: conn} do
      course = course_fixture(%{price: Money.new(0, :USD)})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}", "Free")
    end

    test "displays price for paid courses", %{conn: conn} do
      course = course_fixture(%{price: Money.new(4999, :USD)})

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id}", "$49.99")
    end

    test "has view link for each course", %{conn: conn} do
      course = course_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/courses")

      assert has_element?(view, "#courses-#{course.id} a", "View")
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
