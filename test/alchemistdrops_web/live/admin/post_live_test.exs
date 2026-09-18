defmodule AlchemistdropsWeb.PostLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures

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
