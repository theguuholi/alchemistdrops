defmodule Alchemistdrops.Payments.ReqClient do
  @moduledoc """
  HTTP client wrapper using Req for Stripe API requests.
  """

  @doc """
  Makes an HTTP request using Req.

  ## Options

  - `:method` - HTTP method (:get, :post, etc.)
  - `:url` - Request URL
  - `:headers` - Request headers
  - `:body` - Request body

  ## Returns

  - `{:ok, %{status: integer, body: map}}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> try do
      ...>   Alchemistdrops.Payments.ReqClient.request([])
      ...> rescue
      ...>   KeyError -> :missing_required_option
      ...> end
      :missing_required_option
  """
  @typedoc "Normalized response returned to the payments boundary."
  @type response :: %{status: non_neg_integer(), body: term()}

  @spec request(keyword()) :: {:ok, response()} | {:error, Exception.t()}
  def request(opts) do
    method = Keyword.fetch!(opts, :method)
    url = Keyword.fetch!(opts, :url)
    headers = Keyword.get(opts, :headers, [])
    body = Keyword.get(opts, :body)

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      body: body,
      decode_body: true
    ]

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
