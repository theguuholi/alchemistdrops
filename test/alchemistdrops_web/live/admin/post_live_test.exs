defmodule AlchemistdropsWeb.PostLiveTest do
  use AlchemistdropsWeb.ConnCase

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Social
  alias Alchemistdrops.Social.{FakeContentGenerator, FakeLinkedInClient}

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

  describe "LinkedIn posting" do
    setup [:register_and_log_in_admin_user, :create_post, :reset_linkedin_fakes]

    test "does not show LinkedIn controls for a new unsaved post", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/posts/new")

      refute html =~ "LinkedIn"
    end

    test "shows the admin connection route when LinkedIn is disconnected", %{
      conn: conn,
      post: post
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert has_element?(
               view,
               "#linkedin-connect[href='/admin/linkedin/connect?post_id=#{post.id}']"
             )

      refute has_element?(view, "#generate-linkedin")
    end

    test "generates a Portuguese preview from the public article URL", %{conn: conn, post: post} do
      connect_linkedin()

      generated_text =
        "Este artigo mostra como publicar com clareza. Leia mais: https://example.com"

      FakeContentGenerator.set_static_result({:ok, %{language: "pt-BR", text: generated_text}})
      FakeContentGenerator.set_static_controller(self())

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert has_element?(view, "#generate-linkedin")
      assert view |> element("#generate-linkedin") |> render_click() =~ generated_text
      assert_received {FakeContentGenerator, :called, ^post, article_url}
      assert article_url == url(~p"/blog/#{post.slug}")
      refute_received {FakeLinkedInClient, :publish_called, _, _, _, _, _}
      assert has_element?(view, "#linkedin-share-form textarea[name='linkedin_share[text]']")
      assert render(view) =~ "Detected language: pt-BR"
    end

    test "persists edited LinkedIn preview text", %{conn: conn, post: post} do
      connect_linkedin()
      share = create_share(post, "Original generated preview")

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert view
             |> form("#linkedin-share-form", linkedin_share: %{text: "Edited LinkedIn preview"})
             |> render_change() =~ "Edited LinkedIn preview"

      assert Social.get_share(post).id == share.id
      assert Social.get_share(post).edited_text == "Edited LinkedIn preview"
    end

    test "requires confirmation and provides loading labels before publication", %{
      conn: conn,
      post: post
    } do
      connect_linkedin()
      create_share(post, "Ready to publish")

      {:ok, view, html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert has_element?(
               view,
               "#publish-linkedin[data-confirm='Publish this post to your LinkedIn profile?']"
             )

      assert html =~ "phx-disable-with=\"Generating LinkedIn preview...\""
      assert html =~ "phx-disable-with=\"Publishing to LinkedIn...\""
    end

    test "disables LinkedIn generation and publication while the post form is dirty", %{
      conn: conn,
      post: post
    } do
      connect_linkedin()
      create_share(post, "Draft waiting for review")

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      view
      |> form("#post-form", post: Map.put(@create_attrs, :title, "Unsaved title"))
      |> render_change()

      assert has_element?(view, "#generate-linkedin[disabled]")
      assert has_element?(view, "#publish-linkedin[disabled]")
    end

    test "shows immutable publication metadata after a successful publish", %{
      conn: conn,
      post: post
    } do
      connect_linkedin()
      create_share(post, "Publish this text")
      FakeLinkedInClient.set_static_result({:ok, %{post_urn: "urn:li:share:published"}})
      FakeLinkedInClient.set_static_controller(self())

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert view |> element("#publish-linkedin") |> render_click() =~ "Published to LinkedIn"

      assert_received {FakeLinkedInClient, :publish_called, _, _, "Publish this text",
                       article_url, _}

      assert article_url == url(~p"/blog/#{post.slug}")
      assert render(view) =~ "urn:li:share:published"
      refute has_element?(view, "#publish-linkedin")
      refute has_element?(view, "#linkedin-share-form")
    end

    test "keeps failed text and allows a retry", %{conn: conn, post: post} do
      connect_linkedin()
      create_share(post, "Keep this text after failure")
      FakeLinkedInClient.set_static_result({:error, :provider_failure})

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      capture_log(fn ->
        view |> element("#publish-linkedin") |> render_click()
      end)

      assert render(view) =~ "LinkedIn publication failed. Please try again."

      assert Social.get_share(post).status == :failed
      assert Social.get_share(post).generated_text == "Keep this text after failure"
      assert has_element?(view, "#publish-linkedin")

      FakeLinkedInClient.set_static_result({:ok, %{post_urn: "urn:li:share:retry"}})

      assert view |> element("#publish-linkedin") |> render_click() =~ "Published to LinkedIn"
      assert Social.get_share(post).status == :published
    end

    test "shows Connect LinkedIn when the connection expires during publication", %{
      conn: conn,
      post: post
    } do
      connect_linkedin()
      create_share(post, "Publish after the token expires")

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      expire_linkedin_connection()

      view |> element("#publish-linkedin") |> render_click()

      assert Social.get_share(post).status == :failed
      assert has_element?(view, "#linkedin-connect")
      refute has_element?(view, "#publish-linkedin")
      refute has_element?(view, "#generate-linkedin")
    end

    test "shows Connect LinkedIn when LinkedIn rejects the stored token", %{
      conn: conn,
      post: post
    } do
      connect_linkedin()
      create_share(post, "Publish with a revoked token")
      FakeLinkedInClient.set_static_result({:error, {:http_error, 401}})

      {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

      capture_log(fn ->
        view |> element("#publish-linkedin") |> render_click()
      end)

      assert Social.get_connection() == nil
      assert Social.get_share(post).status == :failed

      assert Social.get_share(post).error_message ==
               "LinkedIn connection is missing or expired."

      assert has_element?(view, "#linkedin-connect")
      refute has_element?(view, "#publish-linkedin")
      refute has_element?(view, "#generate-linkedin")
    end

    test "does not render another publish action once the post is published", %{
      conn: conn,
      post: post
    } do
      create_published_share(post)

      {:ok, view, html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert html =~ "Published to LinkedIn"
      refute has_element?(view, "#publish-linkedin")
      refute has_element?(view, "#generate-linkedin")
    end

    test "shows published metadata when the connection has expired", %{conn: conn, post: post} do
      create_published_share(post)
      expire_linkedin_connection()

      {:ok, view, html} = live(conn, ~p"/admin/posts/#{post}/edit")

      assert has_element?(view, "#linkedin-published")
      assert html =~ "urn:li:share:already-published"
      refute has_element?(view, "#linkedin-connect")
      refute has_element?(view, "#publish-linkedin")
    end
  end

  defp reset_linkedin_fakes(_context) do
    FakeContentGenerator.reset_static()
    FakeLinkedInClient.reset_static()

    on_exit(fn ->
      FakeContentGenerator.reset_static()
      FakeLinkedInClient.reset_static()
    end)

    :ok
  end

  defp connect_linkedin do
    store_linkedin_connection(3_600)
  end

  defp expire_linkedin_connection do
    store_linkedin_connection(0)
  end

  defp store_linkedin_connection(expires_in) do
    assert {:ok, _connection} =
             Social.store_connection(%{
               access_token: "linkedin-access-token",
               expires_in: expires_in,
               member_urn: "urn:li:person:admin"
             })
  end

  defp create_share(post, generated_text) do
    FakeContentGenerator.set_static_result({:ok, %{language: "en", text: generated_text}})
    assert {:ok, share} = Social.generate_share(post, url(~p"/blog/#{post.slug}"))
    share
  end

  defp create_published_share(post) do
    connect_linkedin()
    create_share(post, "Already published")
    FakeLinkedInClient.set_static_result({:ok, %{post_urn: "urn:li:share:already-published"}})
    assert {:ok, _share} = Social.publish_share(post, url(~p"/blog/#{post.slug}"))
  end
end
