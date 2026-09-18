defmodule AlchemistdropsWeb.Public.PostLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.PostsFixtures
  import Phoenix.LiveViewTest

  alias Alchemistdrops.Posts

  describe "handle_params/3 - index listing" do
    test "given no published posts, when the index loads, then it renders the empty state",
         %{conn: conn} do
      # Given
      # There are no published posts.

      # When
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then
      assert has_element?(view, "main#blog-index[aria-labelledby='blog-title']")
      assert has_element?(view, "#blog-title", "Alchemist's Journal")
      assert has_element?(view, "#blog-description", "Discover insights")
      assert has_element?(view, "#posts-empty-state", "No posts yet")
      assert has_element?(view, "#posts-empty-state", "Check back soon for new content")
    end

    test "given published posts, when the index loads, then it renders stable card contracts",
         %{conn: conn} do
      # Given
      first =
        post_fixture(%{
          title: "Understanding Elixir Processes",
          body: "Body that must not be used as the card excerpt",
          summary: "A focused process summary",
          views: 42
        })

      second =
        post_fixture(%{
          title: "Phoenix LiveView Tips",
          body: "LiveView body",
          summary: "A focused LiveView summary",
          views: 128
        })

      # When
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then
      assert has_element?(view, "article#posts-#{first.id}")
      assert has_element?(view, "#post-title-#{first.id}", "Understanding Elixir Processes")

      assert has_element?(
               view,
               "#post-link-#{first.id}[href='/blog/#{first.slug}']",
               "Understanding Elixir Processes"
             )

      assert has_element?(view, "#post-excerpt-#{first.id}", "A focused process summary")
      refute has_element?(view, "#post-excerpt-#{first.id}", first.body)
      assert has_element?(view, "#post-views-#{first.id}", "42")
      assert has_element?(view, "#post-date-#{first.id}[datetime]")
      assert has_element?(view, "#post-read-more-#{first.id}", "Read article")
      assert has_element?(view, "#post-title-#{second.id}", "Phoenix LiveView Tips")
      assert has_element?(view, "#post-views-#{second.id}", "128")
    end

    test "given a category query, when the URL loads, then handle_params filters the cards",
         %{conn: conn} do
      # Given
      elixir = category_fixture(%{name: "Elixir"})
      phoenix = category_fixture(%{name: "Phoenix"})
      elixir_post = post_fixture(%{title: "Elixir article", category_id: elixir.id})
      phoenix_post = post_fixture(%{title: "Phoenix article", category_id: phoenix.id})

      # When
      {:ok, view, _html} = live(conn, ~p"/blog?category=elixir")

      # Then
      assert has_element?(view, "#posts-#{elixir_post.id}")
      refute has_element?(view, "#posts-#{phoenix_post.id}")
      assert has_element?(view, "#blog-category-elixir")
    end

    test "given combined category and tag queries, when the URL loads, then both filters apply",
         %{conn: conn} do
      # Given
      elixir = category_fixture(%{name: "Elixir"})
      phoenix = category_fixture(%{name: "Phoenix"})

      matching =
        post_fixture(%{
          title: "OTP with Elixir",
          category_id: elixir.id,
          tag_names: "OTP"
        })

      wrong_tag = post_fixture(%{title: "Ecto with Elixir", category_id: elixir.id})

      wrong_category =
        post_fixture(%{
          title: "OTP with Phoenix",
          category_id: phoenix.id,
          tag_names: "OTP"
        })

      # When
      {:ok, view, _html} = live(conn, ~p"/blog?category=elixir&tag=otp")

      # Then
      assert has_element?(view, "#posts-#{matching.id}")
      refute has_element?(view, "#posts-#{wrong_tag.id}")
      refute has_element?(view, "#posts-#{wrong_category.id}")
      assert has_element?(view, "#blog-category-elixir")
      assert has_element?(view, "#blog-tag-otp")
    end

    test "given category controls, when a category is selected, then the URL is patched and results change",
         %{conn: conn} do
      # Given
      category = category_fixture(%{name: "Elixir"})
      elixir_post = post_fixture(%{title: "Selected article", category_id: category.id})
      other_post = post_fixture(%{title: "Other article"})
      {:ok, view, _html} = live(conn, ~p"/blog")

      # When
      view
      |> element("#blog-category-elixir", "Elixir 1")
      |> render_click()

      # Then
      assert_patch(view, ~p"/blog?category=elixir")
      assert has_element?(view, "#posts-#{elixir_post.id}")
      refute has_element?(view, "#posts-#{other_post.id}")
    end

    test "given more than one page, when next is selected, then pagination patches the URL",
         %{conn: conn} do
      # Given
      category = category_fixture(%{name: "Pagination"})

      for number <- 1..13 do
        post_fixture(%{title: "Page article #{number}", category_id: category.id})
      end

      {:ok, view, _html} = live(conn, ~p"/blog")

      # When
      view
      |> element("#blog-next", "Next")
      |> render_click()

      # Then
      assert_patch(view, ~p"/blog?page=2")
      assert has_element?(view, "#blog-previous", "Previous")
      refute has_element?(view, "#blog-next")
    end

    test "given a draft post, when the index loads, then the draft is not exposed", %{conn: conn} do
      # Given
      draft = draft_post_fixture(%{title: "Private draft"})

      # When
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then
      refute has_element?(view, "#posts-#{draft.id}")
      refute has_element?(view, "#post-title-#{draft.id}", "Private draft")
    end
  end

  describe "mount/3 - post detail" do
    test "given a published post, when its page mounts, then it renders semantic article content",
         %{conn: conn} do
      # Given
      post =
        post_fixture(%{
          title: "Mastering Phoenix Contexts",
          body: "## Boundaries\n\nContexts provide clear boundaries.",
          summary: "A guide to context boundaries",
          views: 250
        })

      # When
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then
      assert has_element?(view, "article#post-detail")
      assert has_element?(view, "nav[aria-label='Blog navigation']")
      assert has_element?(view, "header#post-header")
      assert has_element?(view, "#post-title", "Mastering Phoenix Contexts")
      assert has_element?(view, "#post-summary", "A guide to context boundaries")
      assert has_element?(view, "section#post-body")
      assert has_element?(view, "#post-article", "Contexts provide clear boundaries")
      assert has_element?(view, "#post-views", "views")
      assert has_element?(view, "footer#post-footer")
    end

    test "given an index card, when its titled link is selected, then the post LiveView opens",
         %{conn: conn} do
      # Given
      post = post_fixture(%{title: "Getting Started with Ecto", body: "Ecto content"})
      {:ok, index_view, _html} = live(conn, ~p"/blog")

      # When
      result =
        index_view
        |> element("#post-link-#{post.id}", "Getting Started with Ecto")
        |> render_click()

      # Then
      assert_redirect(index_view, ~p"/blog/#{post.slug}")

      assert {:ok, show_view, _html} =
               follow_redirect(result, conn, ~p"/blog/#{post.slug}")

      assert has_element?(show_view, "#post-title", "Getting Started with Ecto")
      assert has_element?(show_view, "#post-article", "Ecto content")
    end

    test "given a legacy UUID URL, when the page mounts, then it redirects to the canonical slug",
         %{conn: conn} do
      # Given
      post = post_fixture(%{title: "Legacy Link", body: "Legacy content"})

      # When
      result = live(conn, ~p"/blog/#{post.id}")

      # Then
      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path == ~p"/blog/#{post.slug}"
    end

    test "given a UUID-shaped slug, when the canonical URL mounts, then the slug wins over ID fallback",
         %{conn: conn} do
      # Given
      uuid_slug = "123e4567-e89b-12d3-a456-426614174000"
      post = post_fixture(%{title: uuid_slug, body: "UUID-shaped slug content"})

      # When
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then
      assert has_element?(view, "#post-title", uuid_slug)
      assert has_element?(view, "#post-article", "UUID-shaped slug content")
    end

    test "given a published post, when a connected page mounts, then its view count increments",
         %{conn: conn} do
      # Given
      post = post_fixture(%{title: "Popular Post", body: "Great content", views: 100})

      # When
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then
      assert Posts.get_post!(post.id).views == 101
      assert has_element?(view, "#post-views", "101 views")
    end

    test "given SEO content, when the post mounts, then the page title and description are exposed",
         %{conn: conn} do
      # Given
      post =
        post_fixture(%{
          title: "Complete Guide to Testing",
          body: "Testing content",
          summary: "Testing is crucial for maintaining code quality",
          seo_title: "Elixir testing guide"
        })

      # When
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then
      assert page_title(view) == "Elixir testing guide · Alchemistdrops"

      assert has_element?(
               view,
               "#post-summary",
               "Testing is crucial for maintaining code quality"
             )
    end

    test "given a loaded detail page, when back is selected, then it redirects to the blog index",
         %{conn: conn} do
      # Given
      post = post_fixture(%{title: "Sample Post", body: "Sample content"})
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # When
      view
      |> element("#post-back-link", "Back to all posts")
      |> render_click()

      # Then
      assert_redirect(view, ~p"/blog")
    end

    test "given an updated post, when its page mounts, then the footer shows the updated timestamp",
         %{conn: conn} do
      # Given
      post = post_fixture(%{title: "Updated Post", body: "Old content"})
      {:ok, updated_post} = Posts.update_post(post, %{body: "New content"})
      formatted_date = Calendar.strftime(updated_post.updated_at, "%B %d, %Y")

      # When
      {:ok, view, _html} = live(conn, ~p"/blog/#{updated_post.slug}")

      # Then
      assert has_element?(view, "#post-updated-at[datetime]", "Last updated: #{formatted_date}")
    end

    test "given a draft post, when its public URL mounts, then it is rejected", %{conn: conn} do
      # Given
      draft = draft_post_fixture(%{title: "Private article"})

      # When / Then
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/blog/#{draft.slug}")
      end
    end

    test "given Mermaid and headings, when the post mounts, then hook and anchor contracts render",
         %{conn: conn} do
      # Given
      post =
        post_fixture(%{
          title: "Architecture Overview",
          body: "## Diagram\n\n```mermaid\ngraph TD\n  A --> B\n```\n\n## Skills\n\nContent."
        })

      # When
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then
      assert has_element?(view, "article#post-article[phx-hook='Mermaid'][phx-update='ignore']")
      assert has_element?(view, "#post-article pre.mermaid")
      assert has_element?(view, "#post-article h2 a#diagram")
      assert has_element?(view, "#post-article h2 a#skills")
      assert has_element?(view, "#article-mobile-toc a[href='#skills']", "Skills")
      assert has_element?(view, "#article-toc a[href='#skills']", "Skills")
    end
  end
end
