defmodule Alchemistdrops.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Alchemistdrops.Posts.Slug

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          background: String.t() | nil,
          title: String.t() | nil,
          slug: String.t() | nil,
          body: String.t() | nil,
          views: integer() | nil,
          status: :draft | :published,
          published_at: DateTime.t() | nil,
          summary: String.t() | nil,
          seo_title: String.t() | nil,
          seo_description: String.t() | nil,
          cover_image_url: String.t() | nil,
          cover_image_alt: String.t() | nil,
          language: :en | :pt_br,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
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
    field :language, Ecto.Enum, values: [en: "en", pt_br: "pt-BR"], default: :en

    belongs_to :category, Alchemistdrops.Posts.Category
    belongs_to :related_course, Alchemistdrops.Courses.Course

    many_to_many :tags, Alchemistdrops.Posts.Tag,
      join_through: "posts_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs), do: draft_changeset(post, attrs)

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

  def publish_changeset(post, attrs) do
    post
    |> draft_changeset(put_status(attrs, :published))
    |> validate_required([:body, :summary, :category_id])
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
