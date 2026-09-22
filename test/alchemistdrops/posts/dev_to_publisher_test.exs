defmodule Alchemistdrops.Posts.DevToPublisherTest do
  use ExUnit.Case, async: true

  alias Alchemistdrops.Posts.{DevToPublisher, Post, Tag}

  setup {Req.Test, :verify_on_exit!}

  describe "sync_article/3" do
    test "given a new Portuguese article, when synchronized, then it creates a published DEV.to article with the original reference" do
      post = published_post()
      canonical_url = "https://alchemistdrops.com/blog/otp-em-producao"

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/articles"
        assert Plug.Conn.get_req_header(conn, "api-key") == ["dev-api-key"]
        assert Plug.Conn.get_req_header(conn, "accept") == ["application/vnd.forem.api-v1+json"]

        assert Jason.decode!(Req.Test.raw_body(conn)) == %{
                 "article" => %{
                   "body_markdown" =>
                     "## Corpo do artigo\n\n---\n\n_Este artigo foi publicado originalmente em [AlchemistDrops](https://alchemistdrops.com/blog/otp-em-producao)._",
                   "canonical_url" => canonical_url,
                   "description" => "Uma introdução prática",
                   "main_image" => "https://alchemistdrops.com/images/otp.png",
                   "published" => true,
                   "tags" => "elixir,phoenix,liveview,otp",
                   "title" => "OTP em produção"
                 }
               }

        Req.Test.json(conn, %{
          "id" => 731,
          "url" => "https://dev.to/theguuholi/article-731"
        })
      end)

      assert {:ok, %{article_id: 731, url: "https://dev.to/theguuholi/article-731"}} =
               DevToPublisher.sync_article(post, canonical_url, options())
    end

    test "given a previously synchronized article, when synchronized, then it updates the stored DEV.to article" do
      post = %{published_post() | dev_to_article_id: 731}

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/articles/731"

        Req.Test.json(conn, %{
          "id" => 731,
          "url" => "https://dev.to/theguuholi/article-731"
        })
      end)

      assert {:ok, %{article_id: 731}} =
               DevToPublisher.sync_article(
                 post,
                 "https://alchemistdrops.com/blog/otp-em-producao",
                 options()
               )
    end

    test "given an update response with another article ID, when synchronized, then it rejects the response" do
      post = %{published_post() | dev_to_article_id: 731}

      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"id" => 999, "url" => "https://dev.to/theguuholi/wrong"})
      end)

      assert {:error, :invalid_response} =
               DevToPublisher.sync_article(
                 post,
                 "https://alchemistdrops.com/blog/otp-em-producao",
                 options()
               )
    end

    test "given an English article, when synchronized, then it appends an English original reference" do
      post = %{published_post() | language: :en, body: "Article body"}

      Req.Test.expect(__MODULE__, fn conn ->
        assert Jason.decode!(Req.Test.raw_body(conn))["article"]["body_markdown"] ==
                 "Article body\n\n---\n\n_This article was originally published on [AlchemistDrops](https://alchemistdrops.com/blog/english)._"

        Req.Test.json(conn, %{
          "id" => 731,
          "url" => "https://dev.to/theguuholi/article-731"
        })
      end)

      assert {:ok, _publication} =
               DevToPublisher.sync_article(
                 post,
                 "https://alchemistdrops.com/blog/english",
                 options()
               )
    end

    test "given missing credentials, when synchronized, then it returns a configuration error without calling HTTP" do
      assert {:error, :not_configured} =
               DevToPublisher.sync_article(
                 published_post(),
                 "https://alchemistdrops.com/blog/otp",
                 Keyword.put(options(), :api_key, nil)
               )
    end

    test "given a draft, when synchronized, then it rejects the request without calling HTTP" do
      assert {:error, :post_not_published} =
               DevToPublisher.sync_article(
                 %{published_post() | status: :draft},
                 "https://alchemistdrops.com/blog/otp",
                 options()
               )
    end

    test "given a transport failure, when synchronized, then it returns a safe request error" do
      Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :timeout))

      assert {:error, :request_failed} =
               DevToPublisher.sync_article(
                 published_post(),
                 "https://alchemistdrops.com/blog/otp",
                 options()
               )
    end

    test "given a rejected DEV.to response, when synchronized, then it returns only the status" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"error" => "Validation failed", "details" => ["Tag invalid"]})
      end)

      assert {:error, {:api_error, 422}} =
               DevToPublisher.sync_article(
                 published_post(),
                 "https://alchemistdrops.com/blog/otp",
                 options()
               )
    end

    test "given an error that reflects credentials, when synchronized, then it never returns remote content" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "dev-api-key", "details" => [%{"nested" => true}]})
      end)

      assert {:error, {:api_error, 500}} =
               DevToPublisher.sync_article(
                 published_post(),
                 "https://alchemistdrops.com/blog/otp",
                 options()
               )
    end

    test "given an incomplete success response, when synchronized, then it returns an invalid response error" do
      Req.Test.expect(__MODULE__, fn conn -> Req.Test.json(conn, %{"id" => 731}) end)

      assert {:error, :invalid_response} =
               DevToPublisher.sync_article(
                 published_post(),
                 "https://alchemistdrops.com/blog/otp",
                 options()
               )
    end
  end

  defp options do
    [
      api_key: "dev-api-key",
      req_options: [plug: {Req.Test, __MODULE__}, retry: false]
    ]
  end

  defp published_post do
    %Post{
      status: :published,
      title: "OTP em produção",
      body: "## Corpo do artigo",
      summary: "Uma introdução prática",
      cover_image_url: "https://alchemistdrops.com/images/otp.png",
      language: :pt_br,
      tags: [
        %Tag{name: "Elixir", slug: "elixir"},
        %Tag{name: "Phoenix", slug: "phoenix"},
        %Tag{name: "LiveView", slug: "liveview"},
        %Tag{name: "OTP", slug: "otp"},
        %Tag{name: "BEAM", slug: "beam"}
      ]
    }
  end
end
