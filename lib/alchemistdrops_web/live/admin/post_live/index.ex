defmodule AlchemistdropsWeb.Admin.PostLive.Index do
  @moduledoc """
  Admin LiveView for managing blog posts.

  Displays all posts with their view counts.
  Mobile-first responsive design with proper accessibility.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts

  @impl true
  def mount(_params, _session, socket) do
    posts = Posts.list_posts()
    stats = calculate_stats(posts)

    {:ok,
     socket
     |> assign(:page_title, "Posts")
     |> assign(:posts_empty?, posts == [])
     |> assign(:total_count, stats.total)
     |> assign(:total_views, stats.total_views)
     |> stream(:posts, posts)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Posts.get_post!(id)
    {:ok, _} = Posts.delete_post(post)

    # Recalculate stats after deletion
    posts = Posts.list_posts()
    stats = calculate_stats(posts)

    {:noreply,
     socket
     |> assign(:posts_empty?, posts == [])
     |> assign(:total_count, stats.total)
     |> assign(:total_views, stats.total_views)
     |> stream_delete(:posts, post)}
  end

  defp calculate_stats(posts) do
    Enum.reduce(posts, %{total: 0, total_views: 0}, fn post, acc ->
      acc
      |> Map.update!(:total, &(&1 + 1))
      |> Map.update!(:total_views, &(&1 + (post.views || 0)))
    end)
  end

  defp format_views(views) when is_integer(views) and views >= 1000 do
    "#{Float.round(views / 1000, 1)}k"
  end

  defp format_views(views), do: "#{views || 0}"
end
