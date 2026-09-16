defmodule Alchemistdrops.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :background, :string, default: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
    field :title, :string
    field :slug, :string
    field :body, :string
    field :views, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:background, :title, :slug, :body, :views])
    |> put_generated_slug()
    |> validate_required([:title, :slug, :body, :views])
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> unique_constraint(:slug)
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

  defp slugify(title) when is_binary(title) do
    slug =
      title
      |> String.normalize(:nfd)
      |> String.replace(~r/[\p{Mn}]/u, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    if slug == "", do: "post", else: slug
  end

  defp slugify(_), do: "post"

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
