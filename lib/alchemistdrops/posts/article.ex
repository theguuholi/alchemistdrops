defmodule Alchemistdrops.Posts.Article do
  @moduledoc """
  Derives the rendered body and reading metadata for a blog post.
  """

  alias Alchemistdrops.Markdown
  alias Alchemistdrops.Posts.Post

  @words_per_minute 220

  @typedoc "A rendered level-two or level-three heading used by article navigation."
  @type toc_entry :: %{level: 2 | 3, id: String.t(), label: String.t()}

  @typedoc "Rendered article content and metadata derived from a post."
  @type t :: %{
          html: String.t(),
          toc: [toc_entry()],
          reading_minutes: pos_integer(),
          description: String.t()
        }

  @doc """
  Builds rendered content, table-of-contents entries, reading time, and description.

  A leading level-one heading matching the post title is removed so the page
  does not render the title twice.

  ## Examples

      iex> article = Alchemistdrops.Posts.Article.build(%Alchemistdrops.Posts.Post{title: "Elixir", body: "## Types"}); {article.reading_minutes, article.toc}
      {1, [%{level: 2, id: "types", label: "Types"}]}
  """
  @spec build(Post.t()) :: t()
  def build(%Post{} = post) do
    body = post.body || ""
    renderable_body = remove_duplicate_leading_title(body, post.title)
    {:ok, html} = Markdown.to_html(renderable_body)

    %{
      html: html,
      toc: Markdown.outline(html),
      reading_minutes: reading_minutes(body),
      description: first_present([post.seo_description, post.summary])
    }
  end

  defp remove_duplicate_leading_title(body, title) when is_binary(title) do
    case Regex.run(~r/\A[ \t]{0,3}#(?!#)[ \t]+([^\r\n]+)(?:\r?\n|\z)/u, body) do
      [line, heading] ->
        heading = String.replace(heading, ~r/[ \t]+#+[ \t]*\z/u, "")

        if normalized_inline_text(heading) == normalized_inline_text(title) do
          body
          |> String.replace_prefix(line, "")
          |> String.trim_leading()
        else
          body
        end

      nil ->
        body
    end
  end

  defp remove_duplicate_leading_title(body, _title), do: body

  defp normalized_inline_text(value) do
    {:ok, html} = Markdown.to_html(value)

    html
    |> Markdown.plain_text()
    |> String.downcase()
  end

  defp reading_minutes(body) do
    word_count = ~r/[\p{L}\p{N}]+(?:['’\-][\p{L}\p{N}]+)*/u |> Regex.scan(body) |> length()
    max(1, ceil(word_count / @words_per_minute))
  end

  defp first_present(values) do
    Enum.find_value(values, "", fn
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          present -> present
        end

      _other ->
        nil
    end)
  end
end
