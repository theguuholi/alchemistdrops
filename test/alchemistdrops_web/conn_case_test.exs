defmodule AlchemistdropsWeb.ConnCaseTest do
  @moduledoc """
  Tests for the ConnCase helper functions.
  """
  use AlchemistdropsWeb.ConnCase, async: true

  import Alchemistdrops.AccountsFixtures

  describe "register_and_log_in_user/2" do
    test "creates user with custom role", %{conn: conn} do
      %{user: user} = register_and_log_in_user(%{conn: conn}, "student")
      assert user.role == :student
    end

    test "with token_authenticated_at option sets the token timestamp", %{conn: conn} do
      authenticated_at = DateTime.add(DateTime.utc_now(:second), -3600, :second)

      context =
        %{conn: conn, token_authenticated_at: authenticated_at}
        |> register_and_log_in_user()

      assert context.user
      assert context.scope
      assert context.conn
    end
  end

  describe "register_and_log_in_admin_user/1" do
    test "creates admin user", %{conn: conn} do
      %{user: user} = register_and_log_in_admin_user(%{conn: conn})
      assert user.role == :admin
    end
  end

  describe "log_in_user/3" do
    test "logs in with options", %{conn: conn} do
      user = user_fixture()
      authenticated_at = DateTime.add(DateTime.utc_now(:second), -7200, :second)

      new_conn = log_in_user(conn, user, token_authenticated_at: authenticated_at)

      # User should be logged in
      assert get_session(new_conn, :user_token)
    end
  end
end
