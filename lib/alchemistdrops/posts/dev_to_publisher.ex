defmodule Alchemistdrops.Posts.DevToPublisher do
  @moduledoc """
  Translates published AlchemistDrops posts into DEV.to API articles.

  The subcontext owns DEV.to-specific payload rules, canonical attribution,
  create-versus-update selection, and safe normalization of remote failures.
  Persistence remains in the parent `Alchemistdrops.Posts` context.
  """

  alias Alchemistdrops.Posts.Post

  @accept "application/vnd.forem.api-v1+json"
  @base_url "https://dev.to"

  @typedoc "DEV.to article attributes derived from a locally published post."
  @type article :: %{required(String.t()) => String.t() | true | nil}

  @typedoc "Remote identity returned by DEV.to after a successful synchronization."
  @type remote_article :: %{article_id: pos_integer(), article_url: String.t()}

  @typedoc "Stable failure returned without exposing credentials or transport internals."
  @type error_reason ::
          :invalid_response
          | :not_configured
          | :post_not_published
          | :request_failed
          | {:api_error, non_neg_integer()}

  @doc """
  Creates or updates a published post on DEV.to.

  A post without `dev_to_article_id` is created with `POST`; a post with an
  existing remote identifier is updated with `PUT`. The payload always marks
  the AlchemistDrops URL as canonical and includes a visible attribution footer.
  Runtime configuration supplies the API key and Req configuration.
  """
  @spec sync_article(Post.t(), String.t()) ::
          {:ok, remote_article()} | {:error, error_reason()}

  def sync_article(%Post{status: status}, _canonical_url) when status != :published,
    do: {:error, :post_not_published}

  def sync_article(%Post{} = post, canonical_url) do
    with {:ok, api_key} <- fetch_api_key() do
      post
      |> build_request(canonical_url, api_key)
      |> send_request()
      |> normalize_response(post.dev_to_article_id)
    end
  end

  @doc """
  Transforms a post into the article attributes expected by DEV.to.

  The transformation is pure: it adds canonical attribution, localizes the
  footer, and limits tags without performing HTTP or persistence work.

  ## Examples

      iex> post = %Alchemistdrops.Posts.Post{
      ...>   title: "OTP in production",
      ...>   body: "Article body",
      ...>   language: :en,
      ...>   tags: []
      ...> }
      iex> article = Alchemistdrops.Posts.DevToPublisher.build_article(
      ...>   post,
      ...>   "https://alchemistdrops.com/blog/otp"
      ...> )
      iex> {article["title"], article["published"], article["canonical_url"]}
      {"OTP in production", true, "https://alchemistdrops.com/blog/otp"}
  """
  @spec build_article(Post.t(), String.t()) :: article()
  def build_article(%Post{} = post, canonical_url) do
    %{
      "title" => post.title,
      "body_markdown" => body_with_attribution(post, canonical_url),
      "published" => true,
      "tags" => dev_to_tags(post.tags),
      "canonical_url" => canonical_url,
      "description" => post.summary,
      "main_image" => post.cover_image_url
    }
  end

  defp fetch_api_key do
    case config(:api_key) do
      api_key when is_binary(api_key) ->
        if present?(api_key), do: {:ok, api_key}, else: {:error, :not_configured}

      _missing ->
        {:error, :not_configured}
    end
  end

  defp build_request(post, canonical_url, api_key) do
    [
      method: request_method(post),
      url: request_url(post),
      headers: [
        {"api-key", api_key},
        {"accept", @accept},
        {"content-type", "application/json"}
      ],
      json: %{"article" => build_article(post, canonical_url)}
    ]
  end

  defp send_request(request_options) do
    request_options
    |> Keyword.merge(config(:req_options) || [])
    |> Req.request()
  rescue
    _error in [ArgumentError, KeyError] -> {:error, :request_failed}
  end

  defp body_with_attribution(post, canonical_url) do
    footer =
      case post.language do
        :pt_br ->
          "_Este artigo foi publicado originalmente em [AlchemistDrops](#{canonical_url})._"

        _language ->
          "_This article was originally published on [AlchemistDrops](#{canonical_url})._"
      end

    [String.trim(post.body || ""), "---", footer]
    |> Enum.join("\n\n")
  end

  defp dev_to_tags(tags) do
    tags
    |> Enum.map(& &1.slug)
    |> Enum.filter(&present?/1)
    |> Enum.take(4)
    |> Enum.join(",")
  end

  defp request_method(%Post{dev_to_article_id: nil}), do: :post
  defp request_method(%Post{}), do: :put

  defp request_url(%Post{dev_to_article_id: nil}), do: @base_url <> "/api/articles"

  defp request_url(%Post{dev_to_article_id: article_id}),
    do: @base_url <> "/api/articles/#{article_id}"

  defp normalize_response(
         {:ok, %{status: status, body: %{"id" => article_id, "url" => article_url}}},
         expected_article_id
       )
       when status in 200..299 and is_integer(article_id) and article_id > 0 and
              is_binary(article_url) and
              (is_nil(expected_article_id) or article_id == expected_article_id) do
    if dev_to_url?(article_url) do
      {:ok, %{article_id: article_id, article_url: article_url}}
    else
      {:error, :invalid_response}
    end
  end

  defp normalize_response({:ok, %{status: status, body: _body}}, _expected_article_id)
       when status in 200..299,
       do: {:error, :invalid_response}

  defp normalize_response({:ok, %{status: status}}, _expected_article_id),
    do: {:error, {:api_error, status}}

  defp normalize_response({:error, _reason}, _expected_article_id), do: {:error, :request_failed}

  defp config(key), do: :alchemistdrops |> Application.get_env(:dev_to, []) |> Keyword.get(key)

  defp dev_to_url?(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: "dev.to"} -> true
      _uri -> false
    end
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
