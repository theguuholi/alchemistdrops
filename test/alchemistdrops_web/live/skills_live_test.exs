defmodule AlchemistdropsWeb.SkillsLiveTest do
  use AlchemistdropsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AlchemistdropsWeb.SkillsLive.Components

  doctest AlchemistdropsWeb.SkillsLive.Components
  doctest AlchemistdropsWeb.SkillsLive.Index

  @skills ~w(
    ecto-development
    elixir-development
    phoenix-authentication
    phoenix-development
    phoenix-js-hooks
    phoenix-liveview-testing
    phoenix-liveview
  )
  @version "docs/agent-toolkit/VERSION" |> File.read!() |> String.trim()

  describe "toolkit_introduction/1 - semantic structure" do
    test "given the toolkit version, when the introduction renders, then its regions describe their purpose" do
      # Given / When
      document =
        (&Components.toolkit_introduction/1)
        |> render_component(version: @version)
        |> LazyHTML.from_fragment()

      # Then
      assert Enum.count(
               LazyHTML.query(
                 document,
                 "header#toolkit-introduction"
               )
             ) == 1

      assert Enum.count(
               LazyHTML.query(
                 document,
                 "header#toolkit-introduction > section[aria-labelledby='toolkit-heading'] h1#toolkit-heading"
               )
             ) == 1

      assert Enum.count(
               LazyHTML.query(
                 document,
                 "aside#toolkit-download[aria-label='Toolkit download'] #download-complete-toolkit"
               )
             ) == 1
    end
  end

  describe "mount/3 - public skill catalog" do
    test "given a visitor, when they open the catalog, then it presents the complete toolkit",
         %{conn: conn} do
      # Given / When
      {:ok, view, _html} = live(conn, ~p"/skills")

      # Then
      assert has_element?(view, "main#skills-page", "Elixir agent toolkit")

      assert has_element?(
               view,
               "#download-complete-toolkit[href='/downloads/agent-toolkit/alchemistdrops-agent-toolkit-v#{@version}.zip'][download]",
               "Download complete toolkit"
             )

      assert has_element?(view, "#installation-guide", "Install in a project")
      assert has_element?(view, "#safety-rules", "Rules protect dangerous commands")
    end

    test "given the catalog, when a visitor compares skills, then every skill explains its advantage",
         %{conn: conn} do
      # Given / When
      {:ok, view, _html} = live(conn, ~p"/skills")

      # Then
      expected_skills = [
        {"ecto-development", "Keeps schemas and data changes explicit"},
        {"elixir-development", "Makes Elixir modules easier to understand"},
        {"phoenix-authentication", "Protects authentication boundaries"},
        {"phoenix-development", "Keeps Phoenix interfaces consistent"},
        {"phoenix-js-hooks", "Connects LiveView and JavaScript safely"},
        {"phoenix-liveview-testing", "Tests behavior through stable DOM contracts"},
        {"phoenix-liveview", "Keeps LiveViews focused on interface orchestration"}
      ]

      for {slug, advantage} <- expected_skills do
        assert has_element?(view, "article#skill-#{slug}", advantage)

        assert has_element?(
                 view,
                 "#download-#{slug}[href='/downloads/agent-toolkit/#{slug}-v#{@version}.zip'][download]",
                 "Download skill"
               )
      end
    end

    test "given the catalog, when a visitor chooses rules only, then it offers the safety package separately",
         %{conn: conn} do
      # Given / When
      {:ok, view, _html} = live(conn, ~p"/skills")

      # Then
      assert has_element?(
               view,
               "#download-safety-rules[href='/downloads/agent-toolkit/elixir-safety-rules-v#{@version}.zip'][download]",
               "Download safety rules"
             )

      assert has_element?(view, "#safety-rules", "optional")

      assert has_element?(
               view,
               "#safety-rules code",
               "unzip elixir-safety-rules-v#{@version}.zip -d ."
             )
    end
  end

  describe "static downloads - versioned archives" do
    test "given published artifacts, when they are requested, then every archive is downloadable",
         %{conn: conn} do
      paths = [
        "/downloads/agent-toolkit/alchemistdrops-agent-toolkit-v#{@version}.zip",
        "/downloads/agent-toolkit/ecto-development-v#{@version}.zip",
        "/downloads/agent-toolkit/elixir-development-v#{@version}.zip",
        "/downloads/agent-toolkit/phoenix-authentication-v#{@version}.zip",
        "/downloads/agent-toolkit/phoenix-development-v#{@version}.zip",
        "/downloads/agent-toolkit/phoenix-js-hooks-v#{@version}.zip",
        "/downloads/agent-toolkit/phoenix-liveview-testing-v#{@version}.zip",
        "/downloads/agent-toolkit/phoenix-liveview-v#{@version}.zip",
        "/downloads/agent-toolkit/elixir-safety-rules-v#{@version}.zip"
      ]

      for path <- paths do
        response = get(recycle(conn), path)

        assert response.status == 200
        assert ["application/zip"] = get_resp_header(response, "content-type")
        assert <<"PK", _archive::binary>> = response.resp_body
      end
    end

    test "given the published archives, when their entries are inspected, then they match the reviewed sources" do
      readme = File.read!("docs/agent-toolkit/README.md")
      license = File.read!("docs/agent-toolkit/LICENSE.txt")

      refute readme =~ ~r/elixir-safety-rules-v\d+\.\d+\.\d+\.zip/

      for skill <- @skills do
        archive = download_archive("#{skill}-v#{@version}.zip")

        assert archive_files(archive) == %{
                 "#{skill}/LICENSE.txt" => license,
                 "#{skill}/SKILL.md" => File.read!(".agents/skills/#{skill}/SKILL.md")
               }
      end

      assert archive_files(download_archive("elixir-safety-rules-v#{@version}.zip")) == %{
               ".codex/rules/elixir-safety.rules" =>
                 File.read!(".codex/rules/elixir-safety.rules"),
               "LICENSE.txt" => license
             }

      toolkit_prefix = "alchemistdrops-agent-toolkit/"

      expected_toolkit_files =
        @skills
        |> Map.new(fn skill ->
          {"#{toolkit_prefix}.agents/skills/#{skill}/SKILL.md",
           File.read!(".agents/skills/#{skill}/SKILL.md")}
        end)
        |> Map.merge(%{
          "#{toolkit_prefix}.codex/rules/elixir-safety.rules" =>
            File.read!(".codex/rules/elixir-safety.rules"),
          "#{toolkit_prefix}AGENTS.md" => File.read!("AGENTS.md"),
          "#{toolkit_prefix}LICENSE.txt" => license,
          "#{toolkit_prefix}README.md" => readme,
          "#{toolkit_prefix}VERSION" => "#{@version}\n"
        })

      assert archive_files(download_archive("alchemistdrops-agent-toolkit-v#{@version}.zip")) ==
               expected_toolkit_files
    end

    test "given an atomic release target, when Phoenix serves downloads, then the directory is publicly traversable" do
      public_path = "priv/static/downloads/agent-toolkit"
      release_target = File.read_link!(public_path)
      release_path = Path.expand(release_target, Path.dirname(public_path))

      assert Bitwise.band(File.stat!(release_path).mode, 0o777) == 0o755
    end
  end

  defp archive_files(path) do
    assert {:ok, extracted_files} = :zip.extract(String.to_charlist(path), [:memory])

    Map.new(extracted_files, fn {name, contents} ->
      {List.to_string(name), contents}
    end)
  end

  defp download_archive(filename) do
    Path.join("priv/static/downloads/agent-toolkit", filename)
  end
end
