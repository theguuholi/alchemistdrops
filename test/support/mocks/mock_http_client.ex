defmodule Alchemistdrops.Payments.MockHttpClient do
  @moduledoc """
  Mock HTTP client for testing Stripe API interactions.

  In test, uses a shared ETS table so expectations set in the test process
  are visible to other processes (e.g. LiveView). Falls back to process
  dictionary when ETS is not available.
  """

  defp ets_table? do
    :ets.whereis(:mock_http_ets) != :undefined
  end

  @doc """
  Sets up a mock response for the next request.

  ## Examples

      MockHttpClient.expect_response(%{status: 200, body: %{"id" => "cs_test"}})

  """
  def expect_response(response) do
    if ets_table?() do
      :ets.insert(:mock_http_ets, {:mock_http_response, response})
    else
      Process.put(:mock_http_response, response)
    end
  end

  @doc """
  Sets up a mock error for the next request.

  ## Examples

      MockHttpClient.expect_error(:timeout)

  """
  def expect_error(error) do
    if ets_table?() do
      :ets.insert(:mock_http_ets, {:mock_http_error, error})
    else
      Process.put(:mock_http_error, error)
    end
  end

  @doc """
  Returns the last request made.

  ## Examples

      MockHttpClient.last_request()
      %{method: :post, url: "...", body: "..."}

  """
  def last_request do
    if ets_table?() do
      case :ets.lookup(:mock_http_ets, :mock_http_last_request) do
        [{:mock_http_last_request, opts}] -> opts
        [] -> nil
      end
    else
      Process.get(:mock_http_last_request)
    end
  end

  @doc """
  Makes a mock HTTP request.

  Returns the expected response or error set via `expect_response/1` or `expect_error/1`.
  """
  def request(opts) do
    if ets_table?() do
      request_via_ets(opts)
    else
      request_via_process(opts)
    end
  end

  defp request_via_ets(opts) do
    :ets.insert(:mock_http_ets, {:mock_http_last_request, opts})

    case :ets.take(:mock_http_ets, :mock_http_error) do
      [{:mock_http_error, error}] ->
        {:error, error}

      [] ->
        case :ets.take(:mock_http_ets, :mock_http_response) do
          [{:mock_http_response, response}] ->
            {:ok, response}

          [] ->
            default_success_response()
        end
    end
  end

  defp request_via_process(opts) do
    Process.put(:mock_http_last_request, opts)

    cond do
      error = Process.delete(:mock_http_error) ->
        {:error, error}

      response = Process.delete(:mock_http_response) ->
        {:ok, response}

      true ->
        default_success_response()
    end
  end

  defp default_success_response do
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
