defmodule AlchemistdropsWeb.PostLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Article

  @page_size 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Blog - Alchemist's Journal")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    categories = Posts.list_categories_with_published_counts()
    tags = Posts.list_tags_with_published_counts()
    category = known_slug(params["category"], categories, :category)
    tag = known_slug(params["tag"], tags, :tag)
    page = positive_page(params["page"])

    posts =
      Posts.list_published_posts(
        page: page,
        page_size: @page_size + 1,
        category: category,
        tag: tag
      )

    {:noreply,
     socket
     |> assign(:posts, Enum.take(posts, @page_size))
     |> assign(:categories, categories)
     |> assign(:tags, tags)
     |> assign(:selected_category, category)
     |> assign(:selected_tag, tag)
     |> assign(:current_page, page)
     |> assign(:has_next_page?, length(posts) > @page_size)}
  end

  defp known_slug(nil, _items, _key), do: nil

  defp known_slug(value, items, key) do
    if Enum.any?(items, &(Map.fetch!(&1, key).slug == value)), do: value
  end

  defp positive_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> page
      _invalid -> 1
    end
  end

  defp positive_page(_value), do: 1

  defp page_params(category, tag, page) do
    %{}
    |> maybe_put("category", category)
    |> maybe_put("tag", tag)
    |> maybe_put("page", if(page > 1, do: page))
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp format_date(datetime), do: Calendar.strftime(datetime, "%B %d, %Y")
  defp article_metadata(post), do: Article.build(post)
end
