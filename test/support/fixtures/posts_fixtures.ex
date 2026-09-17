defmodule Alchemistdrops.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Alchemistdrops.Posts` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    category_id = Map.get(attrs, :category_id) || category_fixture().id

    {:ok, post} =
      attrs
      |> Enum.into(%{
        background: "some background",
        body: "some body",
        category_id: category_id,
        summary: "A concise article summary",
        title: "some title",
        views: 42,
        status: :published
      })
      |> Alchemistdrops.Posts.create_post()

    published_at = DateTime.utc_now() |> DateTime.truncate(:second)

    post
    |> Ecto.Changeset.change(published_at: published_at)
    |> Alchemistdrops.Repo.update!()
  end

  @doc """
  Generate a draft post.
  """
  def draft_post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        background: "some background",
        title: "draft #{System.unique_integer([:positive])}",
        views: 0,
        status: :draft
      })
      |> Alchemistdrops.Posts.create_post()

    post
  end

  @doc """
  Generate a post category.
  """
  def category_fixture(attrs \\ %{}) do
    sequence = System.unique_integer([:positive])

    %Alchemistdrops.Posts.Category{}
    |> Alchemistdrops.Posts.Category.changeset(Enum.into(attrs, %{name: "Category #{sequence}"}))
    |> Alchemistdrops.Repo.insert!()
  end

  @doc """
  Generate a post tag.
  """
  def tag_fixture(attrs \\ %{}) do
    sequence = System.unique_integer([:positive])

    %Alchemistdrops.Posts.Tag{}
    |> Alchemistdrops.Posts.Tag.changeset(Enum.into(attrs, %{name: "Tag #{sequence}"}))
    |> Alchemistdrops.Repo.insert!()
  end
end
