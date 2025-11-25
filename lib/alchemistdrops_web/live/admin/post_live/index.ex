defmodule AlchemistdropsWeb.Admin.PostLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Posts
        <:actions>
          <.button variant="primary" navigate={~p"/admin/posts/new"}>
            <.icon name="hero-plus" /> New Post
          </.button>
        </:actions>
      </.header>

      <.table
        id="posts"
        rows={@streams.posts}
        row_click={fn {_id, post} -> JS.navigate(~p"/admin/posts/#{post}") end}
      >
        <:col :let={{_id, post}} label="Background">{post.background}</:col>
        <:col :let={{_id, post}} label="Title">{post.title}</:col>
        <:col :let={{_id, post}} label="Body">{post.body}</:col>
        <:col :let={{_id, post}} label="Views">{post.views}</:col>
        <:action :let={{_id, post}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/posts/#{post}"}>Show</.link>
          </div>
          <.link navigate={~p"/admin/posts/#{post}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, post}}>
          <.link
            phx-click={JS.push("delete", value: %{id: post.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Posts")
     |> stream(:posts, list_posts())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Posts.get_post!(id)
    {:ok, _} = Posts.delete_post(post)

    {:noreply, stream_delete(socket, :posts, post)}
  end

  defp list_posts do
    Posts.list_posts()
  end
end
