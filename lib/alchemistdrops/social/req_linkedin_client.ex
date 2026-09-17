defmodule Alchemistdrops.Social.ReqLinkedInClient do
  @moduledoc """
  Implements the LinkedIn integration boundary with `Req`.
  """

  @behaviour Alchemistdrops.Social.LinkedInClient

  @authorization_url "https://www.linkedin.com/oauth/v2/authorization"
  @token_url "https://www.linkedin.com/oauth/v2/accessToken"
  @userinfo_url "https://api.linkedin.com/v2/userinfo"
  @posts_url "https://api.linkedin.com/rest/posts"
  @scopes "openid profile w_member_social"

  @impl true
  def authorization_url(state) when is_binary(state) do
    with {:ok, config} <-
           linkedin_config([:client_id, :client_secret, :redirect_uri, :api_version]) do
      query =
        URI.encode_query(%{
          client_id: config[:client_id],
          redirect_uri: config[:redirect_uri],
          response_type: "code",
          scope: @scopes,
          state: state
        })

      {:ok, @authorization_url <> "?" <> query}
    end
  end

  @impl true
  def exchange_code(code) when is_binary(code) do
    with {:ok, config} <- linkedin_config([:client_id, :client_secret, :redirect_uri]) do
      options =
        request_options(
          form: [
            grant_type: "authorization_code",
            code: code,
            client_id: config[:client_id],
            client_secret: config[:client_secret],
            redirect_uri: config[:redirect_uri]
          ]
        )

      case Req.post(@token_url, options) do
        {:ok, %{status: 200, body: %{"access_token" => access_token, "expires_in" => expires_in}}}
        when is_binary(access_token) and is_integer(expires_in) and expires_in >= 0 ->
          if String.trim(access_token) == "" do
            {:error, :invalid_response}
          else
            {:ok, %{access_token: access_token, expires_in: expires_in}}
          end

        {:ok, %{status: 200}} ->
          {:error, :invalid_response}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, error} ->
          normalize_request_error(error)
      end
    end
  end

  @impl true
  def fetch_profile(access_token) when is_binary(access_token) do
    options = request_options(headers: [{"authorization", "Bearer #{access_token}"}])

    case Req.get(@userinfo_url, options) do
      {:ok, %{status: 200, body: %{"sub" => subject}}}
      when is_binary(subject) and subject != "" ->
        {:ok, %{member_urn: "urn:li:person:#{subject}"}}

      {:ok, %{status: 200}} ->
        {:error, :invalid_response}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, error} ->
        normalize_request_error(error)
    end
  end

  @impl true
  def publish(access_token, member_urn, text, article_url, title) do
    with {:ok, config} <- linkedin_config([:api_version]) do
      options =
        request_options(
          json: %{
            author: member_urn,
            commentary: text,
            visibility: "PUBLIC",
            distribution: %{
              feedDistribution: "MAIN_FEED",
              targetEntities: [],
              thirdPartyDistributionChannels: []
            },
            content: %{article: %{source: article_url, title: title}},
            lifecycleState: "PUBLISHED",
            isReshareDisabledByAuthor: false
          },
          headers: [
            {"authorization", "Bearer #{access_token}"},
            {"linkedin-version", config[:api_version]},
            {"x-restli-protocol-version", "2.0.0"},
            {"content-type", "application/json"}
          ]
        )

      case Req.post(@posts_url, options) do
        {:ok, %{status: 201, headers: %{"x-restli-id" => [post_urn | _]}}}
        when is_binary(post_urn) and post_urn != "" ->
          {:ok, %{post_urn: post_urn}}

        {:ok, %{status: 201}} ->
          {:error, :invalid_response}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, error} ->
          normalize_request_error(error)
      end
    end
  end

  defp linkedin_config(required_keys) do
    config = Application.get_env(:alchemistdrops, :linkedin, [])

    if Enum.all?(required_keys, &(is_binary(config[&1]) and config[&1] != "")) do
      {:ok, config}
    else
      {:error, :not_configured}
    end
  end

  defp request_options(options) do
    configured_options = Application.get_env(:alchemistdrops, :linkedin_req_options, [])
    configured_headers = Keyword.get(configured_options, :headers, [])
    required_headers = Keyword.get(options, :headers, [])

    configured_options
    |> Keyword.delete(:headers)
    |> Keyword.merge(Keyword.delete(options, :headers))
    |> maybe_put_headers(merge_headers(configured_headers, required_headers))
  end

  defp merge_headers(configured_headers, required_headers) do
    required_names = MapSet.new(required_headers, fn {name, _value} -> normalize_header(name) end)

    configured_headers
    |> Enum.reject(fn {name, _value} ->
      MapSet.member?(required_names, normalize_header(name))
    end)
    |> Kernel.++(required_headers)
  end

  defp maybe_put_headers(options, []), do: options
  defp maybe_put_headers(options, headers), do: Keyword.put(options, :headers, headers)

  defp normalize_request_error(%Req.TransportError{reason: reason}) do
    {:error, {:transport_error, reason}}
  end

  defp normalize_request_error(%Req.HTTPError{}) do
    {:error, {:request_error, :http_protocol}}
  end

  defp normalize_request_error(_error) do
    {:error, {:request_error, :unexpected}}
  end

  defp normalize_header(name), do: name |> to_string() |> String.downcase()
end
