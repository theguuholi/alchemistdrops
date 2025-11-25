defmodule Alchemistdrops.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Alchemistdrops.Posts` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        background: "some background",
        body: "some body",
        title: "some title",
        views: 42
      })
      |> Alchemistdrops.Posts.create_post()

    post
  end
end
