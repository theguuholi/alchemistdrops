defmodule Alchemistdrops.Posts.PostTest do
  use Alchemistdrops.DataCase, async: true

  alias Alchemistdrops.Posts.Post

  doctest Alchemistdrops.Posts.Post

  describe "draft_changeset/2" do
    test "given DEV.to identity attributes, when a draft is changed, then system fields stay protected" do
      post = %Post{}

      changeset =
        Post.draft_changeset(post, %{
          title: "Protected distribution fields",
          dev_to_article_id: 123
        })

      assert post.dev_to_article_id == nil
      refute Map.has_key?(changeset.changes, :dev_to_article_id)
    end

    test "given a title, when a draft is validated, then defaults and slug are present" do
      changeset = Post.draft_changeset(%Post{}, %{title: "Hello OTP"})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :draft
      assert Ecto.Changeset.get_field(changeset, :views) == 0
      assert changeset.changes.slug == "hello-otp"
    end

    test "given invalid SEO and cover metadata, when validated, then each invariant is reported" do
      changeset =
        Post.draft_changeset(%Post{}, %{
          title: "Metadata",
          summary: String.duplicate("s", 241),
          seo_title: String.duplicate("t", 61),
          seo_description: String.duplicate("d", 161),
          cover_image_url: "http://example.com/image.png"
        })

      assert %{
               summary: ["should be at most 240 character(s)"],
               seo_title: ["should be at most 60 character(s)"],
               seo_description: ["should be at most 160 character(s)"],
               cover_image_url: ["must be an absolute HTTPS URL"]
             } = errors_on(changeset)
    end

    test "given an HTTPS cover without alt text, when validated, then accessible text is required" do
      changeset =
        Post.draft_changeset(%Post{}, %{
          title: "Cover",
          cover_image_url: "https://example.com/image.png"
        })

      assert %{cover_image_alt: ["can't be blank when a cover image is present"]} =
               errors_on(changeset)
    end
  end

  describe "publish_changeset/2" do
    test "given complete content and a category name, when published, then the post is valid" do
      changeset =
        Post.publish_changeset(%Post{}, %{
          title: "Published",
          body: "Body",
          summary: "Summary",
          category_name: "Elixir"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :published
    end

    test "given incomplete content, when published, then body, summary, and category are required" do
      changeset = Post.publish_changeset(%Post{}, %{title: "Incomplete"})

      assert %{
               body: ["can't be blank"],
               summary: ["can't be blank"],
               category_id: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "dev_to_publication_changeset/2" do
    test "given a DEV.to article ID, when changed, then it records only that identity" do
      changeset = Post.dev_to_publication_changeset(%Post{}, 123)

      assert changeset.valid?
      assert changeset.changes.dev_to_article_id == 123
    end
  end
end
