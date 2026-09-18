defmodule AlchemistdropsWeb.Plugs.RawBodyTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias AlchemistdropsWeb.Plugs.RawBody

  # Mock adapter that returns an error when reading body
  defmodule ErrorAdapter do
    def read_req_body(_state, _opts), do: {:error, :mock_read_error}
  end

  describe "call/2" do
    test "reads body and assigns raw_body" do
      body = ~s({"test": "data"})

      conn =
        :post
        |> conn("/test", body)
        |> RawBody.call([])

      assert conn.assigns[:raw_body] == body
    end

    test "skips reading if raw_body already assigned" do
      body = "original body"

      conn =
        :post
        |> conn("/test", "new body")
        |> Plug.Conn.assign(:raw_body, body)
        |> RawBody.call([])

      # Should keep original body
      assert conn.assigns[:raw_body] == body
    end

    test "handles empty body" do
      conn =
        :post
        |> conn("/test", "")
        |> RawBody.call([])

      assert conn.assigns[:raw_body] == ""
    end

    test "handles error when body cannot be read" do
      # Create a conn with a mock adapter that returns an error on read_body
      conn = conn(:post, "/test", "body content")

      # Replace the adapter with one that will error
      error_adapter = {__MODULE__.ErrorAdapter, :state}
      conn = %{conn | adapter: error_adapter}

      # Call RawBody which should handle the error gracefully
      conn = RawBody.call(conn, [])

      # Should assign empty string on error
      assert conn.assigns[:raw_body] == ""
    end
  end

  describe "init/1" do
    test "returns options unchanged" do
      assert RawBody.init([]) == []
      assert RawBody.init(foo: :bar) == [foo: :bar]
    end
  end
end
