defmodule Alchemistdrops.Social.LinkedInSchemasTest do
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Social.{LinkedInConnection, LinkedInPostShare}

  import Alchemistdrops.PostsFixtures

  test "requires the LinkedIn connection fields and uses the personal singleton id" do
    changeset = LinkedInConnection.changeset(%LinkedInConnection{}, %{})

    refute changeset.valid?

    assert %{
             member_urn: ["can't be blank"],
             access_token_ciphertext: ["can't be blank"],
             expires_at: ["can't be blank"]
           } =
             errors_on(changeset)

    valid_changeset =
      LinkedInConnection.changeset(%LinkedInConnection{}, %{
        member_urn: "urn:li:person:abc123",
        access_token_ciphertext: "encrypted-token",
        expires_at: ~U[2026-09-16 15:00:00Z]
      })

    assert valid_changeset.valid?
    assert Ecto.Changeset.get_field(valid_changeset, :id) == "personal"
  end

  test "the database rejects a LinkedIn connection with a non-personal id" do
    connection = %LinkedInConnection{
      id: "organization",
      member_urn: "urn:li:organization:abc123",
      access_token_ciphertext: "encrypted-token",
      expires_at: ~U[2026-09-16 15:00:00Z]
    }

    assert_raise Ecto.ConstraintError, ~r/linkedin_connections_personal_id_check/, fn ->
      Repo.insert!(connection)
    end
  end

  test "accepts every LinkedIn post share status" do
    for status <- [:draft, :publishing, :published, :failed] do
      changeset = LinkedInPostShare.status_changeset(%LinkedInPostShare{}, %{status: status})

      assert changeset.valid?
      assert Ecto.Changeset.apply_changes(changeset).status == status
    end
  end

  test "limits generated text to 3,000 characters" do
    valid_attrs = %{language: "en", generated_text: String.duplicate("a", 3_000)}
    invalid_attrs = %{language: "en", generated_text: String.duplicate("a", 3_001)}

    assert LinkedInPostShare.generation_changeset(%LinkedInPostShare{}, valid_attrs).valid?

    changeset = LinkedInPostShare.generation_changeset(%LinkedInPostShare{}, invalid_attrs)
    refute changeset.valid?
    assert %{generated_text: ["should be at most 3000 character(s)"]} = errors_on(changeset)
  end

  test "validates edited text with the same character limit" do
    changeset =
      LinkedInPostShare.edit_changeset(%LinkedInPostShare{}, %{
        edited_text: String.duplicate("a", 3_001)
      })

    refute changeset.valid?
    assert %{edited_text: ["should be at most 3000 character(s)"]} = errors_on(changeset)
  end

  test "returns a changeset error when a post already has a LinkedIn share" do
    post = post_fixture()
    attrs = %{language: "en", generated_text: "A post worth sharing."}

    assert {:ok, _share} =
             Repo.insert(
               %LinkedInPostShare{post_id: post.id}
               |> LinkedInPostShare.generation_changeset(attrs)
             )

    assert {:error, changeset} =
             Repo.insert(
               %LinkedInPostShare{post_id: post.id}
               |> LinkedInPostShare.generation_changeset(attrs)
             )

    assert %{post_id: ["has already been taken"]} = errors_on(changeset)
  end

  test "returns a changeset error when a share references a missing post" do
    share = %LinkedInPostShare{post_id: Ecto.UUID.generate()}
    attrs = %{language: "en", generated_text: "A post worth sharing."}

    assert {:error, changeset} =
             Repo.insert(share |> LinkedInPostShare.generation_changeset(attrs))

    assert %{post_id: ["does not exist"]} = errors_on(changeset)
  end
end
