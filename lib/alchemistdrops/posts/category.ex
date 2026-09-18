defmodule Alchemistdrops.Posts.Category do
  @moduledoc """
  Represents the primary editorial topic assigned to blog posts.

  Categories provide stable, human-readable URL slugs for discovery and ensure
  names and slugs remain unique across the public blog taxonomy.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Alchemistdrops.Posts.Slug

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Database identifier for the category. Nil before persistence."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Human-readable category name. Nil before validation."
  @type name :: String.t() | nil

  @typedoc "URL-safe category identifier. Nil before slug generation."
  @type slug :: String.t() | nil

  @typedoc "Short explanation of the category. Nil when it has not been provided."
  @type description :: String.t() | nil

  @typedoc "Timestamp when the category was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the category was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A post category before or after persistence."
  @type t :: %__MODULE__{
          id: id(),
          name: name(),
          slug: slug(),
          description: description(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

  schema "post_categories" do
    field :name, :string
    field :slug, :string
    field :description, :string

    has_many :posts, Alchemistdrops.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a category changeset, normalizing its name and generating a slug when absent.

  ## Examples

      iex> changeset = Alchemistdrops.Posts.Category.changeset(%Alchemistdrops.Posts.Category{}, %{name: "  Elixir Patterns  "})
      iex> {changeset.changes.name, changeset.changes.slug}
      {"Elixir Patterns", "elixir-patterns"}

      iex> Alchemistdrops.Posts.Category.changeset(%Alchemistdrops.Posts.Category{}, %{name: ""}).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t(t())
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description])
    |> update_change(:name, &String.trim/1)
    |> put_generated_slug()
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 80)
    |> validate_length(:description, max: 240)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> unique_constraint(:name, name: :post_categories_lower_name_index)
    |> unique_constraint(:slug)
  end

  defp put_generated_slug(changeset) do
    case get_field(changeset, :slug) do
      value when is_binary(value) and value != "" -> changeset
      _value -> put_change(changeset, :slug, Slug.from(get_field(changeset, :name)))
    end
  end
end
