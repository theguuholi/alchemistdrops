defmodule Alchemistdrops.Posts.Post do
  @moduledoc """
  Represents an editorial article throughout its draft and published lifecycle.

  Posts own the content, SEO metadata, taxonomy, publication state, and optional
  course relationship rendered by the public blog. Separate draft and publish
  changesets keep incomplete editorial work private until it is ready.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Alchemistdrops.Posts.Slug

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Editorial publication state of a post."
  @type status :: :draft | :published

  @typedoc "Language used by article content and localized public copy."
  @type language :: :en | :pt_br

  @typedoc "Database identifier for the post. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "CSS background value used by the post presentation. Nil when unavailable."
  @type background :: String.t() | nil

  @typedoc "Editorial post title. Nil before validation."
  @type title :: String.t() | nil

  @typedoc "URL-safe post identifier. Nil before slug generation."
  @type slug :: String.t() | nil

  @typedoc "Long-form article content. Nil while an incomplete draft is being edited."
  @type body :: String.t() | nil

  @typedoc "Recorded number of post views. Nil for legacy or incomplete data."
  @type views :: integer() | nil

  @typedoc "Timestamp when the post became public. Nil while it remains a draft."
  @type published_at :: DateTime.t() | nil

  @typedoc "Short article summary. Nil while an incomplete draft is being edited."
  @type summary :: String.t() | nil

  @typedoc "Search-engine title override. Nil when the article title should be used."
  @type seo_title :: String.t() | nil

  @typedoc "Search-engine description override. Nil when unavailable."
  @type seo_description :: String.t() | nil

  @typedoc "Absolute HTTPS URL for the cover image. Nil when no cover is configured."
  @type cover_image_url :: String.t() | nil

  @typedoc "Accessible alternative text for the cover image. Nil when no cover is configured."
  @type cover_image_alt :: String.t() | nil

  @typedoc "Numeric DEV.to article identifier. Nil until the first successful cross-publication."
  @type dev_to_article_id :: pos_integer() | nil

  @typedoc "Public DEV.to article URL. Nil until returned by a successful synchronization."
  @type dev_to_article_url :: String.t() | nil

  @typedoc "Category name supplied by editorial forms. Nil when a category ID is used."
  @type category_name :: String.t() | nil

  @typedoc "Identifier of the post's category. Nil while an incomplete draft is being edited."
  @type category_id :: Ecto.UUID.t() | nil

  @typedoc "Identifier of the course promoted by the post. Nil when no course is related."
  @type related_course_id :: Ecto.UUID.t() | nil

  @typedoc "Timestamp when the post was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the post was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A post before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          background: background(),
          title: title(),
          slug: slug(),
          body: body(),
          views: views(),
          status: status(),
          published_at: published_at(),
          summary: summary(),
          seo_title: seo_title(),
          seo_description: seo_description(),
          cover_image_url: cover_image_url(),
          cover_image_alt: cover_image_alt(),
          dev_to_article_id: dev_to_article_id(),
          dev_to_article_url: dev_to_article_url(),
          language: language(),
          category_name: category_name(),
          category_id: category_id(),
          related_course_id: related_course_id(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

  schema "posts" do
    field :background, :string, default: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
    field :title, :string
    field :slug, :string
    field :body, :string
    field :views, :integer, default: 0
    field :status, Ecto.Enum, values: [:draft, :published], default: :draft
    field :published_at, :utc_datetime
    field :summary, :string
    field :seo_title, :string
    field :seo_description, :string
    field :cover_image_url, :string
    field :cover_image_alt, :string
    field :dev_to_article_id, :integer
    field :dev_to_article_url, :string
    field :language, Ecto.Enum, values: [en: "en", pt_br: "pt-BR"], default: :en
    field :category_name, :string, virtual: true

    belongs_to :category, Alchemistdrops.Posts.Category
    belongs_to :related_course, Alchemistdrops.Courses.Course

    many_to_many :tags, Alchemistdrops.Posts.Tag,
      join_through: "posts_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds the default draft changeset.

  This is equivalent to `draft_changeset/2` and does not require publish-only
  content such as the body, summary, or category.

  ## Examples

      iex> changeset = Alchemistdrops.Posts.Post.changeset(%Alchemistdrops.Posts.Post{}, %{title: "Hello OTP"})
      iex> {changeset.valid?, changeset.changes.slug}
      {true, "hello-otp"}
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
  def changeset(post, attrs), do: draft_changeset(post, attrs)

  @doc """
  Builds a draft changeset with generated slug and editorial metadata validation.

  ## Examples

      iex> changeset = Alchemistdrops.Posts.Post.draft_changeset(%Alchemistdrops.Posts.Post{}, %{title: "Draft Article"})
      iex> {Ecto.Changeset.get_field(changeset, :status), changeset.changes.slug}
      {:draft, "draft-article"}
  """
  @spec draft_changeset(t(), map()) :: Ecto.Changeset.t(t())
  def draft_changeset(post, attrs) do
    post
    |> cast(attrs, [
      :background,
      :title,
      :slug,
      :body,
      :views,
      :status,
      :summary,
      :seo_title,
      :seo_description,
      :cover_image_url,
      :cover_image_alt,
      :language,
      :category_name,
      :category_id,
      :related_course_id
    ])
    |> put_generated_slug()
    |> validate_required([:title, :slug, :views, :status, :language])
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_length(:summary, max: 240)
    |> validate_length(:seo_title, max: 60)
    |> validate_length(:seo_description, max: 160)
    |> validate_cover_url()
    |> validate_cover_alt()
    |> unique_constraint(:slug)
  end

  @doc """
  Builds a publish changeset and requires complete body, summary, and category data.

  ## Examples

      iex> attrs = %{title: "Published Article", body: "Body", summary: "Summary", category_name: "Elixir"}
      iex> changeset = Alchemistdrops.Posts.Post.publish_changeset(%Alchemistdrops.Posts.Post{}, attrs)
      iex> {changeset.valid?, Ecto.Changeset.get_field(changeset, :status)}
      {true, :published}

      iex> Alchemistdrops.Posts.Post.publish_changeset(%Alchemistdrops.Posts.Post{}, %{title: "Incomplete"}).valid?
      false
  """
  @spec publish_changeset(t(), map()) :: Ecto.Changeset.t(t())
  def publish_changeset(post, attrs) do
    post
    |> draft_changeset(put_status(attrs, :published))
    |> validate_required([:body, :summary])
    |> validate_category()
  end

  @doc """
  Builds the trusted changeset that records a successful DEV.to synchronization.

  This system-owned field stays outside the editorial changesets so browser
  parameters cannot replace the remote identity.

  ## Examples

      iex> changeset = Alchemistdrops.Posts.Post.dev_to_publication_changeset(
      ...>   %Alchemistdrops.Posts.Post{},
      ...>   123,
      ...>   "https://dev.to/alchemistdrops/otp-in-production-123"
      ...> )
      iex> {changeset.changes.dev_to_article_id, changeset.changes.dev_to_article_url}
      {123, "https://dev.to/alchemistdrops/otp-in-production-123"}
  """
  @spec dev_to_publication_changeset(t(), pos_integer(), String.t()) :: Ecto.Changeset.t(t())
  def dev_to_publication_changeset(post, article_id, article_url) do
    post
    |> change(dev_to_article_id: article_id, dev_to_article_url: article_url)
    |> unique_constraint(:dev_to_article_id)
  end

  defp validate_category(changeset) do
    case fetch_change(changeset, :category_name) do
      {:ok, name} ->
        if present?(name),
          do: changeset,
          else: add_error(changeset, :category_name, "can't be blank")

      :error ->
        validate_required(changeset, [:category_id])
    end
  end

  defp put_generated_slug(changeset) do
    slug = get_field(changeset, :slug)
    title = get_field(changeset, :title)

    if present?(slug) do
      changeset
    else
      put_change(changeset, :slug, slugify(title))
    end
  end

  defp slugify(title), do: Slug.from(title)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp validate_cover_alt(changeset) do
    if present?(get_field(changeset, :cover_image_url)) and
         not present?(get_field(changeset, :cover_image_alt)) do
      add_error(changeset, :cover_image_alt, "can't be blank when a cover image is present")
    else
      changeset
    end
  end

  defp validate_cover_url(changeset) do
    validate_change(changeset, :cover_image_url, fn :cover_image_url, value ->
      uri = URI.parse(value)

      if uri.scheme == "https" and present?(uri.host) do
        []
      else
        [cover_image_url: "must be an absolute HTTPS URL"]
      end
    end)
  end

  defp put_status(attrs, status) do
    if Enum.any?(Map.keys(attrs), &is_binary/1) do
      Map.put(attrs, "status", Atom.to_string(status))
    else
      Map.put(attrs, :status, status)
    end
  end
end
