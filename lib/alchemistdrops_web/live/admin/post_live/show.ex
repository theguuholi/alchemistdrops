defmodule AlchemistdropsWeb.Admin.PostLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Post {@post.id}
        <:subtitle>This is a post record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/posts"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/posts/#{@post}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit post
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Background">{@post.background}</:item>
        <:item title="Title">{@post.title}</:item>
        <:item title="Body">{@post.body}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Post")
     |> assign(:post, Posts.get_post!(id))}
  end
end
