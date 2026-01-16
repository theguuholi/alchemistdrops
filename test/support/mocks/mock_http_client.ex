defmodule Alchemistdrops.Payments.MockHttpClient do
  @moduledoc """
  Mock HTTP client for testing Stripe API interactions.

  Uses the process dictionary to store expectations for test isolation.
  """

  @doc """
  Sets up a mock response for the next request.

  ## Examples

      MockHttpClient.expect_response(%{status: 200, body: %{"id" => "cs_test"}})

  """
  def expect_response(response) do
    Process.put(:mock_http_response, response)
  end

  @doc """
  Sets up a mock error for the next request.

  ## Examples

      MockHttpClient.expect_error(:timeout)

  """
  def expect_error(error) do
    Process.put(:mock_http_error, error)
  end

  @doc """
  Returns the last request made.

  ## Examples

      MockHttpClient.last_request()
      %{method: :post, url: "...", body: "..."}

  """
  def last_request do
    Process.get(:mock_http_last_request)
  end

  @doc """
  Makes a mock HTTP request.

  Returns the expected response or error set via `expect_response/1` or `expect_error/1`.
  """
  def request(opts) do
    # Store the request for assertions
    Process.put(:mock_http_last_request, opts)

    cond do
      error = Process.delete(:mock_http_error) ->
        {:error, error}

      response = Process.delete(:mock_http_response) ->
        {:ok, response}

      true ->
        # Default response for successful checkout session creation
        {:ok,
         %{
           status: 200,
           body: %{
             "id" => "cs_test_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}",
             "url" => "https://checkout.stripe.com/test/session",
             "payment_intent" =>
               "pi_test_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
           }
         }}
    end
  end
end
