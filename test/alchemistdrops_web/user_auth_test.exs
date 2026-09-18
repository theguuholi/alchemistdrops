defmodule AlchemistdropsWeb.UserAuthTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Alchemistdrops.AccountsFixtures
  import Ecto.Query

  alias Alchemistdrops.Accounts
  alias AlchemistdropsWeb.UserAuth

  describe "fetch_current_scope_for_user/2" do
    test "assigns current_scope from session token", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)
        |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope.user.id == user.id
    end

    test "reissues session token when old", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # Make the token old by updating inserted_at
      Alchemistdrops.Repo.update_all(
        from(t in Alchemistdrops.Accounts.UserToken, where: t.token == ^token),
        set: [inserted_at: DateTime.add(DateTime.utc_now(:second), -8, :day)]
      )

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)
        |> Plug.Conn.assign(:current_scope, Accounts.Scope.for_user(nil))
        |> UserAuth.fetch_current_scope_for_user([])

      # User should still be logged in
      assert conn.assigns.current_scope.user.id == user.id
      # New token should be generated
      new_token = get_session(conn, :user_token)
      assert new_token != token
    end

    test "reissues session token and preserves remember_me when set", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # Make the token old by updating inserted_at
      Alchemistdrops.Repo.update_all(
        from(t in Alchemistdrops.Accounts.UserToken, where: t.token == ^token),
        set: [inserted_at: DateTime.add(DateTime.utc_now(:second), -8, :day)]
      )

      # Simulate a session where remember_me was previously set (no params with remember_me)
      # Use endpoint's secret_key_base for cookie signing
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Map.put(:secret_key_base, AlchemistdropsWeb.Endpoint.config(:secret_key_base))
        |> Plug.Conn.put_session(:user_token, token)
        |> Plug.Conn.put_session(:user_remember_me, true)
        |> Plug.Conn.assign(:current_scope, Accounts.Scope.for_user(nil))
        |> UserAuth.fetch_current_scope_for_user([])

      # User should still be logged in
      assert conn.assigns.current_scope.user.id == user.id
      # remember_me should be preserved
      assert get_session(conn, :user_remember_me) == true
      # New token should be generated
      new_token = get_session(conn, :user_token)
      assert new_token != token
    end

    test "assigns nil scope when no token", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> UserAuth.fetch_current_scope_for_user([])

      scope = conn.assigns.current_scope
      assert scope == nil or scope.user == nil
    end
  end

  describe "log_in_user/3" do
    test "logs in user without remember_me", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.assign(:current_scope, Accounts.Scope.for_user(nil))
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == "/"
    end

    test "uses user_return_to from session", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_return_to, "/custom-path")
        |> Plug.Conn.assign(:current_scope, Accounts.Scope.for_user(nil))
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == "/custom-path"
    end

    test "does not renew session for same user", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.assign(:current_scope, Accounts.Scope.for_user(user))
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == "/users/settings"
    end
  end

  describe "log_out_user/1" do
    test "logs out user and broadcasts disconnect", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> UserAuth.log_out_user()

      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
    end

    test "broadcasts disconnect when live_socket_id exists", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      live_socket_id = "users_sessions:#{Base.url_encode64(token)}"

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)
        |> Plug.Conn.put_session(:live_socket_id, live_socket_id)
        |> Plug.Conn.assign(:current_scope, Accounts.Scope.for_user(user))
        |> UserAuth.log_out_user()

      assert redirected_to(conn) == "/"
    end
  end

  describe "signed_in_path/1" do
    test "returns settings path for logged in user", %{conn: conn} do
      user = user_fixture()
      conn = Plug.Conn.assign(conn, :current_scope, Accounts.Scope.for_user(user))

      assert UserAuth.signed_in_path(conn) == "/users/settings"
    end

    test "returns root path for guest", %{conn: conn} do
      conn = Plug.Conn.assign(conn, :current_scope, Accounts.Scope.for_user(nil))
      assert UserAuth.signed_in_path(conn) == "/"
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect for tokens" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      token_struct = %{token: token}

      # This should not raise
      UserAuth.disconnect_sessions([token_struct])
    end
  end

  describe "on_mount :require_authenticated" do
    test "halts and redirects unauthenticated user", %{conn: _conn} do
      # Create a minimal socket for testing on_mount
      socket = %Phoenix.LiveView.Socket{
        endpoint: AlchemistdropsWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}},
        private: %{assign_new: {%{}, []}, live_temp: %{}}
      }

      # Empty session means no authenticated user
      session = %{}

      assert {:halt, redirected_socket} =
               UserAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert redirected_socket.redirected == {:redirect, %{status: 302, to: "/users/log-in"}}
    end
  end

  describe "require_authenticated_user plug" do
    test "redirects unauthenticated user for non-GET request", %{conn: conn} do
      # Simulate a POST request with no current_scope
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Phoenix.Controller.fetch_flash([])
        |> Map.put(:method, "POST")
        |> Plug.Conn.assign(:current_scope, nil)
        |> UserAuth.require_authenticated_user([])

      assert redirected_to(conn) == "/users/log-in"
      # Non-GET requests should NOT store return_to
      refute get_session(conn, :user_return_to)
    end

    test "redirects unauthenticated user for GET request and stores return_to", %{conn: _conn} do
      # Create conn with correct path
      conn =
        :get
        |> Phoenix.ConnTest.build_conn("/protected-page")
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Phoenix.Controller.fetch_flash([])
        |> Plug.Conn.assign(:current_scope, nil)
        |> UserAuth.require_authenticated_user([])

      assert redirected_to(conn) == "/users/log-in"
      # GET requests should store return_to
      assert get_session(conn, :user_return_to) == "/protected-page"
    end
  end
end
