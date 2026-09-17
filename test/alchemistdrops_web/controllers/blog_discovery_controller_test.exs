defmodule AlchemistdropsWeb.BlogDiscoveryControllerTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.PostsFixtures

  test "sitemap lists canonical public pages and published articles only", %{conn: conn} do
    published = post_fixture(%{title: "Discoverable article"})
    draft = draft_post_fixture(%{title: "Private draft"})

    conn = get(conn, ~p"/sitemap.xml")
    body = response(conn, 200)

    assert get_resp_header(conn, "content-type") |> hd() =~ "application/xml"
    assert body =~ "http://localhost:4002/blog/#{published.slug}"
    assert body =~ "http://localhost:4002/courses"
    refute body =~ draft.slug
  end

  test "Atom feed contains recent published articles and escapes editorial text", %{conn: conn} do
    published = post_fixture(%{title: "Elixir & Phoenix", summary: "Fast < reliable"})
    draft = draft_post_fixture(%{title: "Unreleased feed item"})

    conn = get(conn, ~p"/blog/feed.xml")
    body = response(conn, 200)

    assert get_resp_header(conn, "content-type") |> hd() =~ "application/xml"
    assert body =~ "<feed xmlns=\"http://www.w3.org/2005/Atom\">"
    assert body =~ "Elixir &amp; Phoenix"
    assert body =~ "Fast &lt; reliable"
    assert body =~ "/blog/#{published.slug}"
    refute body =~ draft.slug
  end
end
