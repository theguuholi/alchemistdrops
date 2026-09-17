defmodule Alchemistdrops.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Alchemistdrops.Posts` context.
  """

  alias Alchemistdrops.Posts.{Category, Post, Tag}
  alias Alchemistdrops.Repo

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    category_id = Map.get(attrs, :category_id) || category_fixture().id

    {:ok, draft} =
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

    {:ok, post} = Alchemistdrops.Posts.publish_post(draft)
    Repo.get!(Post, post.id)
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

    %Category{}
    |> Category.changeset(Enum.into(attrs, %{name: "Category #{sequence}"}))
    |> Repo.insert!()
  end

  @doc """
  Generate a post tag.
  """
  def tag_fixture(attrs \\ %{}) do
    sequence = System.unique_integer([:positive])

    %Tag{}
    |> Tag.changeset(Enum.into(attrs, %{name: "Tag #{sequence}"}))
    |> Repo.insert!()
  end
end
