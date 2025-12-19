defmodule AlchemistdropsWeb.Admin.EnrollmentLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures
  import Alchemistdrops.AccountsFixtures

  defp create_enrollment(_) do
    user = user_fixture()
    course = published_course_fixture()
    enrollment = enrollment_fixture(%{user: user, course: course})
    %{user: user, course: course, enrollment: enrollment}
  end

  describe "Index" do
    setup [:register_and_log_in_admin_user, :create_enrollment]

    test "given admin user, when visiting enrollments index, then lists all enrollments", %{
      conn: conn,
      enrollment: enrollment,
      user: user
    } do
      {:ok, view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Manage Enrollments"
      assert has_element?(view, "#enrollments-#{enrollment.id}")
      assert html =~ user.email
    end

    test "given enrollment exists, when viewing index, then displays status badge", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Active"
    end

    test "given enrollments exist, when viewing index, then displays stats summary", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Total"
      assert html =~ "Active"
      assert html =~ "Completed"
      assert html =~ "Cancelled"
    end

    test "given no enrollments exist, when visiting index, then shows empty state", %{
      conn: conn,
      enrollment: enrollment,
      course: course
    } do
      Alchemistdrops.Repo.delete(enrollment)
      Alchemistdrops.Courses.delete_course(course)

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "No enrollments found"
    end
  end

  describe "Enrollment actions" do
    setup [:register_and_log_in_admin_user, :create_enrollment]

    test "given active enrollment, when clicking complete, then marks enrollment as completed", %{
      conn: conn,
      enrollment: enrollment
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      view
      |> element("#enrollments button[phx-click='complete'][phx-value-id='#{enrollment.id}']")
      |> render_click()

      updated = Alchemistdrops.Enrollments.get_enrollment!(enrollment.id)
      assert updated.status == "completed"
      assert updated.completed_at != nil
    end

    test "given active enrollment, when clicking cancel, then marks enrollment as cancelled", %{
      conn: conn,
      enrollment: enrollment
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      view
      |> element("#enrollments button[phx-click='cancel'][phx-value-id='#{enrollment.id}']")
      |> render_click()

      updated = Alchemistdrops.Enrollments.get_enrollment!(enrollment.id)
      assert updated.status == "cancelled"
    end

    test "given cancelled enrollment, when clicking reactivate, then marks enrollment as active",
         %{
           conn: conn
         } do
      user = user_fixture()
      course = published_course_fixture()
      enrollment = cancelled_enrollment_fixture(%{user: user, course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      view
      |> element("#enrollments button[phx-click='reactivate'][phx-value-id='#{enrollment.id}']")
      |> render_click()

      updated = Alchemistdrops.Enrollments.get_enrollment!(enrollment.id)
      assert updated.status == "active"
      assert updated.completed_at == nil
    end

    test "given enrollment completed, when viewing index, then stats are updated", %{
      conn: conn,
      enrollment: enrollment
    } do
      {:ok, view, html_before} = live(conn, ~p"/admin/enrollments")

      assert html_before =~ "Active"

      view
      |> element("#enrollments button[phx-click='complete'][phx-value-id='#{enrollment.id}']")
      |> render_click()

      html_after = render(view)
      assert html_after =~ "Completed"
    end
  end

  describe "Index access control" do
    setup [:create_enrollment]

    test "given unauthenticated user, when visiting enrollments index, then redirects", %{
      conn: conn
    } do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/enrollments")
    end

    test "given non-admin user, when visiting enrollments index, then redirects", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/enrollments")
    end
  end

  describe "Mobile view" do
    setup [:register_and_log_in_admin_user, :create_enrollment]

    test "given mobile view, when rendering enrollments, then includes mobile card elements", %{
      conn: conn,
      enrollment: enrollment
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      assert has_element?(view, "#enrollments-#{enrollment.id}-mobile")
    end

    test "given mobile view, when rendering enrollments, then shows action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Complete"
      assert html =~ "Cancel"
    end
  end
end
