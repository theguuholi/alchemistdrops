defmodule Alchemistdrops.MarkdownTest do
  use ExUnit.Case, async: true

  doctest Alchemistdrops.Markdown

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

    test "adds id attributes to heading anchors for navigation" do
      md = "## Skills\n\n### Sub Section\n\n## Another Heading\n"

      assert {:ok, html} = Markdown.to_html(md)
      # MDEx generates <h2><a id="skills" ...></a>Skills</h2>
      assert html =~ ~s(<a href="#skills" aria-hidden="true" class="anchor" id="skills">)
      assert html =~ ~s(id="sub-section")
      assert html =~ ~s(id="another-heading")
    end

    test "anchor links pointing to heading ids resolve correctly" do
      md = "## My Section\n\n[Jump to section](#my-section)\n"

      assert {:ok, html} = Markdown.to_html(md)
      assert html =~ ~s(id="my-section")
      assert html =~ ~s(href="#my-section")
    end

    test "renders mermaid code blocks as pre.mermaid elements" do
      md = "```mermaid\ngraph TD\n  A --> B\n```\n"

      assert {:ok, html} = Markdown.to_html(md)
      assert html =~ ~s(<pre class="mermaid">)
      assert html =~ "graph TD"
      refute html =~ ~s(class="language-mermaid")
    end

    test "mermaid block preserves diagram source" do
      md = "```mermaid\nsequenceDiagram\n  Alice ->> Bob: Hello\n```\n"

      assert {:ok, html} = Markdown.to_html(md)
      assert html =~ ~s(<pre class="mermaid">)
      assert html =~ "sequenceDiagram"
      assert html =~ "Alice ->> Bob: Hello"
    end

    test "non-mermaid code blocks are not affected" do
      md = "```elixir\ndef hello, do: :world\n```\n"

      assert {:ok, html} = Markdown.to_html(md)
      refute html =~ ~s(<pre class="mermaid">)
      assert html =~ "hello"
    end
  end
end
