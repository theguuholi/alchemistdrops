defmodule AlchemistdropsWeb.LinkedInAuthControllerTest do
  use AlchemistdropsWeb.ConnCase, async: false

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Social
  alias Alchemistdrops.Social.TokenCipher

  @request_stub __MODULE__

  setup do
    previous_linkedin = Application.get_env(:alchemistdrops, :linkedin)
    previous_client = Application.get_env(:alchemistdrops, :linkedin_client)
    previous_req_options = Application.get_env(:alchemistdrops, :linkedin_req_options)

    previous_encryption_key =
      Application.get_env(:alchemistdrops, :linkedin_token_encryption_key)

    Application.put_env(:alchemistdrops, :linkedin,
      client_id: "linkedin-client-id",
      client_secret: "linkedin-client-secret",
      redirect_uri: "https://example.com/admin/linkedin/callback",
      api_version: "202609"
    )

    Application.put_env(
      :alchemistdrops,
      :linkedin_client,
      Alchemistdrops.Social.ReqLinkedInClient
    )

    Application.put_env(:alchemistdrops, :linkedin_req_options,
      plug: {Req.Test, @request_stub},
      retry: false
    )

    on_exit(fn ->
      restore_env(:linkedin, previous_linkedin)
      restore_env(:linkedin_client, previous_client)
      restore_env(:linkedin_req_options, previous_req_options)
      restore_env(:linkedin_token_encryption_key, previous_encryption_key)
    end)
  end

  test "connect redirects a guest to login", %{conn: conn} do
    conn = get(conn, "/admin/linkedin/connect?post_id=post-id")

    assert redirected_to(conn) == "/users/log-in"
  end

  test "connect redirects a signed-in non-admin user home", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture(%{role: :user}))
      |> get("/admin/linkedin/connect?post_id=post-id")

    assert redirected_to(conn) == "/"
  end

  test "connect stores state and an internal return path before redirecting an admin", %{
    conn: conn
  } do
    post = post_fixture()

    conn =
      conn
      |> log_in_user(user_fixture(%{role: :admin}))
      |> get("/admin/linkedin/connect?post_id=#{post.id}")

    authorization_url = redirected_to(conn)
    query = authorization_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert String.starts_with?(
             authorization_url,
             "https://www.linkedin.com/oauth/v2/authorization?"
           )

    assert query["state"] == get_session(conn, :linkedin_oauth_state)
    assert byte_size(query["state"]) >= 32
    assert get_session(conn, :linkedin_oauth_return_to) == "/admin/posts/#{post.id}/edit"
  end

  test "connect stays disabled when LinkedIn client configuration is incomplete", %{conn: conn} do
    post = post_fixture()

    Application.put_env(:alchemistdrops, :linkedin,
      client_id: "linkedin-client-id",
      client_secret: nil,
      redirect_uri: "https://example.com/admin/linkedin/callback",
      api_version: "202609"
    )

    conn =
      conn
      |> log_in_user(user_fixture(%{role: :admin}))
      |> get("/admin/linkedin/connect?post_id=#{post.id}")

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not configured"
    refute get_session(conn, :linkedin_oauth_state)
  end

  test "connect stays disabled without the token encryption key", %{conn: conn} do
    post = post_fixture()
    Application.delete_env(:alchemistdrops, :linkedin_token_encryption_key)

    conn =
      conn
      |> log_in_user(user_fixture(%{role: :admin}))
      |> get("/admin/linkedin/connect?post_id=#{post.id}")

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not configured"
    refute get_session(conn, :linkedin_oauth_state)
  end

  test "callback redirects a guest to login", %{conn: conn} do
    conn = get(conn, "/admin/linkedin/callback?code=code&state=state")

    assert redirected_to(conn) == "/users/log-in"
  end

  test "callback rejects a missing state and consumes the OAuth session", %{conn: conn} do
    {conn, post, _state} = start_oauth(conn)

    conn = get(conn, "/admin/linkedin/callback?code=authorization-code")

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "could not be verified"
    refute get_session(conn, :linkedin_oauth_state)
    refute get_session(conn, :linkedin_oauth_return_to)
  end

  test "callback rejects an equal-length mismatched state and consumes the OAuth session", %{
    conn: conn
  } do
    {conn, post, state} = start_oauth(conn)
    mismatched_state = flip_first_character(state)

    conn =
      get(
        conn,
        "/admin/linkedin/callback?code=authorization-code&state=#{mismatched_state}"
      )

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "could not be verified"
    refute get_session(conn, :linkedin_oauth_state)
    refute get_session(conn, :linkedin_oauth_return_to)
  end

  test "callback returns an OAuth denial to the post form without calling LinkedIn", %{conn: conn} do
    {conn, post, state} = start_oauth(conn)

    conn = get(conn, "/admin/linkedin/callback?error=access_denied&state=#{state}")

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "was not completed"
    assert Social.get_connection() == nil
    refute get_session(conn, :linkedin_oauth_state)
    refute get_session(conn, :linkedin_oauth_return_to)
  end

  test "callback exchanges the code, fetches the profile, and stores the encrypted connection", %{
    conn: conn
  } do
    {conn, post, state} = start_oauth(conn)

    Req.Test.expect(@request_stub, fn conn ->
      assert conn.request_path == "/oauth/v2/accessToken"
      Req.Test.json(conn, %{access_token: "callback-access-token", expires_in: 3_600})
    end)

    Req.Test.expect(@request_stub, fn conn ->
      assert conn.request_path == "/v2/userinfo"

      assert Plug.Conn.get_req_header(conn, "authorization") == [
               "Bearer callback-access-token"
             ]

      Req.Test.json(conn, %{sub: "abc123"})
    end)

    conn =
      get(conn, "/admin/linkedin/callback?code=authorization-code&state=#{state}")

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "connected"
    refute inspect(conn.assigns.flash) =~ "callback-access-token"
    refute get_session(conn, :linkedin_oauth_state)
    refute get_session(conn, :linkedin_oauth_return_to)

    connection = Social.get_connection()
    assert connection.member_urn == "urn:li:person:abc123"
    assert DateTime.compare(connection.expires_at, DateTime.utc_now(:second)) == :gt

    assert {:ok, "callback-access-token"} =
             TokenCipher.decrypt(connection.access_token_ciphertext)
  end

  test "callback redacts a LinkedIn exchange failure and returns to the post form", %{conn: conn} do
    {conn, post, state} = start_oauth(conn)

    Req.Test.expect(@request_stub, fn conn ->
      Plug.Conn.send_resp(conn, 401, "callback-access-token was rejected")
    end)

    conn =
      get(conn, "/admin/linkedin/callback?code=authorization-code&state=#{state}")

    assert redirected_to(conn) == "/admin/posts/#{post.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "could not connect"
    refute inspect(conn.assigns.flash) =~ "callback-access-token"
    assert Social.get_connection() == nil
    refute get_session(conn, :linkedin_oauth_state)
    refute get_session(conn, :linkedin_oauth_return_to)
  end

  defp restore_env(key, nil), do: Application.delete_env(:alchemistdrops, key)
  defp restore_env(key, value), do: Application.put_env(:alchemistdrops, key, value)

  defp start_oauth(conn) do
    post = post_fixture()

    conn =
      conn
      |> log_in_user(user_fixture(%{role: :admin}))
      |> get("/admin/linkedin/connect?post_id=#{post.id}")

    {conn, post, get_session(conn, :linkedin_oauth_state)}
  end

  defp flip_first_character("A" <> rest), do: "B" <> rest
  defp flip_first_character(<<_first, rest::binary>>), do: "A" <> rest
end
