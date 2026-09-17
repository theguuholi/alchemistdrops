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
      {:ok, view, html} = live(conn, ~p"/admin/posts")

      assert html =~ "Posts"
      assert has_element?(view, "#posts-#{post.id}")
    end

    test "displays stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/posts")

      assert html =~ "Total Posts"
      assert html =~ "Total Views"
    end

    test "formats views as 'k' when 1000 or more", %{conn: conn} do
      post_fixture(%{title: "Popular Post", views: 1500})
      {:ok, _view, html} = live(conn, ~p"/admin/posts")

      assert html =~ "1.5k"
    end

    test "saves new post", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/posts")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Post")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/posts/new")

      assert render(form_live) =~ "New Post"

      assert form_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#post-form", post: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/posts")

      html = render(index_live)
      assert html =~ "Post created successfully"
    end

    test "shows errors when creating post with invalid data", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/posts/new")

      # Submit invalid data - should show errors and stay on form
      html =
        form_live
        |> form("#post-form", post: @invalid_attrs)
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "updates post in listing", %{conn: conn, post: post} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/posts")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#posts-#{post.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/posts/#{post}/edit")

      assert render(form_live) =~ "Edit Post"

      assert form_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#post-form", post: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/posts")

      html = render(index_live)
      assert html =~ "Post updated successfully"
    end

    test "shows errors when updating post with invalid data", %{conn: conn, post: post} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      # Submit invalid data - should show errors and stay on form
      html =
        form_live
        |> form("#post-form", post: @invalid_attrs)
        |> render_submit()

      assert html =~ "can&#39;t be blank"
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
      {:ok, _show_live, html} = live(conn, ~p"/admin/posts/#{post}")

      assert html =~ "Show Post"
      assert html =~ post.background
    end

    test "updates post and returns to show", %{conn: conn, post: post} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/posts/#{post}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/posts/#{post}/edit?return_to=show")

      assert render(form_live) =~ "Edit Post"

      assert form_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#post-form", post: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/posts/#{post}")

      html = render(show_live)
      assert html =~ "Post updated successfully"
      assert html =~ "some updated background"
    end
  end
end
