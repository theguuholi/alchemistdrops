defmodule AlchemistdropsWeb.UserLive.ConfirmationTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Alchemistdrops.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Alchemistdrops.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), confirmed_user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, view, _html} = live(conn, ~p"/users/log-in/#{token}")
      assert has_element?(view, "#confirmation_form button", "Confirm and stay logged in")
    end

    test "renders login page for confirmed user", %{conn: conn, confirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, view, _html} = live(conn, ~p"/users/log-in/#{token}")
      refute has_element?(view, "#confirmation_form")
      assert has_element?(view, "#login_form", "Log")
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User confirmed successfully"

      assert Accounts.get_user!(user.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, login_view, _html} =
        conn
        |> live(~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_view, "#flash-error", "Magic link is invalid or it has expired")
    end

    test "logs confirmed user in without changing confirmed_at", %{
      conn: conn,
      confirmed_user: user
    } do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#login_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Accounts.get_user!(user.id).confirmed_at == user.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, login_view, _html} =
        conn
        |> live(~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_view, "#flash-error", "Magic link is invalid or it has expired")
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, login_view, _html} =
        conn
        |> live(~p"/users/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_view, "#flash-error", "Magic link is invalid or it has expired")
    end

    test "renders log in button when user is already logged in", %{
      conn: conn,
      confirmed_user: user
    } do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/log-in/#{token}")

      # When already logged in, shows simple "Log in" button instead of "Keep me logged in"
      assert has_element?(view, "#login_form button", "Log in")
      refute has_element?(view, "#login_form", "Keep me logged in")
    end
  end
end
