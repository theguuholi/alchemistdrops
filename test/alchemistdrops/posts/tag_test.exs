defmodule Alchemistdrops.Posts.TagTest do
  use Alchemistdrops.DataCase, async: true

  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Posts.Tag

  doctest Alchemistdrops.Posts.Tag

  describe "changeset/2" do
    test "given a name, when validated, then it trims the name and generates a slug" do
      changeset = Tag.changeset(%Tag{}, %{name: "  LiveView Tips  "})

      assert changeset.valid?
      assert changeset.changes.name == "LiveView Tips"
      assert changeset.changes.slug == "liveview-tips"
    end

    test "given no name, when validated, then the name is required" do
      changeset = Tag.changeset(%Tag{}, %{})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "given a name longer than 50 characters, when validated, then it is rejected" do
      changeset = Tag.changeset(%Tag{}, %{name: String.duplicate("a", 51)})

      assert %{name: ["should be at most 50 character(s)"]} = errors_on(changeset)
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
