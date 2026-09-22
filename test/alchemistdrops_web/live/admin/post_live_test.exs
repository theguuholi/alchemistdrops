defmodule AlchemistdropsWeb.PostLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.PostsFixtures
  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  @dev_to_stub :dev_to

  @create_attrs %{
    title: "a new post title",
    body: "some body",
    background: "some background",
    views: 42
  }
  @update_attrs %{
    title: "some updated title",
    body: "some updated body",
    background: "some updated background",
    views: 43
  }
  @invalid_attrs %{title: nil, body: nil, background: nil, views: nil}

  defp create_post(_) do
    post = post_fixture()

    %{post: post}
  end

  describe "Index" do
    setup [:register_and_log_in_admin_user, :create_post]
    setup {Req.Test, :verify_on_exit!}

    test "lists all posts", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts")

      assert has_element?(view, "#admin-posts h1", "Posts")
      assert has_element?(view, "#posts-#{post.id}")
    end

    test "displays stats", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/posts")

      assert has_element?(view, "#admin-posts", "Total Posts")
      assert has_element?(view, "#admin-posts", "Total Views")
    end

    test "formats views as 'k' when 1000 or more", %{conn: conn} do
      post_fixture(%{title: "Popular Post", views: 1500})
      {:ok, view, _html} = live(conn, ~p"/admin/posts")

      assert has_element?(view, "#admin-posts", "1.5k")
    end

    test "saves new post", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/posts")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Post")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/posts/new")

      assert has_element?(form_live, "#post-form")

      form_live
      |> form("#post-form", post: @invalid_attrs)
      |> render_change()

      assert has_element?(form_live, "#post_title-error-0", "can't be blank")

      assert {:ok, index_live, _html} =
               form_live
               |> form("#post-form", post: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/posts")

      assert has_element?(index_live, "#flash-info", "Post created successfully")
    end

    test "shows errors when creating post with invalid data", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/posts/new")

      # Submit invalid data - should show errors and stay on form
      form_live
      |> form("#post-form", post: @invalid_attrs)
      |> render_submit()

      assert has_element?(form_live, "#post_title-error-0", "can't be blank")
    end

    test "updates post in listing", %{conn: conn, post: post} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/posts")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#posts-#{post.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/posts/#{post}/edit")

      assert has_element?(form_live, "#post-form")

      form_live
      |> form("#post-form", post: @invalid_attrs)
      |> render_change()

      assert has_element?(form_live, "#post_title-error-0", "can't be blank")

      assert {:ok, index_live, _html} =
               form_live
               |> form("#post-form", post: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/posts")

      assert has_element?(index_live, "#flash-info", "Post updated successfully")
    end

    test "shows errors when updating post with invalid data", %{conn: conn, post: post} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      # Submit invalid data - should show errors and stay on form
      form_live
      |> form("#post-form", post: @invalid_attrs)
      |> render_submit()

      assert has_element?(form_live, "#post_title-error-0", "can't be blank")
    end

    test "deletes post in listing", %{conn: conn, post: post} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/posts")

      assert index_live
             |> element("#posts-#{post.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#posts-#{post.id}")
    end

    test "given local and synchronized posts, when listed, then it shows the matching DEV.to action",
         %{conn: conn, post: post} do
      draft = draft_post_fixture(%{title: "Unpublished draft"})

      synchronized =
        dev_to_post_fixture(%{
          title: "Synchronized article",
          dev_to_article_id: 711,
          dev_to_article_url: "https://dev.to/alchemistdrops/synchronized-article-711"
        })

      {:ok, view, _html} = live(conn, ~p"/admin/posts")

      assert has_element?(
               view,
               "#posts-#{post.id} #publish-dev-to-#{post.id}",
               "Publish on DEV.to"
             )

      refute has_element?(view, "#posts-#{draft.id} #publish-dev-to-#{draft.id}")
      refute has_element?(view, "#posts-#{synchronized.id} #publish-dev-to-#{synchronized.id}")

      assert has_element?(
               view,
               "#posts-#{synchronized.id} #view-dev-to-#{synchronized.id}[href='https://dev.to/alchemistdrops/synchronized-article-711'][target='_blank'][rel='noopener noreferrer']",
               "View on DEV.to"
             )
    end

    test "given a legacy DEV.to ID without a URL, when listed, then it reports publication without a publish button",
         %{conn: conn} do
      synchronized =
        legacy_dev_to_post_fixture(%{title: "Legacy synchronization", dev_to_article_id: 712})

      {:ok, view, _html} = live(conn, ~p"/admin/posts")

      refute has_element?(view, "#publish-dev-to-#{synchronized.id}")

      assert has_element?(
               view,
               "#dev-to-published-#{synchronized.id}",
               "Published on DEV.to"
             )
    end

    test "given a published post, when DEV.to accepts it, then the index reports publication",
         %{conn: conn, post: post} do
      Req.Test.expect(@dev_to_stub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/articles"

        Req.Test.json(conn, %{
          "id" => 812,
          "url" => "https://dev.to/alchemistdrops/published-from-admin-812"
        })
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/posts")
      Req.Test.allow(@dev_to_stub, self(), view.pid)

      view
      |> element("#publish-dev-to-#{post.id}", "Publish on DEV.to")
      |> render_click()

      assert has_element?(view, "#flash-info", "Article published on DEV.to")
      refute has_element?(view, "#publish-dev-to-#{post.id}")

      assert has_element?(
               view,
               "#view-dev-to-#{post.id}[href='https://dev.to/alchemistdrops/published-from-admin-812']",
               "View on DEV.to"
             )
    end

    test "given a published post, when DEV.to rejects it, then the index reports the failure",
         %{conn: conn, post: post} do
      Req.Test.expect(@dev_to_stub, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"error" => "Validation failed"})
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/posts")
      Req.Test.allow(@dev_to_stub, self(), view.pid)

      log =
        capture_log(fn ->
          view |> element("#publish-dev-to-#{post.id}") |> render_click()
        end)

      assert has_element?(view, "#flash-error", "Could not publish article on DEV.to")
      assert log =~ "Failed to publish post #{post.id} to DEV.to"
      assert log =~ "{:api_error, 422}"
    end
  end

  describe "Show" do
    setup [:register_and_log_in_admin_user, :create_post]

    test "displays post", %{conn: conn, post: post} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/posts/#{post}")

      assert has_element?(show_live, "#admin-post-show", "Post #{post.id}")
      assert has_element?(show_live, "#admin-post-show", post.background)
    end

    test "updates post and returns to show", %{conn: conn, post: post} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/posts/#{post}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/posts/#{post}/edit?return_to=show")

      assert has_element?(form_live, "#post-form")

      form_live
      |> form("#post-form", post: @invalid_attrs)
      |> render_change()

      assert has_element?(form_live, "#post_title-error-0", "can't be blank")

      assert {:ok, show_live, _html} =
               form_live
               |> form("#post-form", post: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/posts/#{post}")

      assert has_element?(show_live, "#flash-info", "Post updated successfully")
      assert has_element?(show_live, "#admin-post-show", "some updated background")
    end
  end
end
