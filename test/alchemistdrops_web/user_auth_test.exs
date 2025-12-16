defmodule AlchemistdropsWeb.UserAuthTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Ecto.Query
  import Alchemistdrops.AccountsFixtures

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
end
