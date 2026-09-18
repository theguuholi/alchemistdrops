defmodule AlchemistdropsWeb.UserLive.LoginTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Alchemistdrops.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, "#login-page h1", "Log in")
      assert has_element?(view, "#login-page a", "Sign up")
      assert has_element?(view, "#login_form_magic button", "Log in with email")
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, login_view, _html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_view, "#flash-info", "If your email is in our system")

      assert Alchemistdrops.Repo.get_by!(Alchemistdrops.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, login_view, _html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert has_element?(login_view, "#flash-info", "If your email is in our system")
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{email: user.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password", user: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, registration_live, _html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert has_element?(registration_live, "#registration-page h1", "Register")
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, "#login-page", "You need to reauthenticate")
      refute has_element?(view, "#login-page a", "Sign up")
      assert has_element?(view, "#login_form_magic button", "Log in with email")
      assert has_element?(view, "#login_form_magic_email[value='#{user.email}']")
    end
  end

  describe "magic link for non-existent user" do
    test "shows same message but no token created", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, login_view, _html} =
        form(lv, "#login_form_magic", user: %{email: "nonexistent@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      # Same message to prevent email enumeration
      assert has_element?(login_view, "#flash-info", "If your email is in our system")

      # No token should be created for non-existent user
      assert Alchemistdrops.Repo.all(Alchemistdrops.Accounts.UserToken) == []
    end
  end

  describe "local mail adapter info box" do
    test "shows mailbox link when using local adapter", %{conn: conn} do
      # Temporarily set the local adapter
      original_config = Application.get_env(:alchemistdrops, Alchemistdrops.Mailer)
      Application.put_env(:alchemistdrops, Alchemistdrops.Mailer, adapter: Swoosh.Adapters.Local)

      try do
        {:ok, view, _html} = live(conn, ~p"/users/log-in")
        assert has_element?(view, "#local-mail-notice", "local mail adapter")
        assert has_element?(view, "#local-mail-notice a[href='/dev/mailbox']")
      after
        Application.put_env(:alchemistdrops, Alchemistdrops.Mailer, original_config)
      end
    end
  end
end
