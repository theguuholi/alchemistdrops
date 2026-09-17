defmodule AlchemistdropsWeb.HomeLiveTest do
  use AlchemistdropsWeb.ConnCase
  import Phoenix.LiveViewTest
  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Repo

  describe "HomeLive" do
    test "renders home page successfully", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Master Elixir at Your Own Pace"
    end

    test "displays hero section with main heading", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Master Elixir at Your Own Pace with Real-World Projects"
      assert html =~ "Learn Elixir, Phoenix, and LiveView"
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
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Why Choose Elixir?"
      assert has_element?(view, "h3", "Scalable & Fast")
      assert has_element?(view, "h3", "Functional & Elegant")
      assert has_element?(view, "h3", "Reliable & Fault-Tolerant")
    end

    test "displays course features section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Why Choose This Course?"
      assert html =~ "Flexible Learning at Your Own Pace"
      assert html =~ "Real-World Examples and Practical Skills"
      assert html =~ "Learn LiveView with Test-Driven Development"
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
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "About the Instructor"
      assert html =~ "Gustavo Oliveira"
      assert html =~ "Brazilian software engineer and educator"
      assert has_element?(view, "img[alt='Gustavo Oliveira - Elixir Instructor']")
    end

    test "renders pricing section with both plans", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Flexible Pricing Plans"
      assert html =~ "Monthly Plan"
      assert html =~ "$9"
      assert html =~ "Yearly Plan"
      assert html =~ "$53"
      assert html =~ "Save $55"
      assert html =~ "Best Value"

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
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Full access to all course content"
      assert html =~ "Access to private Elixir community"
      assert html =~ "Downloadable resources and guides"
      assert html =~ "Priority support"
    end

    test "displays FAQ section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Frequently Asked Questions"
      assert html =~ "What exactly is Alchemistdrops?"
      assert html =~ "Are the classes hands-on?"
      assert html =~ "How long will I have access to the course?"
      assert html =~ "How does the support work?"
    end

    test "renders final CTA section", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Ready to Take the Next Step in Your Elixir Journey?"
      assert html =~ "Build real-world projects and join a thriving community"
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
      {:ok, _lv, html} = live(conn, ~p"/")

      # Check Stripe links have target and rel attributes
      assert html =~ ~s(target="_blank")
      assert html =~ ~s(rel="noopener noreferrer")
    end

    test "images have lazy loading attributes", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ ~s(loading="lazy")
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

      assert html =~ "Master Elixir - Alchemistdrops"
    end

    test "shows exactly the three most recent published articles", %{conn: conn} do
      Enum.each(1..4, fn number -> post_fixture(%{title: "Recent article #{number}"}) end)
      draft_post_fixture(%{title: "Homepage draft"})

      {:ok, view, html} = live(conn, ~p"/")

      recent_html = view |> element("#recent-articles") |> render()
      assert length(Regex.scan(~r/<article\b/, recent_html)) == 3
      refute html =~ "Homepage draft"
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
