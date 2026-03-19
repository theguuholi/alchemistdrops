defmodule AlchemistdropsWeb.AboutLive.Index do
  @moduledoc """
  Professional About / Profile page: enterprise meets edgy.
  """
  use AlchemistdropsWeb, :live_view

  @linkedin_url "https://www.linkedin.com/in/devgustavooliveira"
  @email "g.92oliveira@gmail.com"

  attr :profile, :map, required: true
  attr :linkedin_url, :string, required: true
  attr :email, :string, required: true

  def hero_section(assigns) do
    ~H"""
    <header class="relative overflow-hidden border-b border-base-300">
      <%!-- Background gradients --%>
      <div
        class="absolute inset-0 bg-gradient-to-br from-primary/5 via-transparent to-secondary/5"
        aria-hidden="true"
      />
      <div
        class="absolute top-0 right-0 w-1/2 h-full bg-[radial-gradient(ellipse_80%_80%_at_100%_0%,oklch(var(--p)/0.08),transparent)]"
        aria-hidden="true"
      />

      <div class="relative max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="flex flex-col md:flex-row md:items-center md:gap-12">
          <%!-- Profile image with gradient glow --%>
          <div class="flex-shrink-0 mb-8 md:mb-0">
            <div class="relative inline-block group">
              <div
                class="absolute -inset-0.5 bg-gradient-to-r from-primary to-secondary rounded-2xl blur opacity-40 group-hover:opacity-60 transition-opacity"
                aria-hidden="true"
              />
              <img
                src={~p"/images/gustavo.webp"}
                alt={@profile.name}
                class="relative w-40 h-40 sm:w-48 sm:h-48 rounded-2xl object-cover ring-1 ring-base-300 shadow-xl"
                width="192"
                height="192"
                loading="eager"
              />
            </div>
          </div>

          <%!-- Name, title, location & CTAs --%>
          <div class="flex-1">
            <p class="text-xs font-semibold uppercase tracking-widest text-primary mb-2">
              Software Engineer
            </p>
            <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight text-base-content mb-3">
              {@profile.name}
            </h1>
            <p class="text-lg sm:text-xl text-base-content/80 font-light max-w-xl mb-6">
              {@profile.title}
            </p>
            <p class="flex items-center gap-2 text-base-content/70 text-sm">
              <.icon name="hero-map-pin" class="w-4 h-4 flex-shrink-0 text-primary/80" />
              {@profile.location}
            </p>
            <div class="flex flex-wrap gap-3 mt-8">
              <a
                href={@linkedin_url}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-[#0A66C2] text-white font-medium text-sm hover:opacity-90 transition-opacity shadow-lg"
                aria-label="LinkedIn profile"
              >
                <.icon name="hero-arrow-top-right-on-square" class="w-5 h-5" /> LinkedIn
              </a>
              <a
                href={"mailto:#{@email}"}
                class="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-base-200 border border-base-300 text-base-content font-medium text-sm hover:bg-base-300 transition-colors"
                aria-label="Email"
              >
                <.icon name="hero-envelope" class="w-5 h-5" /> Contact
              </a>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Gustavo Oliveira — Software Engineer")
     |> assign(:meta_description, meta_description())
     |> assign(:profile, profile())
     |> assign(:career, career())
     |> assign(:linkedin_url, @linkedin_url)
     |> assign(:email, @email)
     |> assign(:chat_messages, [])
     |> assign(:chat_loading, false)
     |> assign(:digital_twin_available, digital_twin_available?())}
  end

  @impl true
  def handle_event("send_message", %{"message" => text}, socket) do
    text = String.trim(text)

    if text == "" do
      {:noreply, socket}
    else
      user_msg = %{role: "user", content: text}
      messages_after_user = socket.assigns.chat_messages ++ [user_msg]

      socket =
        socket
        |> assign(:chat_messages, messages_after_user)
        |> assign(:chat_loading, true)

      send(self(), :run_digital_twin)
      {:noreply, socket}
    end
  end

  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:run_digital_twin, socket) do
    messages = socket.assigns.chat_messages
    profile = socket.assigns.profile
    career = socket.assigns.career
    extra_context = read_prompt_markdown()

    result =
      Alchemistdrops.DigitalTwin.chat(profile, career, messages, extra_context: extra_context)

    socket =
      case result do
        {:ok, content} ->
          assistant_msg = %{role: "assistant", content: content}
          assign(socket, :chat_messages, messages ++ [assistant_msg])

        {:error, reason} ->
          error_content = "Sorry, I couldn't get a response. (#{inspect(reason)})"

          assign(
            socket,
            :chat_messages,
            messages ++ [%{role: "assistant", content: error_content}]
          )
      end

    {:noreply, assign(socket, :chat_loading, false)}
  end

  defp digital_twin_available? do
    key = Application.get_env(:alchemistdrops, :openrouter_api_key)
    is_binary(key) and key != ""
  end

  # Reads docs/prompts/gustavo-career-and-impact.md when present (for richer Digital Twin context).
  defp read_prompt_markdown do
    base =
      Application.get_env(:alchemistdrops, :prompt_markdown_path) ||
        "docs/prompts/gustavo-career-and-impact.md"

    path = Path.expand(base, File.cwd!())

    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> content
        _ -> nil
      end
    else
      nil
    end
  end

  defp meta_description do
    "Gustavo Oliveira — Senior Software Engineer. Elixir, Phoenix, LiveView, Java. " <>
      "Passionate about Agile, evolutive engineering, and building scalable systems."
  end

  defp profile do
    %{
      name: "Gustavo Oliveira",
      title: "Software Engineer",
      location: "São Paulo, Brazil",
      tagline:
        "Passionate developer who believes that Agile Methodologies, Product Design and Evolutive Engineering can leverage any business to a higher level of competitivity.",
      bio: [
        "Driven by communication, data, and results. Proactive, responsible engineer focused on outcomes—scale, time and cost savings, and better product and team performance.",
        "Active in open source communities (GUJ, Viva o Linux, GitHub, StackOverflow). Successfully led teams with Scrum, fast delivery, and high-quality commitment."
      ],
      education: "Bachelor's Degree, Internet Systems · Fatec Carapicuiba (2012–2014)",
      honors: "Week Technology — AngularJs"
    }
  end

  defp career do
    [
      %{
        company: "Stord",
        role: "Senior Software Engineer",
        period: "May 2025 — Present",
        location: "United States",
        impact: [
          "Scaled the platform to handle 500,000+ orders per day",
          "Co-created freight-order flows and shipping features, including A/B testing to optimize conversion and cost",
          "Built international orders with tax ID support and integration with Logiwa and other complex systems",
          "Architected scalable payment processing and high-volume email; trained the team for faster, higher-quality delivery"
        ]
      },
      %{
        company: "Lolo",
        role: "Senior Software Engineer",
        period: "Aug 2023 — May 2025",
        location: "United States",
        impact: [
          "Designed the software architecture that enabled faster releases, easier onboarding, and fewer bugs—helping the company scale faster",
          "Built high-throughput email (thousands per hour) and the billing application that processes payments reliably at scale",
          "Mentored the team for better quality and delivery"
        ]
      },
      %{
        company: "Clarus R+D",
        role: "Senior Software Engineer",
        period: "May 2021 — May 2023",
        location: "Columbus, Ohio",
        impact: [
          "Processed thousands of W2 forms so customers could save time and money preparing tax documents",
          "Contributed to architecture and product quality, helping the company build a strong, maintainable foundation"
        ]
      },
      %{
        company: "Zubale",
        role: "Senior Software Engineer",
        period: "Jul 2020 — Jul 2021",
        location: "United States",
        impact: [
          "Cost savings and faster operations: ops team moved from weeks or days of work to a few hours per day",
          "Optimized API to handle ~1M records in under 10 minutes so Zubaleros could see pickings and fulfill orders much faster",
          "Mentored developers for better quality and velocity"
        ]
      },
      %{
        company: "HDI Seguros",
        role: "Lead Software Engineer",
        period: "Jul 2019 — Jul 2020",
        location: "São Paulo, Brazil",
        impact: [
          "Made it easier for customers to integrate with HDI, improving adoption and time-to-value",
          "Open Insurance API and digital modernization helped attract and onboard more customers"
        ]
      },
      %{
        company: "TOTVS",
        role: "Senior Software Development Engineer",
        period: "Oct 2018 — Jun 2019",
        location: "São Paulo, Brazil",
        impact: [
          "Led migration from monolith to microservices, increasing deploy frequency and enabling faster innovation",
          "Simplified the system so it was easier to understand, maintain, and extend—improving team velocity and reliability"
        ]
      },
      %{
        company: "Concrete Solutions",
        role: "Senior Software Engineer",
        period: "Jan 2016 — Oct 2018",
        location: "São Paulo, Brazil",
        impact: [
          "Lean, UX, and Agile delivery; BDD and quality practices for mobile and APIs",
          "REST APIs and alignment with product for faster, predictable releases"
        ]
      },
      %{
        company: "CWI Software",
        role: "Software Engineer",
        period: "Jan 2015 — Dec 2015",
        location: "São Paulo, Brazil",
        impact: [
          "Scrum delivery; full-stack work enabling faster iteration and collaboration"
        ]
      },
      %{
        company: "Ericsson Inovação",
        role: "Software Engineer Intern",
        period: "Jan 2013 — Dec 2014",
        location: "São Paulo, Brazil",
        impact: [
          "CI pipelines for automation and quality; inventory management for operations"
        ]
      }
    ]
  end
end
