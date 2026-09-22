defmodule AlchemistdropsWeb.Admin.PostEditorialLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.PostsFixtures
  import Phoenix.LiveViewTest

  setup :register_and_log_in_admin_user

  test "an incomplete article can be saved as a draft", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    assert {:ok, index_view, _html} =
             view
             |> form("#post-form", post: %{title: "A useful draft"})
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/posts")

    assert has_element?(index_view, "#admin-posts", "A useful draft")
  end

  test "publishing reports missing publication fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    render_submit(view, "save", %{
      "intent" => "publish",
      "post" => %{"title" => "Incomplete article"}
    })

    assert has_element?(view, "#post-form .text-error", "can't be blank")
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

    {:ok, edit_view, _html} = live(conn, edit_path)
    assert has_element?(edit_view, "#public-post-link[href^='/blog/']", "View article")
  end

  test "assigns a new category to a legacy published article", %{conn: conn} do
    post = legacy_post_without_category_fixture(%{title: "Legacy published article"})

    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

    view
    |> form("#post-form", post: %{category_name: "AI"})
    |> render_change()

    refute has_element?(view, "[id^='post-category-error-']")

    assert {:ok, index_view, _html} =
             view
             |> form("#post-form", post: %{category_name: "AI"})
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/posts")

    assert has_element?(index_view, "#flash-info", "Post updated successfully")
  end

  test "unpublishes an article", %{conn: conn} do
    post = post_fixture(%{title: "Published article"})
    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

    view |> element("#unpublish-post") |> render_click()
    assert has_element?(view, "#flash-info", "Draft saved")
    assert has_element?(view, "#publish-post", "Publish article")
    refute has_element?(view, "#unpublish-post")
  end

  test "shows taxonomy, optional course, SEO preview, and tag validation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/posts/new")

    assert has_element?(view, "#post-category")
    assert has_element?(view, "#post-tags")
    assert has_element?(view, "#post-related-course")
    assert has_element?(view, "#seo-preview")
    assert has_element?(view, "#preview-article[phx-hook='Mermaid']")

    view
    |> form("#post-form",
      post: %{
        title: "Too many tags",
        tag_names: "one, two, three, four, five, six"
      }
    )
    |> render_submit()

    assert has_element?(view, "#post-tags-error-0", "must contain at most 5 tags")
  end

  test "admin index displays editorial status and publication date", %{conn: conn} do
    published = post_fixture(%{title: "Published row"})
    draft_post_fixture(%{title: "Draft row"})

    {:ok, view, _html} = live(conn, ~p"/admin/posts")

    assert has_element?(view, "#admin-posts", "Published row")
    assert has_element?(view, "#admin-posts", "Draft row")
    assert has_element?(view, "#posts-#{published.id} [data-role='post-status']", "Published")

    assert has_element?(
             view,
             "#posts-#{published.id}",
             Calendar.strftime(published.published_at, "%b %-d, %Y")
           )
  end
end
