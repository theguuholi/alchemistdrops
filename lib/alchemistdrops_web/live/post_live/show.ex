defmodule AlchemistdropsWeb.PostLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Article

  @copy %{
    en: %{
      back: "Back to all posts",
      outline: "In this article",
      minute: "min read",
      updated: "Last updated",
      course_eyebrow: "Continue learning",
      course_action: "Explore course",
      related: "Related articles",
      author: "Written by Gustavo Oliveira"
    },
    pt_br: %{
      back: "Voltar ao blog",
      outline: "Neste artigo",
      minute: "min de leitura",
      updated: "Atualizado em",
      course_eyebrow: "Continue aprendendo",
      course_action: "Conhecer curso",
      related: "Artigos relacionados",
      author: "Escrito por Gustavo Oliveira"
    }
  }

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    post = get_post_by_slug_or_id!(slug)

    if post.slug != slug do
      {:ok, push_navigate(socket, to: ~p"/blog/#{post.slug}")}
    else
      mount_post(socket, post)
    end
  end

  defp mount_post(socket, post) do
    if connected?(socket), do: Posts.increment_views(post)

    article = Article.build(post)
    canonical_url = build_url(~p"/blog/#{post.slug}")
    image_url = post.cover_image_url || build_url(~p"/images/logo.svg")
    page_title = present(post.seo_title) || post.title
    page_language = language(post.language)

    {:ok,
     socket
     |> assign(:page_title, page_title)
     |> assign(:meta_description, article.description)
     |> assign(:meta_url, canonical_url)
     |> assign(:meta_type, "article")
     |> assign(:meta_image, image_url)
     |> assign(:meta_locale, locale(post.language))
     |> assign(:page_language, page_language)
     |> assign(:article_published_at, DateTime.to_iso8601(post.published_at))
     |> assign(:article_modified_at, DateTime.to_iso8601(post.updated_at))
     |> assign(:json_ld, json_ld(post, article, canonical_url, image_url, page_language))
     |> assign(:post, post)
     |> assign(:article, article)
     |> assign(:article_html, Phoenix.HTML.raw(article.html))
     |> assign(:related_course, published_course(post.related_course))
     |> assign(:related_posts, Posts.list_related_posts(post, 3))
     |> assign(:copy, Map.fetch!(@copy, post.language))}
  end

  defp get_post_by_slug_or_id!(slug) do
    case Posts.get_published_post_by_slug(slug) do
      nil -> get_post_by_legacy_id!(slug)
      post -> post
    end
  end

  defp get_post_by_legacy_id!(slug) do
    case Ecto.UUID.cast(slug) do
      {:ok, id} -> Posts.get_published_post_by_id!(id)
      :error -> Posts.get_published_post_by_slug!(slug)
    end
  end

  defp published_course(%{published: true} = course), do: course
  defp published_course(_course), do: nil

  defp format_date(datetime), do: Calendar.strftime(datetime, "%B %d, %Y")
  defp build_url(path), do: AlchemistdropsWeb.Endpoint.url() <> path

  defp language(:pt_br), do: "pt-BR"
  defp language(_language), do: "en"

  defp locale(:pt_br), do: "pt_BR"
  defp locale(_language), do: "en_US"

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp present(_value), do: nil

  defp json_ld(post, article, canonical_url, image_url, page_language) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => post.title,
      "description" => article.description,
      "image" => image_url,
      "author" => %{"@type" => "Person", "name" => "Gustavo Oliveira"},
      "datePublished" => DateTime.to_iso8601(post.published_at),
      "dateModified" => DateTime.to_iso8601(post.updated_at),
      "inLanguage" => page_language,
      "mainEntityOfPage" => canonical_url
    }
  end
end
