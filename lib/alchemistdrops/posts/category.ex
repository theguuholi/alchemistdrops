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

  @typedoc "A post category before or after persistence."
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          description: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
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
      iex> {Ecto.Changeset.get_change(changeset, :name), Ecto.Changeset.get_change(changeset, :slug)}
      {"Elixir Patterns", "elixir-patterns"}

      iex> Alchemistdrops.Posts.Category.changeset(%Alchemistdrops.Posts.Category{}, %{name: ""}).valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
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
