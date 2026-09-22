defmodule Alchemistdrops.Posts.DevToPublisher.ReqClientTest do
  use ExUnit.Case, async: true

  alias Alchemistdrops.Posts.DevToPublisher.ReqClient

  setup {Req.Test, :verify_on_exit!}

  test "given a JSON request, when DEV.to responds, then it returns a normalized response" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/articles"
      assert Plug.Conn.get_req_header(conn, "api-key") == ["secret"]

      assert Jason.decode!(Req.Test.raw_body(conn)) == %{
               "article" => %{"published" => true, "title" => "OTP"}
             }

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(%{"id" => 44, "url" => "https://dev.to/user/otp"})
    end)

    assert {:ok,
            %{
              status: 201,
              body: %{"id" => 44, "url" => "https://dev.to/user/otp"}
            }} =
             ReqClient.request(
               method: :post,
               url: "https://dev.to/api/articles",
               headers: [{"api-key", "secret"}],
               json: %{"article" => %{"published" => true, "title" => "OTP"}},
               plug: {Req.Test, __MODULE__}
             )
  end

  test "given a transport error, when requested, then it returns the exception" do
    Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :timeout))

    assert {:error, %Req.TransportError{reason: :timeout}} =
             ReqClient.request(
               method: :post,
               url: "https://dev.to/api/articles",
               plug: {Req.Test, __MODULE__}
             )
  end
end
