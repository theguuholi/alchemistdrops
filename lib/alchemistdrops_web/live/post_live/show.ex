defmodule AlchemistdropsWeb.PostLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts
  alias AlchemistdropsWeb.PostLive.Presenter

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    page = Posts.get_published_post_page!(slug)

    if page.post.slug != slug do
      {:ok, push_navigate(socket, to: ~p"/blog/#{page.post.slug}")}
    else
      mount_post(socket, page)
    end
  end

  defp mount_post(socket, %{post: post} = page) do
    if connected?(socket), do: Posts.increment_views(post)

    {:ok, assign(socket, Presenter.show(page))}
  end

  defp format_date(datetime), do: Calendar.strftime(datetime, "%B %d, %Y")
end
