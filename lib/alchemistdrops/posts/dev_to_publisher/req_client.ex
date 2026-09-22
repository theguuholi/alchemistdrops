defmodule Alchemistdrops.Posts.DevToPublisher.ReqClient do
  @moduledoc """
  Req-backed HTTP adapter for the DEV.to publishing subcontext.

  It keeps Req response structs out of the domain boundary so the publisher can
  consume a small, deterministic response contract.
  """

  @typedoc "Normalized HTTP response consumed by the DEV.to publisher."
  @type response :: %{status: non_neg_integer(), body: term()}

  @doc """
  Executes a Req request and normalizes successful HTTP responses.

  The options are passed to `Req.request/1`, including `:method`, `:url`,
  `:headers`, and `:json`. Transport exceptions are returned unchanged inside
  the error tuple for the publisher to sanitize.
  """
  @spec request(keyword()) :: {:ok, response()} | {:error, Exception.t()}
  def request(options) do
    options =
      Keyword.merge(
        options,
        Application.get_env(:alchemistdrops, :dev_to, [])[:req_options] || []
      )

    case Req.request(options) do
      {:ok, %Req.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
