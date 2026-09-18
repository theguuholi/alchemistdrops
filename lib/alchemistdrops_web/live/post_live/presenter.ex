defmodule AlchemistdropsWeb.PostLive.Presenter do
  @moduledoc """
  Builds presentation-only state for the public post detail LiveView.

  It keeps localized copy, SEO metadata, canonical URLs, and rendered article
  data out of LiveView callbacks without owning persistence or domain rules.
  """

  alias Alchemistdrops.Posts.Article
  alias Alchemistdrops.Posts.Post

  @type assigns :: %{
          page_title: String.t() | nil,
          meta_description: String.t(),
          meta_url: String.t(),
          meta_type: String.t(),
          meta_image: String.t() | nil,
          meta_locale: String.t(),
          page_language: String.t(),
          article_published_at: String.t(),
          article_modified_at: String.t(),
          json_ld: map(),
          post: Post.t(),
          article: Article.t(),
          article_html: Phoenix.HTML.safe(),
          related_course: struct() | nil,
          related_posts: [Post.t()],
          copy: map()
        }

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

  @doc """
  Converts public post page data into assigns consumed by the detail template.
  """
  @spec show(Alchemistdrops.Posts.published_post_page()) :: assigns()
  def show(%{post: post, related_course: related_course, related_posts: related_posts}) do
    article = Article.build(post)
    canonical_url = build_url("/blog/#{post.slug}")
    image_url = post.cover_image_url || build_url("/images/logo.svg")
    page_language = language(post.language)

    %{
      page_title: present(post.seo_title) || post.title,
      meta_description: article.description,
      meta_url: canonical_url,
      meta_type: "article",
      meta_image: image_url,
      meta_locale: locale(post.language),
      page_language: page_language,
      article_published_at: DateTime.to_iso8601(post.published_at),
      article_modified_at: DateTime.to_iso8601(post.updated_at),
      json_ld: json_ld(post, article, canonical_url, image_url, page_language),
      post: post,
      article: article,
      article_html: Phoenix.HTML.raw(article.html),
      related_course: related_course,
      related_posts: related_posts,
      copy: Map.fetch!(@copy, post.language)
    }
  end

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
