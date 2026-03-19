defmodule Alchemistdrops.Markdown do
  @moduledoc """
  Shared Markdown → HTML for blog posts and admin preview.

  Enables GitHub Flavored Markdown extensions (especially **tables**) so pipe tables
  render as `<table>` instead of literal paragraph text.
  """

  @mdex_opts [
    extension: [
      table: true,
      strikethrough: true,
      autolink: true,
      tasklist: true
    ]
  ]

  @doc """
  Converts Markdown to HTML with GFM extensions and wraps `<table>` in
  `.table-wrapper` for prose styles in `app.css`.

  Always returns `{:ok, html_string}`.
  """
  @spec to_html(String.t()) :: {:ok, String.t()}
  def to_html(content) when is_binary(content) and byte_size(content) > 0 do
    {:ok, html} = MDEx.to_html(content, @mdex_opts)
    {:ok, wrap_tables_for_styling(html)}
  end

  def to_html(_), do: {:ok, ""}

  defp wrap_tables_for_styling(html) when is_binary(html) do
    html
    |> String.replace("<table", "<div class=\"table-wrapper\"><table")
    |> String.replace("</table>", "</table></div>")
  end
end
