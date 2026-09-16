defmodule Alchemistdrops.Repo.Migrations.AddSlugToPosts do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      add :slug, :string
    end

    flush()

    backfill_post_slugs()

    create unique_index(:posts, [:slug])

    alter table(:posts) do
      modify :slug, :string, null: false
    end
  end

  def down do
    drop unique_index(:posts, [:slug])

    alter table(:posts) do
      remove :slug
    end
  end

  defp backfill_post_slugs do
    %{rows: rows} =
      repo().query!("""
      SELECT id, title
      FROM posts
      ORDER BY inserted_at, id
      """)

    Enum.reduce(rows, MapSet.new(), fn [id, title], used_slugs ->
      slug = unique_slug(slugify(title), used_slugs)

      repo().query!("UPDATE posts SET slug = $1 WHERE id = $2", [slug, id])

      MapSet.put(used_slugs, slug)
    end)
  end

  defp unique_slug(base_slug, used_slugs) do
    if MapSet.member?(used_slugs, base_slug) do
      find_available_slug_suffix(base_slug, used_slugs)
    else
      base_slug
    end
  end

  defp find_available_slug_suffix(base_slug, used_slugs) do
    2
    |> Stream.iterate(&(&1 + 1))
    |> Enum.find_value(fn suffix ->
      slug = "#{base_slug}-#{suffix}"
      unless MapSet.member?(used_slugs, slug), do: slug
    end)
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
end
