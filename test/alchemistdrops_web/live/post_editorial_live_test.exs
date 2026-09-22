defmodule AlchemistdropsWeb.Public.PostEditorialLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.PostsFixtures
  import Phoenix.LiveViewTest

  test "drafts stay out of the public index and cannot be opened", %{conn: conn} do
    draft = draft_post_fixture(%{title: "Hidden draft"})
    published = post_fixture(%{title: "Visible article"})

    {:ok, view, _html} = live(conn, ~p"/blog")
    assert has_element?(view, "#posts-#{published.id}", published.title)
    refute has_element?(view, "#posts-grid", draft.title)

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/blog/#{draft.slug}") end
    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/blog/#{draft.id}") end
  end

  test "public index renders legacy published posts without a category", %{conn: conn} do
    post = legacy_post_without_category_fixture(%{title: "Legacy article"})

    {:ok, view, _html} = live(conn, ~p"/blog")

    assert has_element?(view, "#posts-#{post.id}", "Legacy article")
    assert has_element?(view, "#posts-#{post.id} .post-category", "Uncategorized")
  end

  test "article page renders a legacy published post without a category", %{conn: conn} do
    post = legacy_post_without_category_fixture(%{title: "Legacy article detail"})

    {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

    assert has_element?(view, ".post-header", "Legacy article detail")
    assert has_element?(view, ".post-header", "Uncategorized")
  end

  test "article page renders a related legacy post without a category", %{conn: conn} do
    current = post_fixture(%{title: "Current tagged article", tag_names: "OTP"})
    legacy_post_without_category_fixture(%{title: "Legacy related article", tag_names: "OTP"})

    {:ok, view, _html} = live(conn, ~p"/blog/#{current.slug}")

    assert has_element?(view, "#related-articles", "Legacy related article")
    assert has_element?(view, "#related-articles", "Uncategorized")
  end

  test "category and tag filters update the result set", %{conn: conn} do
    post_fixture(%{
      title: "OTP patterns",
      body: "Body",
      summary: "Summary",
      category_name: "Elixir",
      tag_names: "OTP"
    })

    post_fixture(%{
      title: "LiveView patterns",
      body: "Body",
      summary: "Summary",
      category_name: "Phoenix",
      tag_names: "LiveView"
    })

    {:ok, category_view, _html} = live(conn, ~p"/blog?category=elixir")
    assert has_element?(category_view, "#posts-grid", "OTP patterns")
    refute has_element?(category_view, "#posts-grid", "LiveView patterns")
    assert has_element?(category_view, "a[href*='tag=otp']", "OTP")

    {:ok, tag_view, _html} = live(conn, ~p"/blog?tag=liveview")
    assert has_element?(tag_view, "#posts-grid", "LiveView patterns")
    refute has_element?(tag_view, "#posts-grid", "OTP patterns")
  end

  test "index cards expose editorial metadata and deterministic pagination", %{conn: conn} do
    Enum.each(1..11, fn number ->
      post_fixture(%{title: "Article #{number}", summary: "Summary #{number}"})
    end)

    {:ok, view, _html} = live(conn, ~p"/blog")

    assert has_element?(view, ".post-card .post-category")
    assert has_element?(view, ".post-card .reading-time", "min read")
    assert has_element?(view, "#posts-grid", "Summary")
    assert has_element?(view, "#blog-next[href='/blog?page=2']")

    {:ok, page_two, _html} = live(conn, ~p"/blog?page=2")
    assert has_element?(page_two, "#blog-previous[href='/blog']")
  end

  test "article uses one page title and matching desktop and mobile outlines", %{conn: conn} do
    post =
      post_fixture(%{
        title: "Guided reading",
        summary: "A concise overview",
        body: "# Guided reading\n\nIntro\n\n## First step\n\n### Details"
      })

    {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

    assert has_element?(view, "article.post-detail h1", "Guided reading")
    refute has_element?(view, "#post-article h1")
    assert has_element?(view, "#article-toc a[href='#first-step']", "First step")
    assert has_element?(view, "#article-mobile-toc details")
    assert has_element?(view, "#post-article h2 a#first-step")
    assert has_element?(view, ".post-content-grid > #post-article")
    assert has_element?(view, ".post-content-grid > #article-toc")
  end

  test "related course CTA is rendered only for a published course", %{conn: conn} do
    published_course = published_course_fixture(%{title: "Production LiveView"})
    draft_course = course_fixture(%{title: "Unreleased course"})

    published_cta =
      post_fixture(%{title: "With course", related_course_id: published_course.id})

    hidden_cta = post_fixture(%{title: "With draft course", related_course_id: draft_course.id})

    {:ok, published_view, _html} = live(conn, ~p"/blog/#{published_cta.slug}")
    assert has_element?(published_view, "#related-course", "Production LiveView")

    {:ok, hidden_view, _html} = live(conn, ~p"/blog/#{hidden_cta.slug}")
    refute has_element?(hidden_view, "#related-course")
  end

  test "Portuguese articles localize reading labels", %{conn: conn} do
    post = post_fixture(%{title: "Leitura guiada", language: :pt_br, body: "## Primeiro passo"})

    {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

    assert has_element?(view, "#article-toc", "Neste artigo")
    assert has_element?(view, ".reading-time", "min de leitura")
    assert has_element?(view, ".back-link", "Voltar ao blog")
  end

  test "article emits canonical social metadata and safe BlogPosting JSON-LD", %{conn: conn} do
    post =
      post_fixture(%{
        title: "Metadata <Guide>",
        summary: "A clear summary",
        seo_title: "Search title",
        seo_description: "Search description",
        cover_image_url: "https://example.com/cover.png",
        cover_image_alt: "Article cover",
        language: :pt_br
      })

    {:ok, _view, html} = live(conn, ~p"/blog/#{post.slug}")

    canonical = "http://localhost:4002/blog/#{post.slug}"
    document = LazyHTML.from_document(html)
    assert LazyHTML.attribute(LazyHTML.query(document, "html"), "lang") == ["pt-BR"]

    assert LazyHTML.attribute(LazyHTML.query(document, "link[rel='canonical']"), "href") == [
             canonical
           ]

    assert LazyHTML.attribute(LazyHTML.query(document, "meta[property='og:type']"), "content") ==
             ["article"]

    assert LazyHTML.attribute(LazyHTML.query(document, "meta[property='og:image']"), "content") ==
             [
               "https://example.com/cover.png"
             ]

    assert LazyHTML.attribute(LazyHTML.query(document, "meta[property='og:locale']"), "content") ==
             [
               "pt_BR"
             ]

    assert Enum.count(LazyHTML.query(document, "meta[property='article:published_time']")) == 1

    json = document |> LazyHTML.query("script[type='application/ld+json']") |> LazyHTML.text()
    assert %{"@type" => "BlogPosting", "headline" => "Metadata <Guide>"} = Jason.decode!(json)
  end

  test "article metadata falls back to the summary and site image", %{conn: conn} do
    post = post_fixture(%{title: "Fallback metadata", summary: "Summary fallback"})

    {:ok, _view, html} = live(conn, ~p"/blog/#{post.slug}")

    document = LazyHTML.from_document(html)

    assert LazyHTML.attribute(LazyHTML.query(document, "meta[name='description']"), "content") ==
             [
               "Summary fallback"
             ]

    assert LazyHTML.attribute(LazyHTML.query(document, "meta[property='og:image']"), "content") ==
             [
               "http://localhost:4002/images/logo.svg"
             ]
  end
end
