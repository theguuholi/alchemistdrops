defmodule AlchemistdropsWeb.AboutLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "About page" do
    test "renders about page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")
      assert has_element?(view, "#about-page", "Gustavo Oliveira")
      assert has_element?(view, "#about-page", "Software Engineer")
    end

    test "displays hero with name and location", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#about-page", "Gustavo Oliveira")
      assert has_element?(view, "#about-page", "São Paulo, Brazil")
      assert has_element?(view, "img[alt='Gustavo Oliveira']")
    end

    test "has LinkedIn and contact links", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(
               view,
               "a[href='https://www.linkedin.com/in/devgustavooliveira']",
               "LinkedIn"
             )

      assert has_element?(view, "a[href='mailto:g.92oliveira@gmail.com']", "Contact")
    end

    test "renders About section with tagline", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#about-page", "About")
      assert has_element?(view, "#about-page", "Elixir/OTP")
      assert has_element?(view, "#about-page", "Distributed Systems")
    end

    test "renders Experience section with roles", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#about-page", "Experience")
      assert has_element?(view, "#about-page", "Stord")
      assert has_element?(view, "#about-page", "Lolo")
      assert has_element?(view, "#about-page", "Clarus R+D")
      assert has_element?(view, "#about-page", "Senior Software Engineer")
    end

    test "renders Portfolio placeholder", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#about-page", "Portfolio")
      assert has_element?(view, "#about-page", "Coming soon")
    end

    test "renders contact CTA with LinkedIn and Email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#contact-heading", "connect")
      assert has_element?(view, "#about-page", "LinkedIn")
      assert has_element?(view, "#about-page", "Email")
    end

    test "renders Digital Twin section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#digital-twin-heading", "Chat with my Digital Twin")

      if has_element?(view, "#digital-twin-unavailable") do
        assert has_element?(view, "#digital-twin-unavailable", "OPENROUTER_API_KEY")
      else
        assert has_element?(view, "#digital-twin-form")
      end
    end
  end
end
