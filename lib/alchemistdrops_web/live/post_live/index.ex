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
    page = Posts.list_published_page(params, page_size: @page_size)

    {:noreply, assign(socket, page)}
  end

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
