defmodule AlchemistdropsWeb.HomeLiveTest do
  use AlchemistdropsWeb.ConnCase
  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Repo

  describe "HomeLive" do
    test "renders home page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#home-page", "Master Elixir at Your Own Pace")
    end

    test "displays hero section with main heading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#home-page header h1", "Master Elixir at Your Own Pace")
      assert has_element?(view, "#home-page header p", "Learn Elixir, Phoenix, and LiveView")
    end

    test "shows logo image", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "img[alt='Alchemistdrops Logo']")
    end

    test "displays call-to-action buttons in hero", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='#pricing']", "Start Learning Today")
      assert has_element?(view, "a[href='#course']", "Explore Course Details")
    end

    test "renders Why Choose Elixir section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#why-elixir", "Why Choose Elixir?")
      assert has_element?(view, "h3", "Scalable & Fast")
      assert has_element?(view, "h3", "Functional & Elegant")
      assert has_element?(view, "h3", "Reliable & Fault-Tolerant")
    end

    test "displays course features section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#course", "Why Choose This Course?")
      assert has_element?(view, "#course", "Flexible Learning at Your Own Pace")
      assert has_element?(view, "#course", "Real-World Examples and Practical Skills")
      assert has_element?(view, "#course", "Learn LiveView with Test-Driven Development")
    end

    test "shows What You'll Learn section with learning items", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "section#what-youll-learn")
      assert has_element?(view, "h3", "Building and Deploying LiveView Apps")
      assert has_element?(view, "h3", "Crafting Scalable Applications with Phoenix")
      assert has_element?(view, "h3", "Real-World Project Creation, Debugging, and Optimization")
      assert has_element?(view, "h3", "Functional Programming Techniques")
      assert has_element?(view, "h3", "Integrating Elixir with Modern Tools and APIs")
    end

    test "displays instructor section with bio", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#instructor", "About the Instructor")
      assert has_element?(view, "#instructor", "Gustavo Oliveira")
      assert has_element?(view, "#instructor", "Brazilian software engineer and educator")
      assert has_element?(view, "img[alt='Gustavo Oliveira - Elixir Instructor']")
    end

    test "renders pricing section with both plans", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#pricing", "Flexible Pricing Plans")
      assert has_element?(view, "#pricing", "Monthly Plan")
      assert has_element?(view, "#pricing", "$9")
      assert has_element?(view, "#pricing", "Yearly Plan")
      assert has_element?(view, "#pricing", "$53")
      assert has_element?(view, "#pricing", "Save $55")
      assert has_element?(view, "#pricing", "Best Value")

      assert has_element?(
               view,
               "a[href='https://buy.stripe.com/fZe8xxbJHcnT6wU8wW']",
               "Subscribe Monthly"
             )

      assert has_element?(
               view,
               "a[href='https://buy.stripe.com/5kAeVVdRPew13kIdRi']",
               "Subscribe Yearly"
             )
    end

    test "shows pricing features list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#pricing", "Full access to all course content")
      assert has_element?(view, "#pricing", "Access to private Elixir community")
      assert has_element?(view, "#pricing", "Downloadable resources and guides")
      assert has_element?(view, "#pricing", "Priority support")
    end

    test "displays FAQ section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#faq", "Frequently Asked Questions")
      assert has_element?(view, "#faq", "What exactly is Alchemistdrops?")
      assert has_element?(view, "#faq", "Are the classes hands-on?")
      assert has_element?(view, "#faq", "How long will I have access to the course?")
      assert has_element?(view, "#faq", "How does the support work?")
    end

    test "renders final CTA section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#home-page", "Ready to Take the Next Step")
      assert has_element?(view, "#home-page", "Build real-world projects and join")
      assert has_element?(view, "a[href='#pricing']", "Start Learning Today")
    end

    test "has proper semantic HTML structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Check for semantic sections
      assert has_element?(view, "header")
      assert has_element?(view, "section#course")
      assert has_element?(view, "section#what-youll-learn")
      assert has_element?(view, "section#instructor")
      assert has_element?(view, "section#pricing")
      assert has_element?(view, "section#faq")
    end

    test "external links have proper security attributes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#pricing a[target='_blank'][rel='noopener noreferrer']")
    end

    test "images have lazy loading attributes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "img[loading='lazy']")
    end

    test "all images have alt text for accessibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Check that img elements exist with alt attributes
      assert has_element?(view, "img[alt='Alchemistdrops Logo']")
      assert has_element?(view, "img[alt='Gustavo Oliveira - Elixir Instructor']")
    end

    test "FAQ items are expandable details elements", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Details/summary elements for FAQ
      assert has_element?(view, "details summary")
    end

    test "assigns learn_items on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify all 5 learning items are displayed
      assert has_element?(view, "h3", "Building and Deploying LiveView Apps")
      assert has_element?(view, "h3", "Crafting Scalable Applications with Phoenix")
      assert has_element?(view, "h3", "Real-World Project Creation, Debugging, and Optimization")
      assert has_element?(view, "h3", "Functional Programming Techniques")
      assert has_element?(view, "h3", "Integrating Elixir with Modern Tools and APIs")
    end

    test "assigns faq_items on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify key FAQ items are displayed
      assert has_element?(view, "summary", "What exactly is Alchemistdrops?")
      assert has_element?(view, "summary", "Are the classes hands-on?")
      assert has_element?(view, "summary", "How long will I have access to the course?")
      assert has_element?(view, "summary", "How does the support work?")
      assert has_element?(view, "summary", "I'm a beginner in Elixir. Will this course help me?")
    end

    test "page title is set correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      document = LazyHTML.from_document(html)
      assert LazyHTML.text(LazyHTML.query(document, "title")) =~ "Master Elixir - Alchemistdrops"
    end

    test "shows exactly the three most recent published articles", %{conn: conn} do
      Enum.each(1..4, fn number -> post_fixture(%{title: "Recent article #{number}"}) end)
      draft_post_fixture(%{title: "Homepage draft"})

      {:ok, view, _html} = live(conn, ~p"/")

      recent_html = view |> element("#recent-articles") |> render()

      assert recent_html |> LazyHTML.from_fragment() |> LazyHTML.query("article") |> Enum.count() ==
               3

      refute has_element?(view, "#recent-articles", "Homepage draft")
      assert has_element?(view, "#recent-articles a[href='/blog']", "View all articles")
    end

    test "renders a legacy published article without a category", %{conn: conn} do
      post = post_fixture(%{title: "Legacy homepage article"})

      post
      |> Ecto.Changeset.change(category_id: nil)
      |> Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#recent-articles article", "Legacy homepage article")
      assert has_element?(view, "#recent-articles article", "Uncategorized")
    end
  end
end
