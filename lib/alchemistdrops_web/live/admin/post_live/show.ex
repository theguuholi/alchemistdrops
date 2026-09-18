defmodule AlchemistdropsWeb.Admin.PostLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Post")
     |> assign(:post, Posts.get_post!(id))}
  end
end
