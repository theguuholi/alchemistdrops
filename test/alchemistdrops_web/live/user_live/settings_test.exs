defmodule AlchemistdropsWeb.UserLive.SettingsTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Alchemistdrops.AccountsFixtures
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "given an authenticated user, when the page loads, then it renders both settings forms",
         %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert has_element?(view, "#email_form button", "Change Email")
      assert has_element?(view, "#password_form button", "Save Password")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/settings")
        |> follow_redirect(conn, ~p"/users/log-in")

      document = LazyHTML.from_document(conn.resp_body)
      assert LazyHTML.text(LazyHTML.query(document, "#flash-error")) =~ "You must re-authenticate"
    end
  end

  describe "handle_event/3 - validate_email and update_email" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> form("#email_form", %{"user" => %{"email" => new_email}})
      |> render_submit()

      assert has_element?(lv, "#flash-info", "A link to confirm your email")
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> element("#email_form")
      |> render_change(%{
        "action" => "update_email",
        "user" => %{"email" => "with spaces"}
      })

      assert has_element?(lv, "#email_form button", "Change Email")
      assert has_element?(lv, "#user_email-error-0", "must have the @ sign and no spaces")
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> form("#email_form", %{"user" => %{"email" => user.email}})
      |> render_submit()

      assert has_element?(lv, "#email_form button", "Change Email")
      assert has_element?(lv, "#user_email-error-0", "did not change")
    end
  end

  describe "handle_event/3 - validate_password and update_password" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user password", %{conn: conn, user: user} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> element("#password_form")
      |> render_change(%{
        "user" => %{
          "password" => "too short",
          "password_confirmation" => "does not match"
        }
      })

      assert has_element?(lv, "#password_form button", "Save Password")
      assert has_element?(lv, "[id^='user_password-error-']", "should be at least 12")

      assert has_element?(
               lv,
               "#user_password_confirmation-error-0",
               "does not match password"
             )
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> form("#password_form", %{
        "user" => %{
          "password" => "too short",
          "password_confirmation" => "does not match"
        }
      })
      |> render_submit()

      assert has_element?(lv, "#password_form button", "Save Password")
      assert has_element?(lv, "[id^='user_password-error-']", "should be at least 12")

      assert has_element?(
               lv,
               "#user_password_confirmation-error-0",
               "does not match password"
             )
    end
  end

  describe "mount/3 - confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token = update_email_token_fixture(user, email)

      %{conn: log_in_user(conn, user), token: token}
    end

    test "updates the user email once", %{conn: conn, token: token} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
