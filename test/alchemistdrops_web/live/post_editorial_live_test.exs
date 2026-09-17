defmodule AlchemistdropsWeb.Public.PostEditorialLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures
  import Alchemistdrops.CoursesFixtures

  alias Alchemistdrops.Posts

  test "drafts stay out of the public index and cannot be opened", %{conn: conn} do
    draft = draft_post_fixture(%{title: "Hidden draft"})
    published = post_fixture(%{title: "Visible article"})

    {:ok, _view, html} = live(conn, ~p"/blog")
    assert html =~ published.title
    refute html =~ draft.title

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/blog/#{draft.slug}") end
    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/blog/#{draft.id}") end
  end

  test "category and tag filters update the result set", %{conn: conn} do
    {:ok, elixir} =
      Posts.create_post(%{
        title: "OTP patterns",
        body: "Body",
        summary: "Summary",
        category_name: "Elixir",
        tag_names: "OTP"
      })

    {:ok, _elixir} = Posts.publish_post(elixir)

    {:ok, phoenix} =
      Posts.create_post(%{
        title: "LiveView patterns",
        body: "Body",
        summary: "Summary",
        category_name: "Phoenix",
        tag_names: "LiveView"
      })

    {:ok, _phoenix} = Posts.publish_post(phoenix)

    {:ok, category_view, category_html} = live(conn, ~p"/blog?category=elixir")
    assert category_html =~ "OTP patterns"
    refute category_html =~ "LiveView patterns"
    assert has_element?(category_view, "a[href*='tag=otp']", "OTP")

    {:ok, _tag_view, tag_html} = live(conn, ~p"/blog?tag=liveview")
    assert tag_html =~ "LiveView patterns"
    refute tag_html =~ "OTP patterns"
  end

  test "index cards expose editorial metadata and deterministic pagination", %{conn: conn} do
    Enum.each(1..11, fn number ->
      post_fixture(%{title: "Article #{number}", summary: "Summary #{number}"})
    end)

    {:ok, view, html} = live(conn, ~p"/blog")

    assert has_element?(view, ".post-card .post-category")
    assert has_element?(view, ".post-card .reading-time", "min read")
    assert html =~ "Summary"
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

    {:ok, view, html} = live(conn, ~p"/blog/#{post.slug}")

    assert html =~ "Neste artigo"
    assert has_element?(view, ".reading-time", "min de leitura")
    assert has_element?(view, ".back-link", "Voltar ao blog")
  end
end
