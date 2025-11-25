defmodule AlchemistdropsWeb.PostLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Blog - Alchemist's Journal")
     |> stream(:posts, list_published_posts())}
  end

  defp list_published_posts do
    Posts.list_published_posts()
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp get_excerpt(body) when is_binary(body) do
    body
    |> String.slice(0, 160)
    |> then(fn text ->
      if String.length(body) > 160 do
        text <> "..."
      else
        text
      end
    end)
  end

  defp get_excerpt(_), do: ""
end
