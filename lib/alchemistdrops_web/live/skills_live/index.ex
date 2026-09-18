defmodule AlchemistdropsWeb.SkillsLive.Index do
  @moduledoc """
  Presents the reusable AlchemistDrops skills and safety rules.

  The catalog explains which engineering problem each skill addresses and
  exposes versioned downloads that can be inspected before they are copied
  into an Elixir project.

  ## Example

      iex> socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      iex> {:ok, mounted_socket} = AlchemistdropsWeb.SkillsLive.Index.mount(%{}, %{}, socket)
      iex> is_binary(mounted_socket.assigns.version)
      true

  """
  use AlchemistdropsWeb, :live_view

  import AlchemistdropsWeb.SkillsLive.Components

  @version_file Path.expand("../../../../docs/agent-toolkit/VERSION", __DIR__)
  @external_resource @version_file
  @version @version_file |> File.read!() |> String.trim()

  @typedoc "A downloadable skill and the practical advantage it brings to an Elixir project."
  @type skill :: %{
          id: String.t(),
          name: String.t(),
          scope: String.t(),
          advantage: String.t(),
          description: String.t(),
          benefits: [String.t()],
          download_path: String.t()
        }

  @doc """
  Loads the public toolkit catalog and its current release version.

  Phoenix invokes this callback when a visitor opens `/skills`.
  """
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Elixir agent toolkit")
     |> assign(
       :meta_description,
       "Download reusable AlchemistDrops skills and safety rules for Elixir, Phoenix, LiveView, and Ecto projects."
     )
     |> assign(:version, @version)
     |> assign(:skills, skills())}
  end

  @spec skills() :: [skill()]
  defp skills do
    [
      %{
        id: "ecto-development",
        name: "Ecto Development",
        scope: "Schemas · changesets · queries",
        advantage: "Keeps schemas and data changes explicit",
        description:
          "Guides schema documentation, meaningful field types, changeset contracts, migrations, associations, and data-integrity tests.",
        benefits: [
          "Documents why each schema exists and what every field represents.",
          "Covers valid, invalid, boundary, constraint, and association scenarios.",
          "Makes changeset assertions direct and readable."
        ],
        download_path: download_path("ecto-development")
      },
      %{
        id: "elixir-development",
        name: "Elixir Development",
        scope: "Modules · types · OTP",
        advantage: "Makes Elixir modules easier to understand",
        description:
          "Establishes clear module boundaries, ExDoc documentation, doctests, typespecs, and safe OTP and concurrency practices.",
        benefits: [
          "Turns public APIs into executable documentation.",
          "Uses types to reveal domain meaning and possible outcomes.",
          "Keeps processes supervised and concurrent work deliberate."
        ],
        download_path: download_path("elixir-development")
      },
      %{
        id: "phoenix-authentication",
        name: "Phoenix Authentication",
        scope: "Sessions · scopes · authorization",
        advantage: "Protects authentication boundaries",
        description:
          "Keeps routes, live sessions, current scopes, and authorization checks aligned with Phoenix authentication conventions.",
        benefits: [
          "Prevents protected pages from drifting into public sessions.",
          "Keeps identity derived from the established current scope.",
          "Tests anonymous, authenticated, and unauthorized paths."
        ],
        download_path: download_path("phoenix-authentication")
      },
      %{
        id: "phoenix-development",
        name: "Phoenix Development",
        scope: "Routes · components · HEEx",
        advantage: "Keeps Phoenix interfaces consistent",
        description:
          "Applies Phoenix 1.8 conventions to routes, function components, semantic HEEx, layouts, forms, assets, and responsive states.",
        benefits: [
          "Reuses components instead of rebuilding interface primitives.",
          "Adds stable DOM contracts for accessibility and tests.",
          "Preserves modern Phoenix and Tailwind conventions."
        ],
        download_path: download_path("phoenix-development")
      },
      %{
        id: "phoenix-js-hooks",
        name: "Phoenix JavaScript Hooks",
        scope: "Hooks · browser events · Vitest",
        advantage: "Connects LiveView and JavaScript safely",
        description:
          "Organizes shared hooks through assets/js/hooks.js and defines ownership, lifecycle, cleanup, browser events, and JavaScript tests.",
        benefits: [
          "Keeps hook registration in one predictable architecture.",
          "Prevents duplicated listeners and client-owned DOM conflicts.",
          "Covers lifecycle and edge cases with the LiveView hook test API."
        ],
        download_path: download_path("phoenix-js-hooks")
      },
      %{
        id: "phoenix-liveview-testing",
        name: "Phoenix LiveView Testing",
        scope: "Gherkin · selectors · outcomes",
        advantage: "Tests behavior through stable DOM contracts",
        description:
          "Structures callback scenarios in Given–When–Then form and verifies the responsible element instead of searching raw HTML.",
        benefits: [
          "Makes failures point to the exact broken interaction.",
          "Covers mount, params, events, messages, navigation, and forms.",
          "Separates rendered behavior from persistence and domain rules."
        ],
        download_path: download_path("phoenix-liveview-testing")
      },
      %{
        id: "phoenix-liveview",
        name: "Phoenix LiveView",
        scope: "State · callbacks · navigation",
        advantage: "Keeps LiveViews focused on interface orchestration",
        description:
          "Keeps business rules in contexts while LiveView callbacks load data, call domain functions, and render the resulting state.",
        benefits: [
          "Prevents pages from becoming a second domain layer.",
          "Uses URL parameters as the source of truth for search and filters.",
          "Promotes semantic, mobile-first templates and deliberate streams."
        ],
        download_path: download_path("phoenix-liveview")
      }
    ]
  end

  @spec download_path(String.t()) :: String.t()
  defp download_path(id), do: "/downloads/agent-toolkit/#{id}-v#{@version}.zip"
end
