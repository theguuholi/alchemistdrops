defmodule Alchemistdrops.Payments.ReqClientTest do
  @moduledoc """
  Tests for ReqClient module.
  """
  use ExUnit.Case, async: false

  alias Alchemistdrops.Payments.ReqClient

  describe "request/1 error handling" do
    test "raises KeyError for missing :method" do
      assert_raise KeyError, fn ->
        ReqClient.request([])
      end
    end

    test "raises KeyError for missing :url" do
      assert_raise KeyError, fn ->
        ReqClient.request(method: :get)
      end
    end

    test "returns error for connection refused" do
      opts = [method: :get, url: "http://localhost:0/test"]
      assert {:error, _} = ReqClient.request(opts)
    end

    test "handles optional body in request" do
      opts = [method: :post, url: "http://localhost:0/test", body: "test"]
      assert {:error, _} = ReqClient.request(opts)
    end

    test "handles custom headers in request" do
      opts = [
        method: :get,
        url: "http://localhost:0/test",
        headers: [{"x-custom", "value"}]
      ]

      assert {:error, _} = ReqClient.request(opts)
    end
  end

  describe "request/1 success path" do
    test "returns success response with valid status and body" do
      # Start a simple HTTP server for testing
      {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen_socket)

      # Spawn a process to handle the request
      parent = self()

      spawn(fn ->
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        {:ok, _request} = :gen_tcp.recv(socket, 0, 5000)

        response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"test\":\"ok\"}"
        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        send(parent, :request_handled)
      end)

      # Make request to our test server
      opts = [method: :get, url: "http://localhost:#{port}/test"]
      result = ReqClient.request(opts)

      # Wait for server to finish
      receive do
        :request_handled -> :ok
      after
        5000 -> :ok
      end

      :gen_tcp.close(listen_socket)

      assert {:ok, %{status: 200, body: body}} = result
      assert body == %{"test" => "ok"}
    end
  end
end
