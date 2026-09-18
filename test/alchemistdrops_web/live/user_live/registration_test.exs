defmodule AlchemistdropsWeb.UserLive.RegistrationTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Alchemistdrops.AccountsFixtures

  describe "mount/3" do
    test "renders registration page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      assert has_element?(view, "#registration-page h1", "Register")
      assert has_element?(view, "#registration-page a", "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> element("#registration_form")
      |> render_change(user: %{"email" => "with spaces"})

      assert has_element?(lv, "#registration-page h1", "Register")
      assert has_element?(lv, "#user_email-error-0", "must have the @ sign")
    end
  end

  describe "handle_event/3 - save" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      {:ok, login_view, _html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_view, "#flash-info", "An email was sent to #{email}")
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      lv
      |> form("#registration_form", user: %{"email" => user.email})
      |> render_submit()

      assert has_element?(lv, "#user_email-error-0", "has already been taken")
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, login_live, _html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_live, "#login-page h1", "Log in")
    end
  end
end
