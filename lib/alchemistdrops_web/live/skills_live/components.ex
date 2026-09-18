defmodule AlchemistdropsWeb.SkillsLive.Components do
  @moduledoc """
  Provides the semantic, page-local sections used by the skills catalog.

  These components keep the catalog template readable without promoting
  content that belongs only to `/skills` into the application's shared
  component API.
  """
  use AlchemistdropsWeb, :html

  @doc """
  Renders the toolkit introduction and complete download action.

  ## Examples

      iex> html = Phoenix.LiveViewTest.render_component(&AlchemistdropsWeb.SkillsLive.Components.toolkit_header/1, version: "1.0.0")
      iex> html =~ ~s(id="download-complete-toolkit")
      true

  """
  attr :version, :string, required: true

  @spec toolkit_header(map()) :: Phoenix.LiveView.Rendered.t()
  def toolkit_header(assigns) do
    ~H"""
    <header class="relative overflow-hidden border-b border-base-300 bg-base-200/60">
      <div
        class="absolute inset-y-0 right-0 w-2/3 bg-[radial-gradient(circle_at_80%_20%,oklch(var(--p)/0.14),transparent_55%)]"
        aria-hidden="true"
      >
      </div>

      <div class="relative mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8">
        <div class="max-w-3xl">
          <p class="mb-5 font-mono text-sm text-primary">.agents/skills · v{@version}</p>
          <h1 class="text-4xl font-bold tracking-tight text-base-content sm:text-6xl">
            Elixir agent toolkit
          </h1>
          <p class="mt-6 max-w-2xl text-lg leading-8 text-base-content/75 sm:text-xl">
            Practical instructions for agents working with Elixir, Phoenix, LiveView, and Ecto.
            Download the complete toolkit or choose only the skill your project needs.
          </p>

          <div class="mt-9 flex flex-col gap-3 sm:flex-row sm:items-center">
            <a
              id="download-complete-toolkit"
              href={"/downloads/agent-toolkit/alchemistdrops-agent-toolkit-v#{@version}.zip"}
              download
              class="btn btn-primary min-h-12 justify-center gap-2 sm:px-6"
            >
              <.icon name="hero-arrow-down-tray" class="size-5" /> Download complete toolkit
            </a>
            <span class="text-sm text-base-content/60">
              7 skills · AGENTS.md · optional safety rules
            </span>
          </div>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Renders the available skills and their individual download actions.

  ## Examples

      iex> skill = %{id: "ecto", name: "Ecto", scope: "Schemas", advantage: "Explicit data", description: "Schema guidance.", benefits: ["Clear contracts"], download_path: "/ecto.zip"}
      iex> html = Phoenix.LiveViewTest.render_component(&AlchemistdropsWeb.SkillsLive.Components.skill_catalog/1, skills: [skill])
      iex> html =~ ~s(id="skill-ecto")
      true

  """
  attr :skills, :list, required: true

  @spec skill_catalog(map()) :: Phoenix.LiveView.Rendered.t()
  def skill_catalog(assigns) do
    ~H"""
    <section
      id="skill-catalog"
      class="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20 lg:px-8"
      aria-labelledby="skill-catalog-heading"
    >
      <header class="grid gap-8 border-b border-base-300 pb-10 lg:grid-cols-[minmax(0,0.7fr)_minmax(0,1.3fr)] lg:gap-16">
        <h2 id="skill-catalog-heading" class="text-3xl font-bold tracking-tight sm:text-4xl">
          Choose the right guidance
        </h2>
        <p class="max-w-2xl text-base leading-7 text-base-content/70 sm:text-lg">
          Each skill has one responsibility. Combine them when a change crosses boundaries—for
          example, a LiveView form backed by an Ecto schema needs interface, testing, and data
          guidance together.
        </p>
      </header>

      <div class="divide-y divide-base-300">
        <article
          :for={skill <- @skills}
          id={"skill-#{skill.id}"}
          class="grid gap-8 py-10 lg:grid-cols-[minmax(0,0.7fr)_minmax(0,1.3fr)] lg:gap-16 lg:py-14"
        >
          <header>
            <p class="font-mono text-xs text-primary">{skill.scope}</p>
            <h3 class="mt-3 text-2xl font-bold tracking-tight text-base-content">{skill.name}</h3>
            <p class="mt-3 text-lg font-medium leading-7 text-base-content/90">
              {skill.advantage}
            </p>
          </header>

          <div>
            <p class="max-w-2xl leading-7 text-base-content/70">{skill.description}</p>
            <ul class="mt-6 space-y-3" aria-label={"Advantages of #{skill.name}"}>
              <li
                :for={benefit <- skill.benefits}
                class="flex gap-3 text-sm leading-6 sm:text-base"
              >
                <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-primary" />
                <span>{benefit}</span>
              </li>
            </ul>
            <a
              id={"download-#{skill.id}"}
              href={skill.download_path}
              download
              class="btn btn-outline btn-sm mt-7 gap-2"
            >
              <.icon name="hero-arrow-down-tray" class="size-4" /> Download skill
            </a>
          </div>
        </article>
      </div>
    </section>
    """
  end

  @doc """
  Renders the optional shell safety rules package.

  ## Examples

      iex> html = Phoenix.LiveViewTest.render_component(&AlchemistdropsWeb.SkillsLive.Components.safety_rules/1, version: "1.0.0")
      iex> html =~ ~s(id="download-safety-rules")
      true

  """
  attr :version, :string, required: true

  @spec safety_rules(map()) :: Phoenix.LiveView.Rendered.t()
  def safety_rules(assigns) do
    ~H"""
    <section
      id="safety-rules"
      class="border-y border-base-300 bg-base-200/60"
      aria-labelledby="safety-rules-heading"
    >
      <div class="mx-auto grid max-w-6xl gap-8 px-4 py-14 sm:px-6 lg:grid-cols-[minmax(0,0.7fr)_minmax(0,1.3fr)] lg:gap-16 lg:px-8 lg:py-16">
        <header>
          <p class="font-mono text-sm text-warning">.codex/rules</p>
          <h2 id="safety-rules-heading" class="mt-3 text-3xl font-bold tracking-tight">
            Rules protect dangerous commands
          </h2>
        </header>
        <div>
          <p class="max-w-2xl leading-7 text-base-content/75">
            Skills guide how code should be written. Rules control which shell commands require
            confirmation. The safety package is optional and asks before destructive Ecto tasks,
            broad dependency cleanup, and shell-wrapped commands.
          </p>
          <p class="mt-4 max-w-2xl text-sm leading-6 text-base-content/60">
            Review rules before installing them because command permissions should match your own
            environment and workflow.
          </p>
          <pre class="mt-5 overflow-x-auto rounded-xl border border-base-300 bg-neutral p-4 text-sm text-neutral-content"><code>unzip elixir-safety-rules-v{@version}.zip -d .</code></pre>
          <a
            id="download-safety-rules"
            href={"/downloads/agent-toolkit/elixir-safety-rules-v#{@version}.zip"}
            download
            class="btn btn-outline btn-sm mt-7 gap-2"
          >
            <.icon name="hero-shield-check" class="size-4" /> Download safety rules
          </a>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  Renders the ordered project installation instructions.

  ## Examples

      iex> html = Phoenix.LiveViewTest.render_component(&AlchemistdropsWeb.SkillsLive.Components.installation_guide/1)
      iex> html =~ ~s(id="installation-guide")
      true

  """
  @spec installation_guide(map()) :: Phoenix.LiveView.Rendered.t()
  def installation_guide(assigns) do
    ~H"""
    <section
      id="installation-guide"
      class="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20 lg:px-8"
      aria-labelledby="installation-heading"
    >
      <div class="grid gap-10 lg:grid-cols-[minmax(0,0.7fr)_minmax(0,1.3fr)] lg:gap-16">
        <header>
          <h2 id="installation-heading" class="text-3xl font-bold tracking-tight">
            Install in a project
          </h2>
          <p class="mt-4 leading-7 text-base-content/70">
            Extract the archive, inspect the instructions, and copy the folders you want into the
            root of your repository.
          </p>
        </header>

        <ol class="space-y-8">
          <li class="grid grid-cols-[2rem_1fr] gap-4">
            <span class="flex size-8 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-content">
              1
            </span>
            <div>
              <h3 class="font-semibold">Choose a package</h3>
              <p class="mt-1 text-sm leading-6 text-base-content/65">
                Use an individual skill for a focused addition, or the complete toolkit when you
                want the routing file and every workflow.
              </p>
            </div>
          </li>
          <li class="grid grid-cols-[2rem_1fr] gap-4">
            <span class="flex size-8 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-content">
              2
            </span>
            <div>
              <h3 class="font-semibold">Copy the skill folder</h3>
              <pre class="mt-3 overflow-x-auto rounded-xl border border-base-300 bg-neutral p-4 text-sm text-neutral-content"><code>{"mkdir -p .agents/skills\ncp -R ecto-development .agents/skills/"}</code></pre>
            </div>
          </li>
          <li class="grid grid-cols-[2rem_1fr] gap-4">
            <span class="flex size-8 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-content">
              3
            </span>
            <div>
              <h3 class="font-semibold">Merge the project instructions</h3>
              <p class="mt-1 text-sm leading-6 text-base-content/65">
                Review the downloaded AGENTS.md instead of overwriting your existing file. Keep
                only the skill routes and project facts that apply to your application.
              </p>
            </div>
          </li>
        </ol>
      </div>
    </section>
    """
  end
end
