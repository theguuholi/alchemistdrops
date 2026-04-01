defmodule Alchemistdrops.Markdown do
  @moduledoc """
  Shared Markdown → HTML for blog posts and admin preview.

  Enables GitHub Flavored Markdown extensions (especially **tables**) so pipe tables
  render as `<table>` instead of literal paragraph text.

  Also enables:
  - Heading IDs for anchor navigation (e.g. `## Skills` → `id="skills"`)
  - Mermaid diagram blocks rendered as `<pre class="mermaid">` for client-side rendering
  """

  @extension_opts [
    table: true,
    strikethrough: true,
    autolink: true,
    tasklist: true,
    header_ids: ""
  ]

  @doc """
  Converts Markdown to HTML with GFM extensions and wraps `<table>` in
  `.table-wrapper` for prose styles in `app.css`.

  Heading IDs are generated so anchor links like `[Section](#section)` work.
  Mermaid code blocks are converted to `<pre class="mermaid">` for client-side rendering.

  Always returns `{:ok, html_string}`.
  """
  @spec to_html(String.t()) :: {:ok, String.t()}
  def to_html(content) when is_binary(content) and byte_size(content) > 0 do
    {:ok, doc} = MDEx.parse_document(content, extension: @extension_opts)

    {:ok, html} =
      doc
      |> transform_mermaid()
      |> MDEx.to_html(render: [unsafe: true])

    {:ok, wrap_tables_for_styling(html)}
  end

  def to_html(_), do: {:ok, ""}

  defp transform_mermaid(document) do
    MDEx.Document.update_nodes(
      document,
      &match?(%MDEx.CodeBlock{info: "mermaid"}, &1),
      &%MDEx.HtmlBlock{literal: "<pre class=\"mermaid\">#{&1.literal}</pre>", nodes: []}
    )
  end

  defp wrap_tables_for_styling(html) when is_binary(html) do
    html
    |> String.replace("<table", "<div class=\"table-wrapper\"><table")
    |> String.replace("</table>", "</table></div>")
  end
end
