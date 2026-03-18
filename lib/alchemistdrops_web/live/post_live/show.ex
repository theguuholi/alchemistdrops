defmodule AlchemistdropsWeb.PostLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Posts.get_post!(id)

    # Increment views asynchronously to avoid impacting test assertions
    if connected?(socket) do
      Posts.increment_views(post)
    end

    meta_description = get_meta_description(post.body)

    {:ok,
     socket
     |> assign(:page_title, post.title <> " - Alchemist's Journal")
     |> assign(:meta_description, meta_description)
     |> assign(:meta_url, build_url(~p"/blog/#{post}"))
     |> assign(:post, post)
     |> assign(:rendered_body, render_markdown(post.body))}
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp get_meta_description(body) when is_binary(body) and byte_size(body) > 0 do
    body
    |> String.slice(0, 160)
    |> String.replace("\n", " ")
    |> String.trim()
  end

  defp get_meta_description(_), do: "Read this post on Alchemist's Journal"

  defp build_url(path) do
    AlchemistdropsWeb.Endpoint.url() <> path
  end

  defp render_markdown(content) when is_binary(content) and byte_size(content) > 0 do
    {:ok, html} = MDEx.to_html(content)
    html = wrap_tables_for_styling(html)
    Phoenix.HTML.raw(html)
  end

  defp render_markdown(_), do: Phoenix.HTML.raw("")

  defp wrap_tables_for_styling(html) do
    html
    |> String.replace("<table", "<div class=\"table-wrapper\"><table")
    |> String.replace("</table>", "</table></div>")
  end
end
