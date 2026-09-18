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
     |> assign(:chat_loading?, false)
     |> assign(:digital_twin_available?, digital_twin_available?())}
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
        |> assign(:chat_loading?, true)

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

    {:noreply, assign(socket, :chat_loading?, false)}
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
    "Gustavo Oliveira — Senior Elixir Engineer. Phoenix, LiveView, OTP, Distributed Systems, AI-assisted development. " <>
      "11+ years building fault-tolerant, high-throughput systems across logistics, fintech, and SaaS."
  end

  defp profile do
    %{
      name: "Gustavo Oliveira",
      title:
        "Senior Elixir Engineer | Phoenix · OTP · Distributed Systems · AI-Assisted Development",
      location: "São Paulo, Brazil (Remote — Americas / Europe)",
      tagline:
        "Senior Elixir Engineer with 11+ years of experience building fault-tolerant, high-throughput distributed systems across logistics, fintech, and SaaS. Deep expertise in Elixir/OTP, Phoenix, LiveView, and real-time asynchronous architectures. Proven track record shipping systems that process millions of records and hundreds of thousands of transactions under real production load.",
      bio: [
        "Passionate about AI-assisted engineering: published author on LLM-powered development workflows, and hands-on practitioner integrating AI tooling (Claude, Cursor, MCP servers) into team development cycles to multiply engineering output.",
        "Selected impact: reduced data ingestion from ~5 hours to under 10 minutes processing ~1M records per run · built Stripe payment system handling 200,000+ transactions/month · architected distributed systems powering ~100,000 deliveries/day across Brazil, Mexico, and Colombia · implemented Tax ID compliance across 10+ international markets enabling global merchant onboarding."
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
        period: "Apr 2025 — Present",
        location: "United States",
        highlights: [
          "Built an AI-powered on-call assistant integrating the live codebase with MCP servers for Freshdesk, Atlassian, Datadog, and Kafka — enabling engineers to resolve incidents in seconds without context switching",
          "Coached the team on Claude plan mode, structured prompting, and AI plugin workflows — accelerating feature design cycles",
          "Engineered combine/separate shipment logic handling ~100,000 daily orders, preventing incorrect fulfilled statuses at scale",
          "Implemented Tax ID support across 10+ markets (CPF, CNPJ, EORI, VAT, RUT, RFC, CUIT) — enabling international merchant onboarding",
          "Built shipping A/B testing framework comparing price vs. delivery speed to drive data-driven decisions at scale",
          "Reduced support tickets ~80/incident cycle via real-time freight pallet visualization feature"
        ],
        technologies: [
          "Elixir",
          "Phoenix",
          "Go",
          "React",
          "Oban",
          "PostgreSQL",
          "Kafka",
          "AWS",
          "GCP",
          "Datadog",
          "Claude Code",
          "Cursor",
          "MCP"
        ]
      },
      %{
        company: "Lolo",
        role: "Senior / Lead Software Engineer",
        period: "Aug 2023 — May 2025",
        location: "United States",
        highlights: [
          "Architected the full backend from scratch with Elixir, Phoenix, and LiveView — supporting ~800 senders and 50+ partners",
          "Built Stripe payment system handling 200,000+ transactions/month with subscription billing, automated retries, and failure recovery",
          "Designed Oban-based pipelines delivering 400,000+ emails and SMS per week, fully decoupled and resilient to third-party downtime",
          "Led team of 5 in adopting TDD, clean architecture, and LiveView patterns — reducing onboarding from 1 week to 1 hour",
          "Introduced GitHub Copilot and AI content generation across the engineering team to accelerate delivery velocity"
        ],
        technologies: [
          "Elixir",
          "Phoenix",
          "LiveView",
          "Oban",
          "Stripe",
          "SendGrid",
          "PostgreSQL",
          "GitHub Copilot"
        ]
      },
      %{
        company: "Clarus R+D",
        role: "Senior Software Engineer",
        period: "May 2021 — May 2023",
        location: "Columbus, Ohio",
        highlights: [
          "Built real-time W2 PDF ingestion pipeline (S3 + parsing API + PostgreSQL) — cutting per-client processing from days to seconds, handling ~1,000 W2s per client per cycle",
          "Contributed to a platform enabling clients to claim over $100M in R&D tax credits annually",
          "Eliminated manual deployments with CI/CD pipeline via GitHub Actions and AWS EKS"
        ],
        technologies: [
          "Elixir",
          "React",
          "LiveView",
          "GitHub Actions",
          "AWS EKS",
          "S3",
          "PostgreSQL"
        ]
      },
      %{
        company: "Zubale",
        role: "Senior Software Engineer",
        period: "Jul 2020 — Jul 2021",
        location: "United States",
        highlights: [
          "Optimized Elixir data ingestion API to process ~1M records in under 10 minutes — down from ~5 hours — eliminating daily bottlenecks and weekend overtime",
          "Architected distributed systems with Kafka and GraphQL powering ~100,000 deliveries/day across Brazil, Mexico, and Colombia",
          "Built geolocation-enabled mobile backend for contractor order fulfillment across 3 countries"
        ],
        technologies: [
          "Elixir",
          "GraphQL",
          "Kafka",
          "React",
          "React Native",
          "MongoDB",
          "PostgreSQL",
          "Kubernetes"
        ]
      },
      %{
        company: "HDI Seguros",
        role: "Lead Software Engineer",
        period: "Jul 2019 — Jul 2020",
        location: "São Paulo, Brazil",
        highlights: [
          "Developed production-grade RESTful APIs (Richardson Level 2) as part of company-wide Digital Modernization Strategy",
          "Engineered the Open Insurance API in compliance with SUSEP's framework — among the first insurers in Brazil to meet requirements",
          "Replaced legacy Progress Database with PostgreSQL and MongoDB; containerized services with Docker and Kubernetes"
        ],
        technologies: [
          "Java 8",
          "Spring Boot",
          "Go",
          "PostgreSQL",
          "MongoDB",
          "Docker",
          "Kubernetes"
        ]
      },
      %{
        company: "TOTVS",
        role: "Senior Software Development Engineer",
        period: "Oct 2018 — Jun 2019",
        location: "São Paulo, Brazil",
        highlights: [
          "Led migration from monolithic architecture to microservices, increasing deploy frequency and enabling faster innovation"
        ],
        technologies: ["Java", "Spring Boot", "Microservices", "Docker"]
      },
      %{
        company: "Concrete Solutions",
        role: "Senior Software Engineer",
        period: "Jan 2016 — Oct 2018",
        location: "São Paulo, Brazil",
        highlights: [
          "Built REST APIs and business tools for enterprise clients using Java 8 and Spring Boot",
          "Delivered BDD/Cucumber automated test suites for mobile applications",
          "Worked across multiple client projects delivering microservices architectures with Spring Cloud"
        ],
        technologies: [
          "Java 8",
          "Spring Boot",
          "Spring Cloud",
          "React",
          "Angular",
          "Oracle",
          "Hibernate",
          "BDD/Cucumber",
          "AWS"
        ]
      },
      %{
        company: "CWI Software",
        role: "Software Engineer",
        period: "Jan 2015 — Dec 2015",
        location: "São Paulo, Brazil",
        highlights: [
          "Integrated enterprise systems via JMS and REST web services; full-stack development with Spring, Hibernate, Angular"
        ],
        technologies: ["Java", "Spring", "Hibernate", "JMS", "Angular"]
      },
      %{
        company: "Ericsson Inovação",
        role: "Software Engineer Intern",
        period: "Jan 2013 — Dec 2014",
        location: "São Paulo, Brazil",
        highlights: [
          "Built CI pipelines with Jenkins; developed inventory management system with Java and JSF"
        ],
        technologies: ["Java", "JSF", "Jenkins", "HTML"]
      }
    ]
  end
end
