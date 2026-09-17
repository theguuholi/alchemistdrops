defmodule Alchemistdrops.Posts.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias Alchemistdrops.Posts.Slug

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_tags" do
    field :name, :string
    field :slug, :string

    many_to_many :posts, Alchemistdrops.Posts.Post, join_through: "posts_tags"

    timestamps(type: :utc_datetime)
  end

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
