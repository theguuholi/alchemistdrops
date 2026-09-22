defmodule AlchemistdropsWeb.Admin.PostLive.Index do
  use AlchemistdropsWeb, :live_view

  require Logger

  alias Alchemistdrops.Posts

  @impl true
  def mount(_params, _session, socket) do
    posts = Posts.list_admin_posts()
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
    posts = Posts.list_admin_posts()

    stats = calculate_stats(posts)

    {:noreply,
     socket
     |> assign(:posts_empty?, posts == [])
     |> assign(:total_count, stats.total)
     |> assign(:total_views, stats.total_views)
     |> stream_delete(:posts, post)}
  end

  def handle_event("publish-dev-to", %{"id" => id}, socket) do
    post = Posts.get_admin_post!(id)
    canonical_url = url(~p"/blog/#{post.slug}")

    case Posts.publish_to_dev(post, canonical_url) do
      {:ok, _post} ->
        {:noreply, put_flash(socket, :info, "Article published on DEV.to")}

      {:error, reason} ->
        Logger.error("Failed to publish post #{post.id} to DEV.to: #{inspect(reason)}")

        {:noreply, put_flash(socket, :error, "Could not publish article on DEV.to")}
    end
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

  defp status_label(%{status: :published}), do: "Published"
  defp status_label(_post), do: "Draft"

  defp format_publication_date(nil), do: "Not published"
  defp format_publication_date(date), do: Calendar.strftime(date, "%b %-d, %Y")
end
