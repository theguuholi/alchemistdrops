defmodule Alchemistdrops.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Alchemistdrops.Posts.{Category, Post, Tag}
  alias Alchemistdrops.Repo
  alias Ecto.Multi

  @public_preloads [:category, :tags, :related_course]
  @default_page_size 12
  @max_page_size 50

  @type published_page :: %{
          posts: [Post.t()],
          categories: [map()],
          tags: [map()],
          selected_category: String.t() | nil,
          selected_tag: String.t() | nil,
          current_page: pos_integer(),
          has_next_page?: boolean()
        }

  @type published_post_page :: %{
          post: Post.t(),
          related_course: struct() | nil,
          related_posts: [Post.t()]
        }

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

  def list_admin_posts do
    Post
    |> order_by([p], desc: p.inserted_at)
    |> preload(^@public_preloads)
    |> Repo.all()
  end

  def list_categories do
    Category
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def get_admin_post!(id) do
    Post
    |> Repo.get!(id)
    |> Repo.preload(@public_preloads)
  end

  def list_published_posts(opts \\ []) do
    page = positive_integer(Keyword.get(opts, :page), 1)

    page_size =
      Keyword.get(opts, :page_size) |> positive_integer(@default_page_size) |> min(@max_page_size)

    published_query()
    |> maybe_filter_category(Keyword.get(opts, :category))
    |> maybe_filter_tag(Keyword.get(opts, :tag))
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
  end

  @doc """
  Returns one public blog page with URL filters normalized against published taxonomy.

  The result includes a one-record lookahead as `has_next_page?`, while `posts`
  contains at most the requested page size.
  """
  @spec list_published_page(map(), keyword()) :: published_page()
  def list_published_page(params, opts \\ []) when is_map(params) do
    page_size =
      Keyword.get(opts, :page_size, @default_page_size)
      |> positive_integer(1)
      |> min(@max_page_size)

    categories = list_categories_with_published_counts()
    tags = list_tags_with_published_counts()
    category = known_taxonomy_slug(params["category"], categories, :category)
    tag = known_taxonomy_slug(params["tag"], tags, :tag)
    page = positive_integer(params["page"], 1)

    posts =
      list_published_posts(
        page: page,
        page_size: page_size + 1,
        category: category,
        tag: tag
      )

    %{
      posts: Enum.take(posts, page_size),
      categories: categories,
      tags: tags,
      selected_category: category,
      selected_tag: tag,
      current_page: page,
      has_next_page?: length(posts) > page_size
    }
  end

  def list_recent_published_posts(limit) when is_integer(limit) and limit > 0 do
    published_query()
    |> limit(^limit)
    |> Repo.all()
  end

  def list_all_published_posts do
    published_query()
    |> Repo.all()
  end

  def list_categories_with_published_counts do
    from(c in Category,
      join: p in assoc(c, :posts),
      where: p.status == :published and not is_nil(p.published_at),
      group_by: c.id,
      order_by: c.name,
      select: %{category: c, published_count: count(p.id)}
    )
    |> Repo.all()
  end

  def list_tags_with_published_counts do
    from(t in Tag,
      join: p in assoc(t, :posts),
      where: p.status == :published and not is_nil(p.published_at),
      group_by: t.id,
      order_by: t.name,
      select: %{tag: t, published_count: count(p.id)}
    )
    |> Repo.all()
  end

  def list_related_posts(%Post{} = post, limit) when is_integer(limit) and limit > 0 do
    post = Repo.preload(post, [:tags])
    tag_ids = Enum.map(post.tags, & &1.id)

    shared_tags =
      if tag_ids == [] do
        []
      else
        published_query()
        |> join(:inner, [p], t in assoc(p, :tags))
        |> where([p, t], p.id != ^post.id and t.id in ^tag_ids)
        |> distinct(true)
        |> limit(^limit)
        |> Repo.all()
      end

    remaining = limit - length(shared_tags)

    same_category =
      if remaining > 0 and post.category_id do
        excluded_ids = [post.id | Enum.map(shared_tags, & &1.id)]

        published_query()
        |> where([p], p.category_id == ^post.category_id and p.id not in ^excluded_ids)
        |> limit(^remaining)
        |> Repo.all()
      else
        []
      end

    shared_tags ++ same_category
  end

  @doc """
  Increments the view count for a post.

  ## Examples

      iex> increment_views(post)
      {:ok, %Post{}}

  """
  def increment_views(%Post{} = post) do
    case from(p in Post, where: p.id == ^post.id) |> Repo.update_all(inc: [views: 1]) do
      {1, _rows} -> {:ok, Repo.get!(Post, post.id)}
      {0, _rows} -> {:error, :not_found}
    end
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

  def get_published_post_by_slug!(slug) do
    published_query()
    |> where([p], p.slug == ^slug)
    |> Repo.one!()
  end

  def get_published_post_by_slug(slug) do
    published_query()
    |> where([p], p.slug == ^slug)
    |> Repo.one()
  end

  def get_published_post_by_id!(id) do
    published_query()
    |> where([p], p.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Loads the public data for a post detail page by canonical slug or legacy UUID.

  Canonical slugs take precedence even when the slug itself has UUID syntax.
  """
  @spec get_published_post_page!(String.t()) :: published_post_page()
  def get_published_post_page!(identifier) when is_binary(identifier) do
    post =
      case get_published_post_by_slug(identifier) do
        nil -> get_published_post_by_legacy_id!(identifier)
        post -> post
      end

    %{
      post: post,
      related_course: published_related_course(post.related_course),
      related_posts: list_related_posts(post, 3)
    }
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs) do
    with {:ok, tag_names} <- validate_tag_names(attrs) do
      Multi.new()
      |> Multi.run(:category, fn repo, _changes -> resolve_category(repo, attrs) end)
      |> Multi.run(:tags, fn repo, _changes -> resolve_tags(repo, attrs, tag_names) end)
      |> Multi.insert(:post, fn %{category: category, tags: tags} ->
        %Post{}
        |> Post.draft_changeset(force_status(attrs, :draft))
        |> maybe_put_assoc(:category, category)
        |> maybe_put_assoc(:tags, tags)
      end)
      |> Repo.transaction()
      |> transaction_result(:post)
    end
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
    with {:ok, tag_names} <- validate_tag_names(attrs) do
      post = Repo.preload(post, [:category, :tags])

      Multi.new()
      |> Multi.run(:category, fn repo, _changes -> resolve_category(repo, attrs) end)
      |> Multi.run(:tags, fn repo, _changes -> resolve_tags(repo, attrs, tag_names) end)
      |> Multi.update(:post, fn %{category: category, tags: tags} ->
        post
        |> update_changeset(attrs)
        |> maybe_put_assoc(:category, category)
        |> maybe_put_assoc(:tags, tags)
      end)
      |> Repo.transaction()
      |> transaction_result(:post)
    end
  end

  def publish_post(%Post{} = post) do
    published_at = post.published_at || DateTime.utc_now() |> DateTime.truncate(:second)

    post
    |> Repo.preload([:category, :tags, :related_course])
    |> Post.publish_changeset(%{})
    |> Ecto.Changeset.put_change(:published_at, published_at)
    |> Repo.update()
  end

  def unpublish_post(%Post{} = post) do
    post
    |> Ecto.Changeset.change(status: :draft)
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
    update_changeset(post, attrs)
  end

  defp published_query do
    from(p in Post,
      where: p.status == :published and not is_nil(p.published_at),
      order_by: [desc: p.published_at, desc: p.id],
      preload: ^@public_preloads
    )
  end

  defp maybe_filter_category(query, value) when is_binary(value) and value != "" do
    from(p in query,
      join: c in assoc(p, :category),
      where: c.slug == ^value
    )
  end

  defp maybe_filter_category(query, _value), do: query

  defp maybe_filter_tag(query, value) when is_binary(value) and value != "" do
    from(p in query,
      join: t in assoc(p, :tags),
      where: t.slug == ^value,
      distinct: true
    )
  end

  defp maybe_filter_tag(query, _value), do: query

  defp known_taxonomy_slug(nil, _items, _key), do: nil

  defp known_taxonomy_slug(value, items, key) do
    if Enum.any?(items, &(Map.fetch!(&1, key).slug == value)), do: value
  end

  defp get_published_post_by_legacy_id!(identifier) do
    case Ecto.UUID.cast(identifier) do
      {:ok, id} -> get_published_post_by_id!(id)
      :error -> get_published_post_by_slug!(identifier)
    end
  end

  defp published_related_course(%{published: true} = course), do: course
  defp published_related_course(_course), do: nil

  defp update_changeset(%Post{status: :published} = post, attrs),
    do: Post.publish_changeset(post, attrs)

  defp update_changeset(post, attrs), do: Post.draft_changeset(post, attrs)

  defp validate_tag_names(attrs) do
    names = normalize_tag_names(attr(attrs, :tag_names))

    if length(names) <= 5 do
      {:ok, names}
    else
      changeset =
        %Post{}
        |> Post.draft_changeset(force_status(attrs, :draft))
        |> Ecto.Changeset.add_error(:tags, "must contain at most 5 tags")

      {:error, changeset}
    end
  end

  defp resolve_category(repo, attrs) do
    if attr_present?(attrs, :category_name) do
      case attr(attrs, :category_name) |> to_string() |> String.trim() do
        "" -> {:ok, nil}
        name -> find_or_create_category(repo, name)
      end
    else
      {:ok, :unchanged}
    end
  end

  defp find_or_create_category(repo, name) do
    query = from c in Category, where: fragment("lower(?)", c.name) == ^String.downcase(name)

    case repo.one(query) do
      nil -> %Category{} |> Category.changeset(%{name: name}) |> repo.insert()
      category -> {:ok, category}
    end
  end

  defp resolve_tags(repo, attrs, tag_names) do
    if attr_present?(attrs, :tag_names) do
      resolve_tag_names(repo, tag_names)
    else
      {:ok, :unchanged}
    end
  end

  defp resolve_tag_names(repo, tag_names) do
    tag_names
    |> Enum.reduce_while({:ok, []}, &resolve_tag_name(repo, &1, &2))
    |> reverse_resolved_tags()
  end

  defp resolve_tag_name(repo, name, {:ok, tags}) do
    case find_or_create_tag(repo, name) do
      {:ok, tag} -> {:cont, {:ok, [tag | tags]}}
      {:error, changeset} -> {:halt, {:error, changeset}}
    end
  end

  defp reverse_resolved_tags({:ok, tags}), do: {:ok, Enum.reverse(tags)}
  defp reverse_resolved_tags(error), do: error

  defp find_or_create_tag(repo, name) do
    query = from t in Tag, where: fragment("lower(?)", t.name) == ^String.downcase(name)

    case repo.one(query) do
      nil -> %Tag{} |> Tag.changeset(%{name: name}) |> repo.insert()
      tag -> {:ok, tag}
    end
  end

  defp normalize_tag_names(nil), do: []

  defp normalize_tag_names(value) do
    value
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp maybe_put_assoc(changeset, _association, :unchanged), do: changeset

  defp maybe_put_assoc(changeset, association, value),
    do: Ecto.Changeset.put_assoc(changeset, association, value)

  defp force_status(attrs, status) do
    if Enum.any?(Map.keys(attrs), &is_binary/1) do
      Map.put(attrs, "status", Atom.to_string(status))
    else
      Map.put(attrs, :status, status)
    end
  end

  defp attr(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp attr_present?(attrs, key),
    do: Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))

  defp transaction_result({:ok, changes}, key), do: {:ok, Map.fetch!(changes, key)}
  defp transaction_result({:error, _step, reason, _changes}, _key), do: {:error, reason}

  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _invalid -> default
    end
  end

  defp positive_integer(_value, default), do: default
end
