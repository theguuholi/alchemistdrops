defmodule Alchemistdrops.Posts.ArticleTest do
  use ExUnit.Case, async: true

  alias Alchemistdrops.Posts.{Article, Post}

  doctest Alchemistdrops.Posts.Article
  doctest Alchemistdrops.Posts.Slug

  describe "build/1" do
    test "removes only a leading h1 that duplicates the post title" do
      post = %Post{
        title: "A Practical Guide",
        body: "# A *Practical* Guide\n\nIntro\n\n## First section\n\n# Intentional conclusion"
      }

      article = Article.build(post)

      refute article.html =~ "<h1><a href=\"#a-practical-guide\""
      assert article.html =~ "Intentional conclusion</h1>"
      assert article.toc == [%{level: 2, id: "first-section", label: "First section"}]
    end

    test "keeps a leading h1 when it does not duplicate the post title" do
      article = Article.build(%Post{title: "Page title", body: "# A distinct introduction"})

      assert article.html =~ "A distinct introduction</h1>"
    end

    test "extracts h2 and h3 entries with plain labels matching rendered anchor ids" do
      article =
        Article.build(%Post{
          title: "Outline",
          body: "## Build with *confidence*\n\n### API & clients\n\n#### Not in the outline"
        })

      assert article.toc == [
               %{level: 2, id: "build-with-confidence", label: "Build with confidence"},
               %{level: 3, id: "api--clients", label: "API & clients"}
             ]
    end

    test "calculates reading time for English and Portuguese text with a one-minute minimum" do
      assert Article.build(%Post{title: "Short", body: "A short article."}).reading_minutes == 1

      long_body = Enum.map_join(1..221, " ", fn _ -> "palavra" end)

      assert Article.build(%Post{title: "Longo", body: long_body}).reading_minutes == 2
    end

    test "handles a nil body" do
      assert %{html: "", toc: [], reading_minutes: 1} =
               Article.build(%Post{title: "Empty", body: nil})
    end

    test "resolves the description from SEO override, summary, then an empty string" do
      assert Article.build(%Post{seo_description: "Search description", summary: "Summary"}).description ==
               "Search description"

      assert Article.build(%Post{seo_description: " ", summary: "Summary"}).description ==
               "Summary"

      assert Article.build(%Post{}).description == ""
    end
  end
end
