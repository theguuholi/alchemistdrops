defmodule Alchemistdrops.Posts.DevToPublisher do
  @moduledoc """
  Translates published AlchemistDrops posts into DEV.to API articles.

  The subcontext owns DEV.to-specific payload rules, canonical attribution,
  create-versus-update selection, and safe normalization of remote failures.
  Persistence remains in the parent `Alchemistdrops.Posts` context.
  """

  alias Alchemistdrops.Posts.Post

  @accept "application/vnd.forem.api-v1+json"

  @typedoc "Remote identity returned after a successful DEV.to synchronization."
  @type publication :: %{article_id: pos_integer(), url: String.t()}

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
  Runtime configuration supplies `:api_key`, `:base_url`, and `:http_client`;
  callers may override them through `options` for deterministic tests.
  """
  @spec sync_article(Post.t(), String.t()) ::
          {:ok, publication()} | {:error, error_reason()}
  @spec sync_article(Post.t(), String.t(), keyword()) ::
          {:ok, publication()} | {:error, error_reason()}
  def sync_article(post, canonical_url, options \\ [])

  def sync_article(%Post{status: status}, _canonical_url, _options) when status != :published,
    do: {:error, :post_not_published}

  def sync_article(%Post{} = post, canonical_url, options) do
    api_key = option(options, :api_key)

    if present?(api_key) do
      request(post, canonical_url, api_key, options)
    else
      {:error, :not_configured}
    end
  end

  defp request(post, canonical_url, api_key, options) do
    http_client = option(options, :http_client)

    request_options = [
      method: request_method(post),
      url: request_url(post, option(options, :base_url)),
      headers: [
        {"api-key", api_key},
        {"accept", @accept},
        {"content-type", "application/json"}
      ],
      json: %{"article" => article_payload(post, canonical_url)}
    ]

    request_options
    |> http_client.request()
    |> normalize_response(post.dev_to_article_id)
  rescue
    _error in [ArgumentError, KeyError, UndefinedFunctionError] -> {:error, :request_failed}
  end

  defp article_payload(post, canonical_url) do
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

  defp dev_to_tags(%Ecto.Association.NotLoaded{}), do: ""

  defp dev_to_tags(tags) do
    tags
    |> Enum.map(& &1.slug)
    |> Enum.filter(&present?/1)
    |> Enum.take(4)
    |> Enum.join(",")
  end

  defp request_method(%Post{dev_to_article_id: nil}), do: :post
  defp request_method(%Post{}), do: :put

  defp request_url(%Post{dev_to_article_id: nil}, base_url),
    do: String.trim_trailing(base_url, "/") <> "/api/articles"

  defp request_url(%Post{dev_to_article_id: article_id}, base_url),
    do: String.trim_trailing(base_url, "/") <> "/api/articles/#{article_id}"

  defp normalize_response(
         {:ok, %{status: status, body: %{"id" => article_id, "url" => url}}},
         expected_article_id
       )
       when status in 200..299 and is_integer(article_id) and article_id > 0 and is_binary(url) and
              (is_nil(expected_article_id) or article_id == expected_article_id) do
    if absolute_http_url?(url) do
      {:ok, %{article_id: article_id, url: url}}
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
  defp normalize_response(_response, _expected_article_id), do: {:error, :invalid_response}

  defp option(options, key) do
    if Keyword.has_key?(options, key) do
      Keyword.get(options, key)
    else
      :alchemistdrops
      |> Application.get_env(:dev_to, [])
      |> Keyword.get(key)
    end
  end

  defp absolute_http_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and present?(uri.host)
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
