defmodule Alchemistdrops.Posts.TagTest do
  use Alchemistdrops.DataCase, async: true

  alias Alchemistdrops.Posts.Tag

  import Alchemistdrops.PostsFixtures

  doctest Alchemistdrops.Posts.Tag

  describe "changeset/2" do
    test "given a name, when validated, then it trims the name and generates a slug" do
      changeset = Tag.changeset(%Tag{}, %{name: "  LiveView Tips  "})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "LiveView Tips"
      assert Ecto.Changeset.get_change(changeset, :slug) == "liveview-tips"
    end

    test "given boundary values, when validated, then required and maximum lengths are enforced" do
      assert %{name: ["can't be blank"]} = errors_on(Tag.changeset(%Tag{}, %{}))

      assert %{name: ["should be at most 50 character(s)"]} =
               errors_on(Tag.changeset(%Tag{}, %{name: String.duplicate("a", 51)}))
    end

    test "given duplicate names and slugs, when inserted, then constraints become changeset errors" do
      first = tag_fixture(%{name: "OTP"})

      assert {:error, duplicate_name} =
               %Tag{}
               |> Tag.changeset(%{name: first.name, slug: "another-slug"})
               |> Repo.insert()

      assert %{name: ["has already been taken"]} = errors_on(duplicate_name)

      assert {:error, duplicate_slug} =
               %Tag{}
               |> Tag.changeset(%{name: "Another name", slug: first.slug})
               |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(duplicate_slug)
    end
  end
end
