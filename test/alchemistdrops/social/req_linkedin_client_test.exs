defmodule Alchemistdrops.Social.ReqLinkedInClientTest do
  use ExUnit.Case, async: false

  alias Alchemistdrops.Social.ReqLinkedInClient

  @request_stub __MODULE__

  setup do
    previous_linkedin = Application.get_env(:alchemistdrops, :linkedin)
    previous_req_options = Application.get_env(:alchemistdrops, :linkedin_req_options)

    Application.put_env(:alchemistdrops, :linkedin,
      client_id: "linkedin-client-id",
      client_secret: "linkedin-client-secret",
      redirect_uri: "https://example.com/admin/linkedin/callback",
      api_version: "202609"
    )

    Application.put_env(
      :alchemistdrops,
      :linkedin_req_options,
      Keyword.merge(previous_req_options || [], plug: {Req.Test, @request_stub}, retry: false)
    )

    on_exit(fn ->
      restore_env(:linkedin, previous_linkedin)
      restore_env(:linkedin_req_options, previous_req_options)
    end)
  end

  test "builds the member authorization URL with OIDC and posting scopes" do
    assert {:ok, authorization_url} = ReqLinkedInClient.authorization_url("single-use-state")

    uri = URI.parse(authorization_url)
    query = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "www.linkedin.com"
    assert uri.path == "/oauth/v2/authorization"

    assert query == %{
             "client_id" => "linkedin-client-id",
             "redirect_uri" => "https://example.com/admin/linkedin/callback",
             "response_type" => "code",
             "scope" => "openid profile w_member_social",
             "state" => "single-use-state"
           }
  end

  test "keeps authorization disabled when LinkedIn configuration is incomplete" do
    Application.put_env(:alchemistdrops, :linkedin,
      client_id: "linkedin-client-id",
      client_secret: nil,
      redirect_uri: "https://example.com/admin/linkedin/callback",
      api_version: "202609"
    )

    assert {:error, :not_configured} =
             ReqLinkedInClient.authorization_url("single-use-state")
  end

  test "exchanges an authorization code using the configured redirect URI" do
    Req.Test.expect(@request_stub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/oauth/v2/accessToken"

      form =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> URI.decode_query()

      assert form == %{
               "client_id" => "linkedin-client-id",
               "client_secret" => "linkedin-client-secret",
               "code" => "authorization-code",
               "grant_type" => "authorization_code",
               "redirect_uri" => "https://example.com/admin/linkedin/callback"
             }

      Req.Test.json(conn, %{access_token: "access-token", expires_in: 5_184_000})
    end)

    assert {:ok, %{access_token: "access-token", expires_in: 5_184_000}} =
             ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "rejects a malformed successful token response" do
    Req.Test.expect(@request_stub, fn conn ->
      Req.Test.json(conn, %{access_token: "access-token"})
    end)

    assert {:error, :invalid_response} = ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "rejects an empty access token in a successful token response" do
    Req.Test.expect(@request_stub, fn conn ->
      Req.Test.json(conn, %{access_token: "", expires_in: 5_184_000})
    end)

    assert {:error, :invalid_response} = ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "rejects a whitespace-only access token in a successful token response" do
    Req.Test.expect(@request_stub, fn conn ->
      Req.Test.json(conn, %{access_token: " \t\n", expires_in: 5_184_000})
    end)

    assert {:error, :invalid_response} = ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "normalizes a non-successful token response without exposing its body" do
    Req.Test.expect(@request_stub, fn conn ->
      Plug.Conn.send_resp(conn, 401, ~s({"error":"secret access-token was rejected"}))
    end)

    assert {:error, {:http_error, 401}} =
             ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "normalizes a token exchange transport failure" do
    Req.Test.expect(@request_stub, &Req.Test.transport_error(&1, :timeout))

    assert {:error, {:transport_error, :timeout}} =
             ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "normalizes a token exchange HTTP protocol failure" do
    Req.Test.expect(@request_stub, &http_protocol_error/1)

    assert {:error, {:request_error, :http_protocol}} =
             ReqLinkedInClient.exchange_code("authorization-code")
  end

  test "normalizes an unexpected token exchange error without exposing it" do
    Req.Test.expect(@request_stub, &opaque_error/1)

    result = ReqLinkedInClient.exchange_code("authorization-code")

    assert {:error, {:request_error, :unexpected}} = result
    refute inspect(result) =~ "secret access-token"
  end

  test "fetches the OIDC profile and maps its subject to a person URN" do
    Req.Test.expect(@request_stub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/userinfo"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer profile-token"]

      Req.Test.json(conn, %{sub: "abc123", name: "LinkedIn Member"})
    end)

    assert {:ok, %{member_urn: "urn:li:person:abc123"}} =
             ReqLinkedInClient.fetch_profile("profile-token")
  end

  test "rejects a malformed successful OIDC profile response" do
    Req.Test.expect(@request_stub, fn conn -> Req.Test.json(conn, %{name: "Missing Subject"}) end)

    assert {:error, :invalid_response} = ReqLinkedInClient.fetch_profile("profile-token")
  end

  test "normalizes a non-successful OIDC profile response" do
    Req.Test.expect(@request_stub, fn conn -> Plug.Conn.send_resp(conn, 403, "forbidden") end)

    assert {:error, {:http_error, 403}} = ReqLinkedInClient.fetch_profile("profile-token")
  end

  test "normalizes an OIDC profile transport failure" do
    Req.Test.expect(@request_stub, &Req.Test.transport_error(&1, :econnrefused))

    assert {:error, {:transport_error, :econnrefused}} =
             ReqLinkedInClient.fetch_profile("profile-token")
  end

  test "normalizes an OIDC profile HTTP protocol failure" do
    Req.Test.expect(@request_stub, &http_protocol_error/1)

    assert {:error, {:request_error, :http_protocol}} =
             ReqLinkedInClient.fetch_profile("profile-token")
  end

  test "normalizes an unexpected OIDC profile error without exposing it" do
    Req.Test.expect(@request_stub, &opaque_error/1)

    result = ReqLinkedInClient.fetch_profile("profile-token")

    assert {:error, {:request_error, :unexpected}} = result
    refute inspect(result) =~ "secret access-token"
  end

  test "publishes a public article post with required REST headers" do
    Req.Test.expect(@request_stub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/posts"

      headers = Map.new(conn.req_headers)
      assert headers["authorization"] == "Bearer publish-token"
      assert headers["linkedin-version"] == "202609"
      assert headers["x-restli-protocol-version"] == "2.0.0"
      assert headers["content-type"] == "application/json"

      assert conn
             |> Req.Test.raw_body()
             |> IO.iodata_to_binary()
             |> Jason.decode!() == %{
               "author" => "urn:li:person:abc123",
               "commentary" => "A concise article summary",
               "content" => %{
                 "article" => %{
                   "source" => "https://example.com/blog/article",
                   "title" => "Article title"
                 }
               },
               "distribution" => %{
                 "feedDistribution" => "MAIN_FEED",
                 "targetEntities" => [],
                 "thirdPartyDistributionChannels" => []
               },
               "isReshareDisabledByAuthor" => false,
               "lifecycleState" => "PUBLISHED",
               "visibility" => "PUBLIC"
             }

      conn
      |> Plug.Conn.put_resp_header("x-restli-id", "urn:li:share:123456")
      |> Plug.Conn.send_resp(201, "")
    end)

    assert {:ok, %{post_urn: "urn:li:share:123456"}} =
             ReqLinkedInClient.publish(
               "publish-token",
               "urn:li:person:abc123",
               "A concise article summary",
               "https://example.com/blog/article",
               "Article title"
             )
  end

  test "rejects a successful post response without a post URN" do
    Req.Test.expect(@request_stub, fn conn -> Plug.Conn.send_resp(conn, 201, "") end)

    assert {:error, :invalid_response} = publish_article()
  end

  test "normalizes a non-successful post response without exposing tokens" do
    Req.Test.expect(@request_stub, fn conn ->
      Plug.Conn.send_resp(conn, 429, "publish-token is rate limited")
    end)

    result = publish_article()

    assert {:error, {:http_error, 429}} = result
    refute inspect(result) =~ "publish-token"
  end

  test "normalizes a post transport failure" do
    Req.Test.expect(@request_stub, &Req.Test.transport_error(&1, :timeout))

    assert {:error, {:transport_error, :timeout}} = publish_article()
  end

  test "normalizes a post HTTP protocol failure" do
    Req.Test.expect(@request_stub, &http_protocol_error/1)

    assert {:error, {:request_error, :http_protocol}} = publish_article()
  end

  test "normalizes an unexpected post error without exposing it" do
    Req.Test.expect(@request_stub, &opaque_error/1)

    result = publish_article()

    assert {:error, {:request_error, :unexpected}} = result
    refute inspect(result) =~ "secret access-token"
  end

  test "preserves configured request headers without allowing required headers to be replaced" do
    Application.put_env(:alchemistdrops, :linkedin_req_options,
      plug: {Req.Test, @request_stub},
      retry: false,
      headers: [
        {"x-client-name", "linkedin-test"},
        {"authorization", "Bearer replaced"},
        {"linkedin-version", "199901"}
      ]
    )

    Req.Test.expect(@request_stub, fn conn ->
      headers = Map.new(conn.req_headers)

      assert headers["x-client-name"] == "linkedin-test"
      assert headers["authorization"] == "Bearer publish-token"
      assert headers["linkedin-version"] == "202609"

      conn
      |> Plug.Conn.put_resp_header("x-restli-id", "urn:li:share:123456")
      |> Plug.Conn.send_resp(201, "")
    end)

    assert {:ok, %{post_urn: "urn:li:share:123456"}} = publish_article()
  end

  test "sets explicit connect and receive timeouts for outbound requests" do
    options = Application.fetch_env!(:alchemistdrops, :linkedin_req_options)

    assert options[:connect_options] == [timeout: 5_000]
    assert options[:receive_timeout] == 15_000
  end

  defp restore_env(key, nil), do: Application.delete_env(:alchemistdrops, key)
  defp restore_env(key, value), do: Application.put_env(:alchemistdrops, key, value)

  defp http_protocol_error(conn) do
    Plug.Conn.put_private(
      conn,
      :req_test_exception,
      %Req.HTTPError{protocol: :http2, reason: :unprocessed}
    )
  end

  defp opaque_error(conn) do
    Plug.Conn.put_private(
      conn,
      :req_test_exception,
      %RuntimeError{message: "secret access-token from provider"}
    )
  end

  defp publish_article do
    ReqLinkedInClient.publish(
      "publish-token",
      "urn:li:person:abc123",
      "A concise article summary",
      "https://example.com/blog/article",
      "Article title"
    )
  end
end
