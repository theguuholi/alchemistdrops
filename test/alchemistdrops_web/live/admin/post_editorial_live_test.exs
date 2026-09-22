defmodule AlchemistdropsWeb.Admin.PostEditorialLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.PostsFixtures
  import Phoenix.LiveViewTest

  alias Alchemistdrops.{Posts, Repo}

  setup :register_and_log_in_admin_user

  setup do
    previous = Application.get_env(:alchemistdrops, :dev_to)

    Application.put_env(:alchemistdrops, :dev_to,
      api_key: "dev-test-key",
      base_url: "https://dev.to",
      http_client: Alchemistdrops.Posts.DevToPublisher.ReqClient,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> Application.put_env(:alchemistdrops, :dev_to, previous) end)
  end

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

    [post] = Enum.filter(Posts.list_admin_posts(), &(&1.title == "Published from editor"))
    assert post.status == :published

    {:ok, edit_view, _html} = live(conn, edit_path)
    assert has_element?(edit_view, "#public-post-link[href='/blog/#{post.slug}']")
    assert has_element?(edit_view, "#publish-dev-to", "Publish on DEV.to")
  end

  test "given a published article, when DEV.to publishing runs twice, then it creates once and updates the same remote article",
       %{conn: conn} do
    post = post_fixture(%{title: "DEV.to distribution", tag_names: "Elixir, LiveView"})
    owner = self()

    Req.Test.expect(__MODULE__, 2, fn conn ->
      send(owner, {:dev_to_http_request, conn.method, conn.request_path, Req.Test.raw_body(conn)})

      status = if conn.method == "POST", do: 201, else: 200

      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(%{
        "id" => 812,
        "url" => "https://dev.to/theguuholi/dev-to-distribution"
      })
    end)

    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")
    Req.Test.allow(__MODULE__, self(), view.pid)

    view |> element("#publish-dev-to", "Publish on DEV.to") |> render_click()

    assert has_element?(view, "#flash-info", "Article published on DEV.to")
    assert has_element?(view, "#publish-dev-to", "Update on DEV.to")

    assert has_element?(
             view,
             "#dev-to-article-link[href='https://dev.to/theguuholi/dev-to-distribution']"
           )

    assert_receive {:dev_to_http_request, "POST", "/api/articles", create_body}

    assert %{
             "article" => %{
               "canonical_url" => canonical_url,
               "published" => true
             }
           } = Jason.decode!(create_body)

    assert canonical_url == "http://localhost:4002/blog/#{post.slug}"

    view |> element("#publish-dev-to", "Update on DEV.to") |> render_click()

    assert has_element?(view, "#flash-info", "Article updated on DEV.to")
    assert_receive {:dev_to_http_request, "PUT", "/api/articles/812", _update_body}

    persisted = Posts.get_post!(post.id)
    assert persisted.dev_to_article_id == 812
    assert persisted.dev_to_url == "https://dev.to/theguuholi/dev-to-distribution"
    assert persisted.dev_to_synced_at
  end

  test "given DEV.to rejects an article, when publishing is requested, then it preserves local state and shows the error",
       %{conn: conn} do
    post = post_fixture(%{title: "Rejected distribution"})

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"error" => "Validation failed", "details" => ["Tag invalid"]})
    end)

    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")
    Req.Test.allow(__MODULE__, self(), view.pid)

    view |> element("#publish-dev-to") |> render_click()

    assert has_element?(view, "#flash-error", "DEV.to rejected the article")
    assert has_element?(view, "#publish-dev-to", "Publish on DEV.to")
    refute has_element?(view, "#dev-to-article-link")

    persisted = Posts.get_post!(post.id)
    assert persisted.dev_to_article_id == nil
    assert persisted.dev_to_url == nil
    assert persisted.dev_to_synced_at == nil
  end

  test "given unsaved editor changes, when DEV.to publishing is considered, then the action is disabled without losing the changes",
       %{conn: conn} do
    post = post_fixture(%{title: "Persisted title"})
    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

    view
    |> form("#post-form", post: %{title: "Unsaved title"})
    |> render_change()

    assert has_element?(view, "#publish-dev-to[disabled]")
    assert has_element?(view, "#dev-to-save-guidance", "Save changes before publishing to DEV.to")
    assert has_element?(view, "#post_title[value='Unsaved title']")

    render_hook(view, "publish-dev-to", %{})

    assert has_element?(view, "#flash-error", "Save your changes before publishing to DEV.to")
    assert has_element?(view, "#post_title[value='Unsaved title']")
    assert Posts.get_post!(post.id).title == "Persisted title"
  end

  test "assigns a new category to a legacy published article", %{conn: conn} do
    post = post_fixture(%{title: "Legacy published article"})

    post
    |> Ecto.Changeset.change(category_id: nil)
    |> Repo.update!()

    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

    view
    |> form("#post-form", post: %{category_name: "AI"})
    |> render_change()

    refute has_element?(view, "[id^='post-category-error-']")

    assert {:error, {:live_redirect, %{to: "/admin/posts"}}} =
             view
             |> form("#post-form", post: %{category_name: "AI"})
             |> render_submit()

    assert Posts.get_admin_post!(post.id).category.name == "AI"
  end

  test "unpublishes an article and removes distribution controls", %{conn: conn} do
    post = post_fixture(%{title: "Published article"})
    {:ok, view, _html} = live(conn, ~p"/admin/posts/#{post}/edit")

    view |> element("#unpublish-post") |> render_click()
    assert has_element?(view, "#flash-info", "Draft saved")
    refute has_element?(view, "#publish-dev-to")
    assert Posts.get_post!(post.id).status == :draft
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
