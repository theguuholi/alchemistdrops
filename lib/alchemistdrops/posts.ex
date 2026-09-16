defmodule Alchemistdrops.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Alchemistdrops.Repo

  alias Alchemistdrops.Posts.Post

  @doc """
  Returns the list of published posts ordered by most recent.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Post
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Increments the view count for a post.

  ## Examples

      iex> increment_views(post)
      {:ok, %Post{}}

  """
  def increment_views(%Post{} = post) do
    post
    |> Ecto.Changeset.change(views: post.views + 1)
    |> Repo.update()
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Gets a single post by slug.

  Raises `Ecto.NoResultsError` if the Post does not exist.
  """
  def get_post_by_slug!(slug), do: Repo.get_by!(Post, slug: slug)

  @doc """
  Gets a single post by slug.

  Returns `nil` if the Post does not exist.
  """
  def get_post_by_slug(slug), do: Repo.get_by(Post, slug: slug)

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end
end
