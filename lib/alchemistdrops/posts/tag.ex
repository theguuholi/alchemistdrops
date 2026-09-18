defmodule Alchemistdrops.Posts.Tag do
  @moduledoc """
  Represents a reusable editorial label attached to blog posts.

  Tags support cross-category discovery through stable slugs while the changeset
  keeps their normalized names and URL identifiers unique.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Alchemistdrops.Posts.Slug

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Database identifier for the tag. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Human-readable tag name. Nil before validation."
  @type name :: String.t() | nil

  @typedoc "URL-safe tag identifier. Nil before slug generation."
  @type slug :: String.t() | nil

  @typedoc "Timestamp when the tag was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the tag was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A post tag before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          name: name(),
          slug: slug(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

  schema "post_tags" do
    field :name, :string
    field :slug, :string

    many_to_many :posts, Alchemistdrops.Posts.Post, join_through: "posts_tags"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a tag changeset, normalizing its name and generating a slug when absent.

  ## Examples

      iex> changeset = Alchemistdrops.Posts.Tag.changeset(%Alchemistdrops.Posts.Tag{}, %{name: "  LiveView Tips  "})
      iex> {changeset.changes.name, changeset.changes.slug}
      {"LiveView Tips", "liveview-tips"}

      iex> Alchemistdrops.Posts.Tag.changeset(%Alchemistdrops.Posts.Tag{}, %{name: ""}).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :slug])
    |> update_change(:name, &String.trim/1)
    |> put_generated_slug()
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> unique_constraint(:name, name: :post_tags_lower_name_index)
    |> unique_constraint(:slug)
  end

  defp put_generated_slug(changeset) do
    case get_field(changeset, :slug) do
      value when is_binary(value) and value != "" -> changeset
      _value -> put_change(changeset, :slug, Slug.from(get_field(changeset, :name)))
    end
  end
end
