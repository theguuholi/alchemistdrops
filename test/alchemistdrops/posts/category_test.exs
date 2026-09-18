defmodule Alchemistdrops.Posts.CategoryTest do
  use Alchemistdrops.DataCase, async: true

  alias Alchemistdrops.Posts.Category

  import Alchemistdrops.PostsFixtures

  doctest Alchemistdrops.Posts.Category

  describe "changeset/2" do
    test "given a name, when validated, then it trims the name and generates a slug" do
      changeset = Category.changeset(%Category{}, %{name: "  Elixir Patterns  "})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Elixir Patterns"
      assert Ecto.Changeset.get_change(changeset, :slug) == "elixir-patterns"
    end

    test "given boundary values, when validated, then required and maximum lengths are enforced" do
      assert %{name: ["can't be blank"]} = errors_on(Category.changeset(%Category{}, %{}))

      assert %{name: ["should be at most 80 character(s)"]} =
               errors_on(Category.changeset(%Category{}, %{name: String.duplicate("a", 81)}))

      assert %{description: ["should be at most 240 character(s)"]} =
               errors_on(
                 Category.changeset(%Category{}, %{
                   name: "Elixir",
                   description: String.duplicate("a", 241)
                 })
               )
    end

    test "given duplicate names and slugs, when inserted, then constraints become changeset errors" do
      first = category_fixture(%{name: "Architecture"})

      assert {:error, duplicate_name} =
               %Category{}
               |> Category.changeset(%{name: first.name, slug: "another-slug"})
               |> Repo.insert()

      assert %{name: ["has already been taken"]} = errors_on(duplicate_name)

      assert {:error, duplicate_slug} =
               %Category{}
               |> Category.changeset(%{name: "Another name", slug: first.slug})
               |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(duplicate_slug)
    end
  end
end
