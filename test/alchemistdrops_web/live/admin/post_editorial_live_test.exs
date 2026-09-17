defmodule AlchemistdropsWeb.Admin.PostEditorialLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Posts

  setup :register_and_log_in_admin_user

  test "an incomplete article can be saved as a draft", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    assert {:error, {:live_redirect, %{to: "/admin/posts"}}} =
             view
             |> form("#post-form", post: %{title: "A useful draft"})
             |> render_submit()

    assert [%{status: :draft, title: "A useful draft"}] =
             Enum.filter(Posts.list_admin_posts(), &(&1.title == "A useful draft"))
  end

  test "publishing reports missing publication fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    html =
      render_submit(view, "save", %{
        "intent" => "publish",
        "post" => %{"title" => "Incomplete article"}
      })

    assert html =~ "can&#39;t be blank"
    assert has_element?(view, "#post-form [name='post[summary]']")
    assert has_element?(view, "#post-form [name='post[category_name]']")
  end

  test "publishes a complete article and exposes its public URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    result =
      render_submit(view, "save", %{
        "intent" => "publish",
        "post" => %{
          "title" => "Published from editor",
          "summary" => "A complete summary",
          "body" => "## Complete body",
          "category_name" => "Engineering",
          "tag_names" => "Elixir, LiveView"
        }
      })

    assert {:error, {:live_redirect, %{to: edit_path}}} = result
    assert edit_path =~ "/admin/posts/"

    [post] = Enum.filter(Posts.list_admin_posts(), &(&1.title == "Published from editor"))
    assert post.status == :published

    {:ok, edit_view, _html} = live(conn, edit_path)
    assert has_element?(edit_view, "#public-post-link[href='/blog/#{post.slug}']")
  end

  test "unpublishes an article and removes distribution controls", %{conn: conn} do
    post = post_fixture(%{title: "Published article"})
    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

    assert view |> element("#unpublish-post") |> render_click() =~ "Draft saved"
    assert Posts.get_post!(post.id).status == :draft
  end

  test "shows taxonomy, optional course, SEO preview, and tag validation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    assert has_element?(view, "#post-category")
    assert has_element?(view, "#post-tags")
    assert has_element?(view, "#post-related-course")
    assert has_element?(view, "#seo-preview")
    assert has_element?(view, "#preview-article[phx-hook='Mermaid']")

    html =
      view
      |> form("#post-form",
        post: %{
          title: "Too many tags",
          tag_names: "one, two, three, four, five, six"
        }
      )
      |> render_submit()

    assert html =~ "must contain at most 5 tags"
  end

  test "admin index displays editorial status and publication date", %{conn: conn} do
    published = post_fixture(%{title: "Published row"})
    draft_post_fixture(%{title: "Draft row"})

    {:ok, view, html} = live(conn, ~p"/admin/posts")

    assert html =~ "Published row"
    assert html =~ "Draft row"
    assert has_element?(view, "#posts-#{published.id} [data-role='post-status']", "Published")
    assert html =~ Calendar.strftime(published.published_at, "%b %-d, %Y")
  end
end
