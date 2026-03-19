defmodule Alchemistdrops.MarkdownTest do
  use ExUnit.Case, async: true

  alias Alchemistdrops.Markdown

  describe "to_html/1" do
    test "renders GFM pipe tables as HTML tables" do
      md = """
      | Term | Meaning |
      |------|---------|
      | **LLM** | Large Language Model. |
      """

      assert {:ok, html} = Markdown.to_html(md)
      assert html =~ "<table"
      assert html =~ "<thead>"
      assert html =~ "<th>"
      assert html =~ "LLM"
      refute html =~ "<p>| Term | Meaning |"
    end

    test "wraps tables in table-wrapper for prose CSS" do
      md = "| a | b |\n|---|---|\n| 1 | 2 |\n"

      assert {:ok, html} = Markdown.to_html(md)
      assert html =~ ~s(<div class="table-wrapper"><table)
      assert html =~ "</table></div>"
    end

    test "returns empty string for empty input" do
      assert {:ok, ""} = Markdown.to_html("")
    end
  end
end
