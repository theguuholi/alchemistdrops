defmodule AlchemistdropsWeb.AboutLiveTest do
  use AlchemistdropsWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "About page" do
    test "renders about page successfully", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/about")
      assert html =~ "Gustavo Oliveira"
      assert html =~ "Software Engineer"
    end

    test "displays hero with name and location", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      assert html =~ "Gustavo Oliveira"
      assert html =~ "São Paulo, Brazil"
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
      {:ok, _lv, html} = live(conn, ~p"/about")

      assert html =~ "About"
      assert html =~ "Agile Methodologies"
      assert html =~ "Evolutive Engineering"
    end

    test "renders Career journey with roles", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/about")

      assert html =~ "Career journey"
      assert html =~ "Stord"
      assert html =~ "Lolo"
      assert html =~ "Clarus R+D"
      assert html =~ "Senior Software Engineer"
    end

    test "renders Portfolio placeholder", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/about")

      assert html =~ "Portfolio"
      assert html =~ "Coming soon"
    end

    test "renders contact CTA with LinkedIn and Email", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/about")

      assert html =~ "connect"
      assert html =~ "LinkedIn"
      assert html =~ "Email"
    end

    test "renders Digital Twin section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/about")

      assert html =~ "Chat with my Digital Twin"
      # When OPENROUTER_API_KEY is not set, placeholder is shown
      assert html =~ "OPENROUTER_API_KEY"
    end
  end
end
