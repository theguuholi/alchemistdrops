defmodule AlchemistdropsWeb.HomeLive.Index do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Article

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Master Elixir - Alchemistdrops")
      |> assign(:learn_items, learn_items())
      |> assign(:faq_items, faq_items())
      |> assign(:recent_posts, Posts.list_recent_published_posts(3))

    {:ok, socket}
  end

  defp learn_items do
    [
      %{
        title: "Building and Deploying LiveView Apps",
        description:
          "Learn how to create and launch interactive web applications with real-time features."
      },
      %{
        title: "Crafting Scalable Applications with Phoenix",
        description:
          "Discover how to design applications that grow effortlessly as your user base expands."
      },
      %{
        title: "Real-World Project Creation, Debugging, and Optimization",
        description:
          "Build and refine projects that mirror challenges in professional environments."
      },
      %{
        title: "Functional Programming Techniques",
        description:
          "Grasp the core principles of functional programming to write clean, maintainable code."
      },
      %{
        title: "Integrating Elixir with Modern Tools and APIs",
        description: "Connect your Elixir applications to external services and APIs seamlessly."
      }
    ]
  end

  defp faq_items do
    [
      %{
        title: "What exactly is Alchemistdrops?",
        description:
          "Alchemistdrops is an online, practical, and highly intensive training to help you become an expert Elixir developer. You'll dive deep into Elixir, Phoenix Framework, LiveView, Unit Tests, CI/CD practices, and the entire ecosystem—from scratch to cloud deployment and best practices."
      },
      %{
        title: "Are the classes hands-on?",
        description:
          "Absolutely! The goal of this training is to give you hands-on experience with real-world scenarios. You'll learn best practices and frameworks while focusing on practical application."
      },
      %{
        title: "How long will I have access to the course?",
        description:
          "You will have access to the training for one year, allowing you to watch and re-watch the material as many times as you need."
      },
      %{
        title: "How does the support work?",
        description:
          "Once you enroll, you gain access to a Discord community where questions are answered personally. Additional Zoom calls may be scheduled for specific questions or issues."
      },
      %{
        title: "I'm a beginner in Elixir. Will this course help me?",
        description:
          "Absolutely! Our course is designed for both beginners and experienced developers. We start from the basics, building a strong foundation that allows you to confidently create applications and tackle complex challenges."
      },
      %{
        title: "I'm already advanced in Elixir. Will this course help me?",
        description:
          "Certainly! We cover advanced topics like LIBCLUSTER, Kubernetes, real-time distributed nodes, deployment, security, and much more that even experienced developers will find valuable."
      },
      %{
        title: "What if I don't like the course?",
        description:
          "We offer a 30-day money-back guarantee. If you're not satisfied for any reason, simply contact us within this period for a full refund."
      }
    ]
  end

  defp reading_minutes(post), do: Article.build(post).reading_minutes

  defp format_post_date(datetime), do: Calendar.strftime(datetime, "%b %-d, %Y")

  attr :image, :string, required: true
  attr :image_alt, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :reversed, :boolean, default: false

  defp feature_course(assigns) do
    ~H"""
    <div class={[
      (@reversed && "md:flex-row-reverse") || "md:flex-row",
      "flex flex-col items-center gap-8 mt-12"
    ]}>
      <div class="flex-1">
        <img
          loading="lazy"
          src={@image}
          alt={@image_alt}
          class="w-full max-w-md mx-auto rounded-lg shadow-lg"
        />
      </div>
      <div class="flex-1 md:text-left text-center">
        <h3 class="text-2xl font-semibold mb-3">
          {@title}
        </h3>
        <p class="text-base leading-relaxed text-base-content/80">
          {@description}
        </p>
      </div>
    </div>
    """
  end
end
