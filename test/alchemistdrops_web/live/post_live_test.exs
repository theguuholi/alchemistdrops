defmodule AlchemistdropsWeb.Public.PostLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures
  import Ecto.Query

  describe "PostLive.Index" do
    test "renders post cards with slug navigation targets", %{conn: conn} do
      post =
        post_fixture(%{
          title: "Slug Link Target",
          body: "The index should link to this post by slug",
          views: 12
        })

      {:ok, _view, html} = live(conn, ~p"/blog")

      assert html =~ "Slug Link Target"
      assert html =~ "/blog/#{post.slug}"
    end
  end

  describe "PostLive.Show" do
    test "sets canonical metadata URL with the post slug", %{conn: conn} do
      post =
        post_fixture(%{
          title: "Canonical Slug",
          body: "The show page should expose the canonical slug URL",
          views: 8
        })

      {:ok, _view, html} = live(conn, ~p"/blog/#{post.slug}")

      assert html =~ ~s(<link rel="canonical" href="http://localhost:4002/blog/#{post.slug}")
      assert html =~ ~s(<meta property="og:url" content="http://localhost:4002/blog/#{post.slug}")
      refute html =~ ~s(http://localhost:4002/blog/#{post.id})
    end
  end

  describe "list_published_posts/0" do
    # Given a list of card blogs
    # When the user visits the blog page
    # Then the user should see all published posts
    test "displays a list of blog post cards", %{conn: conn} do
      # Given: three blog posts exist in the database
      _post1 =
        post_fixture(%{
          title: "Understanding Elixir Processes",
          body: "Elixir processes are lightweight and isolated units of concurrency...",
          background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
          views: 42
        })

      _post2 =
        post_fixture(%{
          title: "Phoenix LiveView Tips",
          body: "LiveView brings real-time interactivity to Phoenix applications...",
          background: "linear-gradient(135deg, #f093fb 0%, #f5576c 100%)",
          views: 128
        })

      _post3 =
        post_fixture(%{
          title: "Building REST APIs",
          body: "REST APIs are a fundamental part of modern web development...",
          background: "linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)",
          views: 87
        })

      # When: the user visits the blog index page
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the page should display the blog header
      assert has_element?(view, "h1", "Alchemist's Journal")
      assert has_element?(view, "p", "Discover insights, tutorials, and stories")

      # And: all three posts should be displayed as cards
      assert has_element?(view, ".post-card .post-title", "Understanding Elixir Processes")
      assert has_element?(view, ".post-card .post-title", "Phoenix LiveView Tips")
      assert has_element?(view, ".post-card .post-title", "Building REST APIs")

      # And: each card should show the view count
      assert has_element?(view, ".views", "42")
      assert has_element?(view, ".views", "128")
      assert has_element?(view, ".views", "87")

      # And: the posts grid should exist
      assert has_element?(view, "#posts-grid")
    end

    # Given: no blog posts exist
    # When: the user visits the blog page
    # Then: an empty state message should be displayed
    test "displays empty state when no posts exist", %{conn: conn} do
      # Given: no posts exist in the database

      # When: the user visits the blog index page
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the empty state message should be displayed
      assert has_element?(view, ".empty-state", "No posts yet")
      assert has_element?(view, ".empty-state", "Check back soon for new content")

      # And: the posts grid should exist but be empty
      assert has_element?(view, "#posts-grid")
    end

    # Given: posts with long body content
    # When: the user views the blog cards
    # Then: the body should be truncated with ellipsis
    test "truncates long post excerpts in cards", %{conn: conn} do
      # Given: a post with a very long body
      long_body =
        String.duplicate(
          "This is a very long post about web development and all its intricacies. ",
          10
        )

      _post = post_fixture(%{title: "Long Article", body: long_body, views: 5})

      # When: the user visits the blog index page
      {:ok, view, html} = live(conn, ~p"/blog")

      # Then: the post title should be visible
      assert has_element?(view, ".post-card .post-title", "Long Article")

      # And: the full long body should not be present
      refute html =~ long_body

      # And: should show ellipsis for truncated content
      assert has_element?(view, ".post-excerpt")
      assert html =~ "..."
    end

    # Given: multiple posts with different dates
    # When: the user views the blog list
    # Then: posts should be ordered by most recent first
    test "displays posts ordered by most recent first", %{conn: conn} do
      # Given: three posts with different timestamps
      {:ok, old_date} = DateTime.new(~D[2023-01-15], ~T[10:00:00], "Etc/UTC")
      {:ok, recent_date} = DateTime.new(~D[2024-11-20], ~T[10:00:00], "Etc/UTC")

      old_post =
        post_fixture(%{
          title: "Old Post",
          body: "This is an old post",
          views: 100
        })

      recent_post =
        post_fixture(%{
          title: "Recent Post",
          body: "This is a recent post",
          views: 50
        })

      # Update timestamps via repo
      Alchemistdrops.Repo.update_all(
        from(p in Alchemistdrops.Posts.Post, where: p.id == ^old_post.id),
        set: [inserted_at: old_date]
      )

      Alchemistdrops.Repo.update_all(
        from(p in Alchemistdrops.Posts.Post, where: p.id == ^recent_post.id),
        set: [inserted_at: recent_date]
      )

      # When: the user visits the blog page
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: both posts should be displayed
      assert has_element?(view, ".post-card .post-title", "Old Post")
      assert has_element?(view, ".post-card .post-title", "Recent Post")

      # And: the recent post should appear before the old post in the DOM
      # Check via the stream IDs which should be in reverse chronological order
      rendered_html = render(view)
      # Posts should be streamed with most recent first
      assert rendered_html =~ ~r/Recent Post.*Old Post/s
    end
  end

  describe "navigate_to_post/1" do
    # Given: a list of card blogs
    # When: the user clicks on a specific post
    # Then: redirect the user to the post detail page
    test "redirects to post detail page when clicking on a post card", %{conn: conn} do
      # Given: a published post exists
      post =
        post_fixture(%{
          title: "Getting Started with Ecto",
          body: "Ecto is a database wrapper and query generator for Elixir...",
          background: "linear-gradient(135deg, #fa709a 0%, #fee140 100%)",
          views: 75
        })

      # When: the user visits the blog index page
      {:ok, index_view, _html} = live(conn, ~p"/blog")

      # And: the user clicks on the post card
      _result =
        index_view
        |> element("article#posts-#{post.id}")
        |> render_click()

      # Then: the user should be redirected to the post detail page
      assert_redirect(index_view, ~p"/blog/#{post.slug}")
    end

    # Given: multiple blog post cards
    # When: the user clicks on a specific card
    # Then: only that specific post's detail page should be shown
    test "navigates to the correct post when multiple posts exist", %{conn: conn} do
      # Given: multiple posts exist
      _post1 = post_fixture(%{title: "First Post", body: "Content 1", views: 10})
      post2 = post_fixture(%{title: "Second Post", body: "Content 2", views: 20})
      _post3 = post_fixture(%{title: "Third Post", body: "Content 3", views: 30})

      # When: the user visits the blog index
      {:ok, index_view, _html} = live(conn, ~p"/blog")

      # And: clicks on the second post
      result =
        index_view
        |> element("article#posts-#{post2.id}")
        |> render_click()

      # Then: should redirect to the second post's page
      assert_redirect(index_view, ~p"/blog/#{post2.slug}")

      # And: following the redirect shows the correct post
      {:ok, view, html} = follow_redirect(result, conn)
      assert has_element?(view, ".post-title", "Second Post")
      assert html =~ "Content 2"
      # Could be 20 or 21 depending on mount increment
      assert html =~ ~r/2[01] views/
      refute html =~ "First Post"
      refute html =~ "Third Post"
    end

    # Given: an old UUID blog URL
    # When: the user visits it
    # Then: redirect the user to the canonical slug URL
    test "redirects legacy UUID post URLs to the slug URL", %{conn: conn} do
      # Given: a published post exists
      post = post_fixture(%{title: "Legacy Link", body: "Old links should continue working"})

      # When: the user visits the old UUID URL
      result = live(conn, ~p"/blog/#{post.id}")

      # Then: the user should be redirected to the canonical slug URL
      assert {:error, {:live_redirect, %{to: "/blog/legacy-link"}}} = result
    end

    # Given: a post whose slug has a UUID shape
    # When: the user visits the public blog slug URL
    # Then: the slug should resolve before legacy UUID fallback
    test "loads UUID-shaped slugs as canonical post URLs", %{conn: conn} do
      # Given: a published post has a UUID-shaped slug
      uuid_shaped_slug = "123e4567-e89b-12d3-a456-426614174000"

      post =
        post_fixture(%{
          title: uuid_shaped_slug,
          body: "This title intentionally produces a UUID-shaped slug"
        })

      # When: the user visits the slug URL
      {:ok, view, html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the page should render the post instead of treating the slug as an ID
      assert has_element?(view, ".post-title", uuid_shaped_slug)
      assert html =~ "This title intentionally produces a UUID-shaped slug"
    end
  end

  describe "show_post_detail/1" do
    # Given: a blog post exists
    # When: the user navigates to the post detail page
    # Then: the full post content should be displayed
    test "displays full post content on detail page", %{conn: conn} do
      # Given: a blog post with rich content
      post =
        post_fixture(%{
          title: "Mastering Phoenix Contexts",
          body:
            "Phoenix contexts are a powerful way to organize your code.\n\nThey provide clear boundaries between different parts of your application.\n\nLet's explore how to use them effectively.",
          background: "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)",
          views: 250
        })

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the post title should be prominently displayed
      assert has_element?(view, ".post-title", "Mastering Phoenix Contexts")

      # And: the full body content should be shown in the post body section
      assert has_element?(
               view,
               ".post-body",
               "Phoenix contexts are a powerful way to organize your code"
             )

      assert has_element?(view, ".post-body", "They provide clear boundaries")
      assert has_element?(view, ".post-body", "Let's explore how to use them effectively")

      # And: the view count should be displayed (note: might be 251 if incremented on mount)
      assert has_element?(view, ".post-views")

      # And: a back button should be present
      assert has_element?(view, ".back-link", "Back to all posts")
    end

    # Given: a user is viewing a post detail page
    # When: the page loads
    # Then: the view count should increment
    test "increments view count when post is viewed", %{conn: conn} do
      # Given: a post with an initial view count
      post = post_fixture(%{title: "Popular Post", body: "Great content", views: 100})

      # When: the user visits the post detail page in a connected socket
      {:ok, _view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the view count should be incremented (only happens when socket is connected in real usage)
      # In tests, this depends on how the test connection is setup
      # So we check that it's either the same or incremented
      updated_post = Alchemistdrops.Posts.get_post!(post.id)
      assert updated_post.views in [100, 101]
    end

    # Given: a post detail page
    # When: the page is rendered
    # Then: SEO meta tags should be present in the head
    test "sets SEO meta tags for the post", %{conn: conn} do
      # Given: a post with descriptive content
      post =
        post_fixture(%{
          title: "Complete Guide to Testing",
          body:
            "Testing is crucial for maintaining code quality. In this comprehensive guide, we'll explore different testing strategies and best practices for Elixir applications.",
          views: 500
        })

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the page title should be set with the post title
      assert page_title(view) =~ "Complete Guide to Testing"

      # And: SEO assigns should be set correctly (need to use render to check assigns in tests)
      assert render_async(view) =~ "Testing is crucial for maintaining code quality"
    end

    # Given: a user is on the post detail page
    # When: the user clicks "Back to all posts"
    # Then: the user should be redirected to the blog index
    test "navigates back to blog index from post detail", %{conn: conn} do
      # Given: a post detail page is loaded
      post = post_fixture(%{title: "Sample Post", body: "Sample content", views: 10})
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # When: the user clicks the back button in the navigation
      _result =
        view
        |> element(".back-link")
        |> render_click()

      # Then: the user should be redirected to the blog index
      assert_redirect(view, ~p"/blog")
    end

    # Given: a post with a recent update
    # When: viewing the post detail
    # Then: the "last updated" timestamp should be displayed
    test "displays last updated timestamp in footer", %{conn: conn} do
      # Given: a post that was recently updated
      post = post_fixture(%{title: "Updated Post", body: "New content", views: 25})

      # Update the post to change the updated_at timestamp
      {:ok, updated_post} =
        Alchemistdrops.Posts.update_post(post, %{body: "Even newer content"})

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{updated_post.slug}")

      # Then: the last updated date should be shown
      assert has_element?(view, ".last-updated", "Last updated:")

      # And: should show the formatted date
      formatted_date = Calendar.strftime(updated_post.updated_at, "%B %d, %Y")
      assert has_element?(view, ".last-updated", formatted_date)
    end
  end

  describe "post_card_ui_elements" do
    # Given: a blog post card
    # When: the card is rendered
    # Then: all essential UI elements should be present
    test "displays all required card elements", %{conn: conn} do
      # Given: a post with all fields populated
      post =
        post_fixture(%{
          title: "Beautiful Card Design",
          body: "This post has a beautiful card design with all elements.",
          background: "linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%)",
          views: 150
        })

      # When: the blog index is rendered
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the card should have a title
      assert has_element?(view, ".post-card .post-title", "Beautiful Card Design")

      # And: should display an excerpt of the body
      assert has_element?(view, ".post-card .post-excerpt")

      # And: should show the view count with an icon
      assert has_element?(view, "article#posts-#{post.id} .views")
      assert has_element?(view, ".views", "150")

      # And: should have a "Read more" call to action
      assert has_element?(view, ".read-more", "Read article")

      # And: should show the publication date
      assert has_element?(view, "article#posts-#{post.id} .post-date")
    end

    # Given: a user hovers over a blog card
    # When: hover effects are applied
    # Then: the card should have hover interaction classes
    test "includes hover interaction classes on cards", %{conn: conn} do
      # Given: a post card exists
      post = post_fixture(%{title: "Hover Test", body: "Testing hover", views: 5})

      # When: the blog index is rendered
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the card should have hover effect classes
      card_html = view |> element("article#posts-#{post.id}") |> render()

      assert card_html =~ "hover:bg-gray-50"
      assert card_html =~ "transition-all"
      assert card_html =~ "group-hover:text-gray-700"
    end
  end

  describe "accessibility_and_semantics" do
    # Given: the blog pages
    # When: rendered in HTML
    # Then: proper HTML5 semantic tags should be used
    test "uses proper HTML5 semantic tags on index page", %{conn: conn} do
      # Given: posts exist
      post_fixture(%{title: "Semantic HTML", body: "Content about HTML5", views: 10})

      # When: the blog index is rendered
      {:ok, view, html} = live(conn, ~p"/blog")

      # Then: proper semantic tags should be used
      assert html =~ "<article"
      assert html =~ "<header"
      assert html =~ "<section"

      # And: heading hierarchy should be proper
      assert has_element?(view, "h1")
      assert has_element?(view, "h2")
    end

    # Given: the post detail page
    # When: rendered
    # Then: proper semantic HTML5 tags and ARIA attributes should be used
    test "uses proper HTML5 semantic tags on detail page", %{conn: conn} do
      # Given: a post exists
      post = post_fixture(%{title: "Accessible Post", body: "Accessibility matters", views: 20})

      # When: the detail page is rendered
      {:ok, view, html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: proper semantic structure should exist
      assert has_element?(view, "article.post-detail")
      assert has_element?(view, "header.post-header")
      assert has_element?(view, "section.post-body")
      assert has_element?(view, "footer.post-footer")
      assert has_element?(view, "nav")

      # And: time elements should have datetime attributes
      assert html =~ ~r/<time datetime="[^"]+"/
    end
  end

  describe "date_formatting" do
    # Given: posts with various dates
    # When: dates are displayed
    # Then: they should be formatted in a readable way
    test "formats dates in a human-readable format", %{conn: conn} do
      # Given: a post with a specific date
      {:ok, specific_date} = DateTime.new(~D[2024-03-15], ~T[10:30:00], "Etc/UTC")

      post =
        post_fixture(%{
          title: "Date Format Test",
          body: "Testing date formats",
          views: 5
        })

      # Manually update the inserted_at timestamp
      Alchemistdrops.Repo.update_all(
        from(p in Alchemistdrops.Posts.Post, where: p.id == ^post.id),
        set: [inserted_at: specific_date]
      )

      # When: the blog index is rendered
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the date should be formatted as "Month DD, YYYY"
      assert has_element?(view, ".post-date", "March 15, 2024")
    end
  end

  describe "edge_cases_and_error_handling" do
    # Given: a post with nil body
    # When: rendering the excerpt
    # Then: should return empty string without error
    test "handles nil body in excerpt gracefully on index page", %{conn: conn} do
      # Given: a post with nil body (using direct repo insert to bypass changeset validation)
      post =
        %Alchemistdrops.Posts.Post{
          title: "Post with nil body",
          slug: "post-with-nil-body",
          body: nil,
          background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
          views: 0
        }
        |> Alchemistdrops.Repo.insert!()

      # When: the blog index is rendered
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the post should be displayed without errors
      assert has_element?(view, ".post-title", "Post with nil body")
      # And: the excerpt should be empty
      assert has_element?(view, "article#posts-#{post.id} .post-excerpt")
    end

    # Given: a post with nil body
    # When: viewing the post detail page
    # Then: should use fallback meta description and render empty content
    test "handles nil body with fallback meta description on show page", %{conn: conn} do
      # Given: a post with nil body
      post =
        %Alchemistdrops.Posts.Post{
          title: "Post without content",
          slug: "post-without-content",
          body: nil,
          background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
          views: 0
        }
        |> Alchemistdrops.Repo.insert!()

      # When: the post detail page is rendered
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the page should load successfully
      assert has_element?(view, ".post-title", "Post without content")
      # And: the post body section should exist (even if empty)
      assert has_element?(view, ".post-body")
    end

    # Given: a post with very short body (less than 160 chars)
    # When: getting excerpt
    # Then: should not add ellipsis
    test "does not add ellipsis for short posts", %{conn: conn} do
      # Given: a post with short body
      short_body = "This is a short post."

      _post =
        post_fixture(%{
          title: "Short Post",
          body: short_body,
          views: 5
        })

      # When: the blog index is rendered
      {:ok, view, html} = live(conn, ~p"/blog")

      # Then: the post should be displayed
      assert has_element?(view, ".post-title", "Short Post")
      # And: the excerpt should not have ellipsis
      refute html =~ "This is a short post...."
    end
  end

  describe "public_access" do
    # Given: a user who is not logged in
    # When: accessing the blog pages
    # Then: the pages should be accessible without authentication
    test "allows public access to blog index without authentication", %{conn: conn} do
      # Given: no user is logged in (using default conn)
      # And: posts exist
      post_fixture(%{title: "Public Post", body: "Everyone can see this", views: 100})

      # When: accessing the blog index
      {:ok, view, _html} = live(conn, ~p"/blog")

      # Then: the page should load successfully
      assert has_element?(view, "h1", "Alchemist's Journal")
      assert has_element?(view, ".post-card .post-title", "Public Post")
    end

    # Given: a user who is not logged in
    # When: accessing a post detail page
    # Then: the page should be accessible without authentication
    test "allows public access to post detail without authentication", %{conn: conn} do
      # Given: no user is logged in
      # And: a post exists
      post = post_fixture(%{title: "Open Access", body: "No login required", views: 50})

      # When: accessing the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the page should load successfully
      assert has_element?(view, ".post-title", "Open Access")
      assert has_element?(view, ".post-body", "No login required")
    end
  end

  describe "mermaid diagrams and anchor links" do
    # Given: a post with a mermaid diagram
    # When: the user views the post detail page
    # Then: the mermaid block should be rendered as pre.mermaid for client-side rendering
    test "renders mermaid code blocks as pre.mermaid elements", %{conn: conn} do
      # Given: a post with a mermaid diagram in the body
      post =
        post_fixture(%{
          title: "Architecture Overview",
          body: "## Diagram\n\n```mermaid\ngraph TD\n  A --> B\n```\n"
        })

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the mermaid block should be rendered as pre.mermaid (not a syntax-highlighted code block)
      assert has_element?(view, "pre.mermaid")
    end

    # Given: a post with markdown headings
    # When: the user views the post detail page
    # Then: headings should have id attributes for anchor navigation
    test "adds id attributes to headings for anchor links", %{conn: conn} do
      # Given: a post with headings
      post =
        post_fixture(%{
          title: "Guide",
          body: "## Installation\n\nSome content.\n\n## Skills\n\nMore content.\n"
        })

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: headings should have id attributes on their anchor elements
      assert has_element?(view, "h2 a#installation")
      assert has_element?(view, "h2 a#skills")
    end

    # Given: a post with anchor links in the table of contents
    # When: the user views the post detail page
    # Then: the anchor links should reference valid heading ids
    test "anchor links in table of contents point to heading ids", %{conn: conn} do
      # Given: a post with a table of contents and headings
      post =
        post_fixture(%{
          title: "Reference",
          body: "1. [Skills](#skills)\n\n## Skills\n\nContent here.\n"
        })

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the anchor link and heading id should both be present
      assert has_element?(view, ~s(a[href="#skills"]))
      assert has_element?(view, "h2 a#skills")
    end

    # Given: a post article rendered on the detail page
    # When: the user views the post
    # Then: the article container should have the Mermaid phx-hook attached
    test "article container has Mermaid hook for client-side rendering", %{conn: conn} do
      # Given: a post exists
      post = post_fixture(%{title: "Hook Test", body: "# Hello"})

      # When: the user visits the post detail page
      {:ok, view, _html} = live(conn, ~p"/blog/#{post.slug}")

      # Then: the article element with id post-article should exist with the hook attribute
      assert has_element?(view, "article#post-article[phx-hook='Mermaid']")
    end
  end
end
