defmodule Alchemistdrops.Posts do
  @moduledoc """
  Owns the editorial lifecycle and public discovery of blog posts.

  This context keeps drafts private, publication requirements consistent, and
  category/tag creation transactional. Public pages and admin tools use this
  boundary instead of constructing Ecto queries or editorial rules themselves.
  """

  import Ecto.Query, warn: false

  alias Alchemistdrops.Courses.Course
  alias Alchemistdrops.Posts.{Category, DevToPublisher, Post, Tag}
  alias Alchemistdrops.Repo
  alias Ecto.Multi

  @public_preloads [:category, :tags, :related_course]
  @default_page_size 12
  @max_page_size 50

  @typedoc "A normalized page of published posts and its URL-driven taxonomy state."
  @type published_page :: %{
          posts: [Post.t()],
          categories: [map()],
          tags: [map()],
          selected_category: String.t() | nil,
          selected_tag: String.t() | nil,
          current_page: pos_integer(),
          has_next_page?: boolean()
        }

  @typedoc "The post, optional published course, and related articles used by a public detail page."
  @type published_post_page :: %{
          post: Post.t(),
          related_course: Course.t() | nil,
          related_posts: [Post.t()]
        }

  @doc """
  Returns all posts ordered by most recently inserted.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Enum.map(Alchemistdrops.Posts.list_posts(), & &1.id)
      [post.id]

  """
  @spec list_posts() :: [Post.t()]
  def list_posts do
    Post
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns every post for administration with public associations preloaded.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.draft_post_fixture()
      iex> [loaded] = Alchemistdrops.Posts.list_admin_posts()
      iex> {loaded.id == post.id, Ecto.assoc_loaded?(loaded.category), Ecto.assoc_loaded?(loaded.tags)}
      {true, true, true}
  """
  @spec list_admin_posts() :: [Post.t()]
  def list_admin_posts do
    Post
    |> order_by([p], desc: p.inserted_at)
    |> preload(^@public_preloads)
    |> Repo.all()
  end

  @doc """
  Returns post categories ordered by name.

  ## Examples

      iex> category = Alchemistdrops.PostsFixtures.category_fixture(%{name: "Elixir"})
      iex> Enum.map(Alchemistdrops.Posts.list_categories(), & &1.id)
      [category.id]
  """
  @spec list_categories() :: [Category.t()]
  def list_categories do
    Category
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Loads one post with all associations required by the admin editor.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Alchemistdrops.Posts.get_admin_post!(post.id).id == post.id
      true
  """
  @spec get_admin_post!(Ecto.UUID.t()) :: Post.t()
  def get_admin_post!(id) do
    Post
    |> Repo.get!(id)
    |> Repo.preload(@public_preloads)
  end

  @doc """
  Returns published posts with optional page, page-size, category, and tag filters.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Enum.map(Alchemistdrops.Posts.list_published_posts(page_size: 1), & &1.id)
      [post.id]
  """
  @spec list_published_posts() :: [Post.t()]
  @spec list_published_posts(keyword()) :: [Post.t()]
  def list_published_posts(opts \\ []) do
    page = positive_integer(Keyword.get(opts, :page), 1)

    page_size =
      opts
      |> Keyword.get(:page_size)
      |> positive_integer(@default_page_size)
      |> min(@max_page_size)

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

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> page = Alchemistdrops.Posts.list_published_page(%{}, page_size: 1)
      iex> {Enum.map(page.posts, & &1.id), page.current_page, page.has_next_page?}
      {[post.id], 1, false}
  """
  @spec list_published_page(map()) :: published_page()
  @spec list_published_page(map(), keyword()) :: published_page()
  def list_published_page(params, opts \\ []) when is_map(params) do
    page_size =
      opts
      |> Keyword.get(:page_size, @default_page_size)
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

  @doc """
  Returns up to `limit` recent published posts.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Enum.map(Alchemistdrops.Posts.list_recent_published_posts(1), & &1.id)
      [post.id]
  """
  @spec list_recent_published_posts(pos_integer()) :: [Post.t()]
  def list_recent_published_posts(limit) when is_integer(limit) and limit > 0 do
    published_query()
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns every published post without pagination.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Enum.map(Alchemistdrops.Posts.list_all_published_posts(), & &1.id)
      [post.id]
  """
  @spec list_all_published_posts() :: [Post.t()]
  def list_all_published_posts do
    published_query()
    |> Repo.all()
  end

  @doc """
  Returns categories that have published posts together with their counts.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> [%{category: category, published_count: 1}] = Alchemistdrops.Posts.list_categories_with_published_counts()
      iex> category.id == post.category_id
      true
  """
  @spec list_categories_with_published_counts() ::
          [%{category: Category.t(), published_count: non_neg_integer()}]
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

  @doc """
  Returns tags that have published posts together with their counts.

  ## Examples

      iex> _post = Alchemistdrops.PostsFixtures.post_fixture(%{tag_names: "OTP"})
      iex> [%{tag: tag, published_count: 1}] = Alchemistdrops.Posts.list_tags_with_published_counts()
      iex> tag.name
      "OTP"
  """
  @spec list_tags_with_published_counts() ::
          [%{tag: Tag.t(), published_count: non_neg_integer()}]
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

  @doc """
  Returns published posts related by shared tags and then category.

  ## Examples

      iex> category = Alchemistdrops.PostsFixtures.category_fixture(%{name: "Architecture"})
      iex> current = Alchemistdrops.PostsFixtures.post_fixture(%{title: "Current", category_id: category.id})
      iex> related = Alchemistdrops.PostsFixtures.post_fixture(%{title: "Related", category_id: category.id})
      iex> Enum.map(Alchemistdrops.Posts.list_related_posts(current, 1), & &1.id)
      [related.id]
  """
  @spec list_related_posts(Post.t(), pos_integer()) :: [Post.t()]
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

      iex> post = Alchemistdrops.PostsFixtures.post_fixture(%{views: 4})
      iex> {:ok, updated} = Alchemistdrops.Posts.increment_views(post)
      iex> updated.views
      5

  """
  @spec increment_views(Post.t()) :: {:ok, Post.t()} | {:error, :not_found}
  def increment_views(%Post{} = post) do
    from(p in Post, where: p.id == ^post.id)
    |> Repo.update_all(inc: [views: 1])
    |> case do
      {1, _rows} -> {:ok, Repo.get!(Post, post.id)}
      {0, _rows} -> {:error, :not_found}
    end
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Alchemistdrops.Posts.get_post!(post.id).id == post.id
      true

  """
  @spec get_post!(Ecto.UUID.t()) :: Post.t()
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Gets a single post by slug.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture(%{title: "Slug lookup"})
      iex> Alchemistdrops.Posts.get_post_by_slug!(post.slug).id == post.id
      true
  """
  @spec get_post_by_slug!(String.t()) :: Post.t()
  def get_post_by_slug!(slug), do: Repo.get_by!(Post, slug: slug)

  @doc """
  Gets a single post by slug.

  Returns `nil` if the Post does not exist.

  ## Examples

      iex> Alchemistdrops.Posts.get_post_by_slug("missing")
      nil
  """
  @spec get_post_by_slug(String.t()) :: Post.t() | nil
  def get_post_by_slug(slug), do: Repo.get_by(Post, slug: slug)

  @doc """
  Loads a published post by slug and raises when it is not public.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture(%{title: "Public slug"})
      iex> Alchemistdrops.Posts.get_published_post_by_slug!(post.slug).id == post.id
      true
  """
  @spec get_published_post_by_slug!(String.t()) :: Post.t()
  def get_published_post_by_slug!(slug) do
    published_query()
    |> where([p], p.slug == ^slug)
    |> Repo.one!()
  end

  @doc """
  Loads a published post by slug or returns `nil`.

  ## Examples

      iex> Alchemistdrops.Posts.get_published_post_by_slug("missing")
      nil
  """
  @spec get_published_post_by_slug(String.t()) :: Post.t() | nil
  def get_published_post_by_slug(slug) do
    published_query()
    |> where([p], p.slug == ^slug)
    |> Repo.one()
  end

  @doc """
  Loads a published post by UUID and raises when it is not public.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> Alchemistdrops.Posts.get_published_post_by_id!(post.id).id == post.id
      true
  """
  @spec get_published_post_by_id!(Ecto.UUID.t()) :: Post.t()
  def get_published_post_by_id!(id) do
    published_query()
    |> where([p], p.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Loads the public data for a post detail page by canonical slug or legacy UUID.

  Canonical slugs take precedence even when the slug itself has UUID syntax.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> page = Alchemistdrops.Posts.get_published_post_page!(post.slug)
      iex> page.post.id == post.id
      true
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

      iex> {:ok, post} = Alchemistdrops.Posts.create_post(%{title: "Draft"})
      iex> {post.title, post.status}
      {"Draft", :draft}

      iex> {:error, changeset} = Alchemistdrops.Posts.create_post(%{})
      iex> changeset.valid?
      false

  """
  @spec create_post(map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
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

      iex> post = Alchemistdrops.PostsFixtures.draft_post_fixture()
      iex> {:ok, updated} = Alchemistdrops.Posts.update_post(post, %{title: "Updated draft"})
      iex> updated.title
      "Updated draft"

  """
  @spec update_post(Post.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
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

  @doc """
  Publishes a complete draft and records its first publication timestamp.

  ## Examples

      iex> draft = Alchemistdrops.PostsFixtures.draft_post_fixture(%{body: "Body", summary: "Summary"})
      iex> category = Alchemistdrops.PostsFixtures.category_fixture()
      iex> {:ok, ready} = Alchemistdrops.Posts.update_post(draft, %{category_id: category.id})
      iex> {:ok, published} = Alchemistdrops.Posts.publish_post(ready)
      iex> {published.status, is_struct(published.published_at, DateTime)}
      {:published, true}
  """
  @spec publish_post(Post.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def publish_post(%Post{} = post) do
    published_at = post.published_at || DateTime.utc_now() |> DateTime.truncate(:second)

    post
    |> Repo.preload([:category, :tags, :related_course])
    |> Post.publish_changeset(%{})
    |> Ecto.Changeset.put_change(:published_at, published_at)
    |> Repo.update()
  end

  @doc """
  Publishes or updates a locally published post on DEV.to and records its remote identity.

  The canonical URL must point to the public AlchemistDrops article. DEV.to API
  failures are returned without changing the stored remote identity.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.draft_post_fixture(%{title: "DEV.to doctest"})
      iex> Alchemistdrops.Posts.publish_to_dev(post, "https://alchemistdrops.com/blog/example")
      {:error, :post_not_published}
  """
  @spec publish_to_dev(Post.t(), String.t()) ::
          {:ok, Post.t()} | {:error, DevToPublisher.error_reason() | Ecto.Changeset.t()}
  def publish_to_dev(%Post{} = post, canonical_url) do
    fn -> sync_locked_post_to_dev(post.id, canonical_url) end
    |> Repo.transaction()
    |> case do
      {:ok, synchronized} -> {:ok, synchronized}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync_locked_post_to_dev(post_id, canonical_url) do
    post =
      Post
      |> where([persisted], persisted.id == ^post_id)
      |> lock("FOR UPDATE")
      |> Repo.one!()
      |> Repo.preload([:tags])

    case DevToPublisher.sync_article(post, canonical_url) do
      {:ok, remote_article} -> persist_dev_to_publication(post, remote_article)
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp persist_dev_to_publication(post, %{article_id: article_id, article_url: article_url}) do
    post
    |> Post.dev_to_publication_changeset(article_id, article_url)
    |> Repo.update()
    |> case do
      {:ok, synchronized} -> synchronized
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @doc """
  Returns a published post to draft state without deleting its content.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.post_fixture()
      iex> {:ok, draft} = Alchemistdrops.Posts.unpublish_post(post)
      iex> draft.status
      :draft
  """
  @spec unpublish_post(Post.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def unpublish_post(%Post{} = post) do
    post
    |> Ecto.Changeset.change(status: :draft)
    |> Repo.update()
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> post = Alchemistdrops.PostsFixtures.draft_post_fixture()
      iex> {:ok, deleted} = Alchemistdrops.Posts.delete_post(post)
      iex> deleted.id == post.id
      true

  """
  @spec delete_post(Post.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> changeset = Alchemistdrops.Posts.change_post(%Alchemistdrops.Posts.Post{})
      iex> match?(%Ecto.Changeset{}, changeset)
      true

  """
  @spec change_post(Post.t()) :: Ecto.Changeset.t()
  @spec change_post(Post.t(), map()) :: Ecto.Changeset.t()
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
      attrs
      |> attr(:category_name)
      |> to_string()
      |> String.trim()
      |> case do
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
