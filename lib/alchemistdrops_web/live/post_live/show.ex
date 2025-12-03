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

  defp get_meta_description(nil), do: "Read this post on Alchemist's Journal"

  defp get_meta_description(body) when is_binary(body) do
    body
    |> String.slice(0, 160)
    |> String.replace("\n", " ")
    |> String.trim()
  end

  defp build_url(path) do
    AlchemistdropsWeb.Endpoint.url() <> path
  end

  defp render_markdown(nil), do: Phoenix.HTML.raw("")

  defp render_markdown(content) when is_binary(content) do
    case MDEx.to_html(content) do
      {:ok, html} -> Phoenix.HTML.raw(html)
      {:error, _} -> Phoenix.HTML.raw(content)
    end
  end
end
