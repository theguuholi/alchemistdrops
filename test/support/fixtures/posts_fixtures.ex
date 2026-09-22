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
    attrs = Map.new(attrs)

    category_attrs =
      if Map.has_key?(attrs, :category_name) do
        %{}
      else
        %{category_id: Map.get(attrs, :category_id) || category_fixture().id}
      end

    {:ok, draft} =
      attrs
      |> Enum.into(%{
        background: "some background",
        body: "some body",
        summary: "A concise article summary",
        title: "some title",
        views: 42,
        status: :published
      })
      |> Map.merge(category_attrs)
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
  Generate a published post without a category, matching legacy data.
  """
  def legacy_post_without_category_fixture(attrs \\ %{}) do
    post = post_fixture(attrs)

    post
    |> Ecto.Changeset.change(category_id: nil)
    |> Repo.update!()
  end

  @doc """
  Update a post for test setup.
  """
  def update_post_fixture(post, attrs) do
    {:ok, post} = Alchemistdrops.Posts.update_post(post, attrs)
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
