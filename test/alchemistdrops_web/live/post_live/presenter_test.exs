defmodule AlchemistdropsWeb.PostLive.PresenterTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Posts
  alias AlchemistdropsWeb.PostLive.Presenter

  describe "show/1 - public presentation" do
    test "given a published post, when presentation is built, then it returns SEO and article state" do
      # Given
      post =
        post_fixture(%{
          title: "Presenter article",
          body: "## Introduction\n\nPresenter body",
          summary: "Presenter summary",
          seo_title: "Presenter SEO"
        })

      page = Posts.get_published_post_page!(post.slug)

      # When
      presentation = Presenter.show(page)

      # Then
      assert presentation.page_title == "Presenter SEO"
      assert presentation.meta_description == "Presenter summary"
      assert presentation.meta_url == "http://localhost:4002/blog/#{post.slug}"
      assert presentation.page_language == "en"
      assert presentation.meta_locale == "en_US"
      assert presentation.post.id == post.id
      assert presentation.article.toc != []
      assert presentation.copy.back == "Back to all posts"
    end

    test "given a blank SEO title and Portuguese post, when presentation is built, then it uses localized defaults" do
      # Given
      post =
        post_fixture(%{
          title: "Artigo público",
          body: "Conteúdo em português",
          summary: "Resumo público",
          seo_title: "   ",
          language: :pt_br
        })

      page = Posts.get_published_post_page!(post.slug)

      # When
      presentation = Presenter.show(page)

      # Then
      assert presentation.page_title == "Artigo público"
      assert presentation.page_language == "pt-BR"
      assert presentation.meta_locale == "pt_BR"
      assert presentation.copy.back == "Voltar ao blog"
    end
  end
end
