defmodule Alchemistdrops.Payments.MockHttpClientTest do
  use ExUnit.Case, async: true

  alias Alchemistdrops.Payments.MockHttpClient

  describe "request/1 default response" do
    test "returns default success response when no expectation is set" do
      # Don't set any expectation
      opts = [method: :post, url: "/test", body: "test"]

      assert {:ok, response} = MockHttpClient.request(opts)
      assert response.status == 200
      assert is_binary(response.body["id"])
      assert String.starts_with?(response.body["id"], "cs_test_")
      assert response.body["url"] == "https://checkout.stripe.com/test/session"
      assert String.starts_with?(response.body["payment_intent"], "pi_test_")
    end
  end

  describe "expect_response/1" do
    test "stores and returns custom response" do
      custom_response = %{status: 201, body: %{"custom" => "response"}}
      MockHttpClient.expect_response(custom_response)

      assert {:ok, ^custom_response} = MockHttpClient.request(method: :get, url: "/test")
    end
  end

  describe "expect_error/1" do
    test "stores and returns custom error" do
      MockHttpClient.expect_error(:custom_error)

      assert {:error, :custom_error} = MockHttpClient.request(method: :get, url: "/test")
    end
  end

  describe "last_request/0" do
    test "returns the last request made" do
      opts = [method: :post, url: "/webhook", body: "payload"]
      MockHttpClient.request(opts)

      assert MockHttpClient.last_request() == opts
    end
  end
end
