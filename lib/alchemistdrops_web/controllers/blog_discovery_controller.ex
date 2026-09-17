defmodule AlchemistdropsWeb.BlogDiscoveryController do
  use AlchemistdropsWeb, :controller

  alias Alchemistdrops.Posts

  def sitemap(conn, _params) do
    urls =
      ["/", "/blog", "/courses", "/about"] ++
        Enum.map(Posts.list_all_published_posts(), &"/blog/#{&1.slug}")

    entries =
      Enum.map_join(urls, "\n", fn path ->
        "  <url><loc>#{xml_escape(absolute_url(path))}</loc></url>"
      end)

    xml =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n#{entries}\n</urlset>"

    xml_response(conn, xml)
  end

  def feed(conn, _params) do
    posts = Posts.list_recent_published_posts(20)
    updated_at = posts |> List.first() |> feed_updated_at()

    entries =
      Enum.map_join(posts, "\n", fn post ->
        url = absolute_url("/blog/#{post.slug}")

        """
          <entry>
            <title>#{xml_escape(post.title)}</title>
            <id>#{xml_escape(url)}</id>
            <link href="#{xml_escape(url)}" />
            <updated>#{DateTime.to_iso8601(post.updated_at)}</updated>
            <published>#{DateTime.to_iso8601(post.published_at)}</published>
            <summary>#{xml_escape(post.summary)}</summary>
          </entry>
        """
      end)

    feed_url = absolute_url("/blog/feed.xml")

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Alchemistdrops Journal</title>
      <id>#{xml_escape(absolute_url("/blog"))}</id>
      <link href="#{xml_escape(feed_url)}" rel="self" />
      <updated>#{DateTime.to_iso8601(updated_at)}</updated>
    #{entries}
    </feed>
    """

    xml_response(conn, xml)
  end

  defp feed_updated_at(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp feed_updated_at(post), do: post.updated_at

  defp absolute_url(path), do: AlchemistdropsWeb.Endpoint.url() <> path

  defp xml_response(conn, body) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, body)
  end

  defp xml_escape(nil), do: ""

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
