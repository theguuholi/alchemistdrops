# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Alchemistdrops.Repo.insert!(%Alchemistdrops.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Create a sample user
_user =
  %Alchemistdrops.Accounts.User{
    email: "demo@alchemistdrops.com",
    hashed_password: Bcrypt.hash_pwd_salt("password123"),
    confirmed_at: DateTime.truncate(DateTime.utc_now(), :second),
    role: :admin
  }
  |> Alchemistdrops.Repo.insert!()

# Create a simple blog post: "How to Use IEx and Elixir"
post =
  %Alchemistdrops.Posts.Post{
    title: "How to Use IEx and Elixir",
    body: """
    The Interactive Elixir (IEx) shell is a powerful tool to explore and experiment with Elixir in real-time.

    ## Opening IEx

    To start IEx, run in your terminal:
        iex

    ## Basics

    - Type arithmetic expressions, variable assignments, and function calls.
    - Use `h` for help, e.g. `h Enum.map`.
    - Reload code with `recompile()` if you're working on a project.

    Try it out:

        iex> IO.puts("Hello, world!")
        Hello, world!


    Happy coding with Elixir!
    """,
    background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    views: 0
  }

# Insert 20 more blog posts as example articles
posts = [
  %{
    title: "Phoenix LiveView Tips",
    body: """
    LiveView brings real-time interactivity to Phoenix applications without writing heavy front-end JS.

    - Use `phx-update=\"stream\"` for efficient list rendering.
    - Communicate using `handle_event` for interactive UIs.
    - Don't forget about assigns for reactive patterns!
    """,
    views: 15
  },
  %{
    title: "Understanding Elixir Processes",
    body: """
    Elixir processes are lightweight and isolated units of concurrency, making Elixir powerful for concurrent workloads.

    To spawn a process:
        spawn(fn -> IO.puts \"Hello from a process!\" end)
    """,
    views: 42
  },
  %{
    title: "Building REST APIs",
    body: """
    REST APIs are a fundamental part of modern web development with Phoenix, supporting JSON endpoints efficiently.

    Use controllers and routes to define your API endpoints, and be sure to use `render/2` for serialization.
    """,
    views: 87
  },
  %{
    title: "Pattern Matching in Elixir",
    body: """
    Pattern matching is one of Elixir's most powerful features.

        {a, b} = {1, 2}
        # a = 1, b = 2

    Use it for function heads, case statements, and more!
    """,
    views: 21
  },
  %{
    title: "Ecto Changesets Explained",
    body: """
    Changesets in Ecto allow you to filter, cast, and validate data before inserting into your database.

    Example:
        changeset = Changeset.cast(params, [:name, :email])
    """,
    views: 33
  },
  %{
    title: "Supervision Trees in OTP",
    body: """
    OTP supervision trees allow Elixir applications to be fault tolerant.

    Use `Supervisor.start_link/2` and define child specifications to set up robust trees.
    """,
    views: 18
  },
  %{
    title: "Deploying Phoenix with Fly.io",
    body: """
    Fly.io makes it easy to deploy distributed Phoenix apps. Try their free tier and check the docs for Elixir integration!
    """,
    views: 5
  },
  %{
    title: "Live Dashboard for Metrics",
    body: """
    Phoenix LiveDashboard provides real-time metrics and insights into your apps.

    Add it to your router in `dev` and `test` environments, then explore observer data!
    """,
    views: 8
  },
  %{
    title: "Testing with ExUnit",
    body: """
    Elixir ships ExUnit, a full-featured test framework. Just create files in test/, name modules `*_test.exs`, and use assert statements.
    """,
    views: 12
  },
  %{
    title: "Enum and Stream in Elixir",
    body: """
    Use Enum for eager processing:
        Enum.map([1,2,3], &(&1 * 2))

    Use Stream for lazy (on-demand) processing of data.
    """,
    views: 10
  },
  %{
    title: "Getting Started with Mix",
    body: """
    Mix helps you compile, test, and manage dependencies for Elixir apps.

    Try:
        mix new demo_project
        mix test

    to get started.
    """,
    views: 7
  },
  %{
    title: "Working with Dates and Times",
    body: """
    Elixir ships with Date, Time, NaiveDateTime, and DateTime types for universal and local handling of dates and times.
    """,
    views: 9
  },
  %{
    title: "Optimizing Phoenix Performance",
    body: """
    Always prefer streams, avoid N+1 database queries, preload associations, and leverage LiveView for seamless experiences.
    """,
    views: 16
  },
  %{
    title: "Understanding PubSub",
    body: """
    Phoenix PubSub gives your app real-time, distributed messaging. Use it for broadcasts and topic-based communication.
    """,
    views: 14
  },
  %{
    title: "Creating Custom Plugs",
    body: """
    Plugs are the building blocks of Phoenix pipelines. Write your own to inject authentication or instrumentation logic.
    """,
    views: 4
  },
  %{
    title: "Authentication in Phoenix",
    body: """
    Use phx.gen.auth for out-of-the-box authentication in Phoenix apps.

    Remember:
    - Log in and registration forms
    - Password resets
    - Secure pipelines
    """,
    views: 12
  },
  %{
    title: "The Power of Pattern Guards",
    body: """
    Pattern guards add extra power to your pattern matching.

        def my_fun(x) when is_integer(x) and x > 0 do
          # guard code
        end
    """,
    views: 13
  },
  %{
    title: "Ecto Query Basics",
    body: """
    Writing queries in Ecto is clear and safe:

        from u in User, where: u.active == true
    """,
    views: 19
  },
  %{
    title: "Concurrency with Task",
    body: """
    Use Task.async_stream/3 for easy and controlled concurrent enumeration in Elixir.

        Task.async_stream(list, &do_work/1)
    """,
    views: 23
  },
  %{
    title: "Elixir Macros for Metaprogramming",
    body: """
    Macros allow you to extend Elixir with your own constructs, but use sparingly!

        # defmacro hello(name), do: quote(do: IO.puts("Hello " <> to_string(name)))
        # This is a demonstration macro in a comment for safety in seeds!
    """,
    views: 8
  }
]

default_background = "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"

Enum.each(posts, fn attrs ->
  %Alchemistdrops.Posts.Post{
    title: attrs.title,
    body: attrs.body,
    background: default_background,
    views: attrs.views
  }
  |> Alchemistdrops.Repo.insert!()
end)

Alchemistdrops.Repo.insert!(post)

# ================================================================================
# Course Feature Seeds
# ================================================================================

alias Alchemistdrops.Repo
alias Alchemistdrops.Accounts.User
alias Alchemistdrops.Courses.{Course, Lesson}
alias Alchemistdrops.Enrollments.Enrollment
alias Alchemistdrops.Payments.Payment

# Create additional users with different roles
_admin_user =
  case Repo.get_by(User, email: "admin@alchemistdrops.com") do
    nil ->
      %User{
        email: "admin@alchemistdrops.com",
        hashed_password: Bcrypt.hash_pwd_salt("AdminPassword123!"),
        confirmed_at: DateTime.truncate(DateTime.utc_now(), :second),
        role: :admin
      }
      |> Repo.insert!()

    user ->
      user
  end

student_user =
  case Repo.get_by(User, email: "student@alchemistdrops.com") do
    nil ->
      %User{
        email: "student@alchemistdrops.com",
        hashed_password: Bcrypt.hash_pwd_salt("StudentPassword123!"),
        confirmed_at: DateTime.truncate(DateTime.utc_now(), :second),
        role: :student
      }
      |> Repo.insert!()

    user ->
      user
  end

regular_user =
  case Repo.get_by(User, email: "user@alchemistdrops.com") do
    nil ->
      %User{
        email: "user@alchemistdrops.com",
        hashed_password: Bcrypt.hash_pwd_salt("UserPassword123!"),
        confirmed_at: DateTime.truncate(DateTime.utc_now(), :second),
        role: :user
      }
      |> Repo.insert!()

    user ->
      user
  end

IO.puts("Created/Found users:")
IO.puts("  - Admin: admin@alchemistdrops.com (password: AdminPassword123!)")
IO.puts("  - Student: student@alchemistdrops.com (password: StudentPassword123!)")
IO.puts("  - User: user@alchemistdrops.com (password: UserPassword123!)")

# Create courses
elixir_course =
  %Course{
    title: "Complete Elixir Mastery",
    description: "Master Elixir from basics to advanced concepts",
    body: """
    # Complete Elixir Mastery

    This comprehensive course will take you from Elixir beginner to advanced practitioner.

    ## What You'll Learn
    - Elixir fundamentals
    - Functional programming concepts
    - OTP and concurrency
    - Building production applications

    ## Prerequisites
    Basic programming knowledge is helpful but not required.
    """,
    price: Money.new(9999, :USD),
    published: true,
    thumbnail_url: nil
  }
  |> Repo.insert!()

phoenix_course =
  %Course{
    title: "Phoenix Framework Deep Dive",
    description: "Build modern web applications with Phoenix",
    body: """
    # Phoenix Framework Deep Dive

    Learn to build scalable, real-time web applications using Phoenix Framework.

    ## Topics Covered
    - Phoenix fundamentals
    - LiveView for real-time UIs
    - Ecto database operations
    - Deployment strategies

    ## Who This Is For
    Developers with basic Elixir knowledge who want to build web applications.
    """,
    price: Money.new(14999, :USD),
    published: true,
    thumbnail_url: nil
  }
  |> Repo.insert!()

free_course =
  %Course{
    title: "Introduction to Functional Programming",
    description: "Get started with functional programming concepts",
    body: """
    # Introduction to Functional Programming

    A free course introducing you to the world of functional programming.

    ## What You'll Discover
    - Immutability
    - Pure functions
    - Higher-order functions
    - Function composition

    Perfect for beginners!
    """,
    price: Money.new(0, :USD),
    published: true,
    thumbnail_url: nil
  }
  |> Repo.insert!()

unpublished_course =
  %Course{
    title: "Advanced Distributed Systems",
    description: "Coming soon: Master distributed systems with Elixir",
    body: "This course is currently under development.",
    price: Money.new(19999, :USD),
    published: false
  }
  |> Repo.insert!()

# Course with real YouTube video lessons
video_course =
  %Course{
    title: "Elixir Video Tutorials",
    description: "Learn Elixir with real video tutorials from the community",
    body: """
    # Elixir Video Tutorials

    A curated collection of video tutorials to help you learn Elixir effectively.

    ## What's Included
    - Real-world video tutorials
    - Community-created content
    - Step-by-step guidance
    - Practical examples

    ## Perfect For
    Visual learners who prefer video content over text-based learning.
    """,
    price: Money.new(2999, :USD),
    published: true,
    thumbnail_url: nil
  }
  |> Repo.insert!()

IO.puts("\nCreated courses:")
IO.puts("  - #{elixir_course.title} ($#{elixir_course.price})")
IO.puts("  - #{phoenix_course.title} ($#{phoenix_course.price})")
IO.puts("  - #{free_course.title} (FREE)")
IO.puts("  - #{video_course.title} ($#{video_course.price})")
IO.puts("  - #{unpublished_course.title} (UNPUBLISHED)")

# Create lessons for Elixir course
elixir_lessons = [
  %{
    title: "Introduction to Elixir",
    description: "Learn the basics of Elixir syntax and concepts",
    content: """
    Welcome to Elixir! In this lesson, we'll cover:
    - Installing Elixir
    - Basic syntax
    - The Interactive Elixir shell (IEx)
    - Your first Elixir program
    """,
    order: 0,
    duration: 20,
    video_url: "https://example.com/videos/elixir-intro",
    published: true
  },
  %{
    title: "Pattern Matching",
    description: "Master Elixir's powerful pattern matching",
    content: """
    Pattern matching is a core feature of Elixir. Learn how to:
    - Match simple values
    - Destructure data structures
    - Use pattern matching in function heads
    - Handle complex matching scenarios
    """,
    order: 1,
    duration: 30,
    video_url: "https://example.com/videos/pattern-matching",
    published: true
  },
  %{
    title: "Data Types and Collections",
    description: "Explore Elixir's data types",
    content: """
    Dive into Elixir's built-in data types:
    - Atoms, tuples, and maps
    - Lists and keyword lists
    - Strings and binaries
    - Working with Enum and Stream
    """,
    order: 2,
    duration: 40,
    video_url: "https://example.com/videos/data-types",
    published: true
  },
  %{
    title: "Functions and Modules",
    description: "Organize code with functions and modules",
    content: """
    Learn to structure your Elixir code:
    - Anonymous functions
    - Named functions
    - Module attributes
    - Function arity and default arguments
    """,
    order: 3,
    duration: 35,
    published: true
  },
  %{
    title: "Processes and Concurrency",
    description: "Harness the power of the BEAM",
    content: """
    Understand Elixir's concurrency model:
    - Spawning processes
    - Message passing
    - Process supervision
    - Linking and monitoring
    """,
    order: 4,
    duration: 45,
    published: false
  }
]

Enum.each(elixir_lessons, fn lesson_attrs ->
  %Lesson{
    course_id: elixir_course.id,
    title: lesson_attrs.title,
    description: lesson_attrs.description,
    content: lesson_attrs.content,
    order: lesson_attrs.order,
    duration: lesson_attrs.duration,
    video_url: Map.get(lesson_attrs, :video_url),
    published: lesson_attrs.published
  }
  |> Repo.insert!()
end)

IO.puts("\nCreated #{length(elixir_lessons)} lessons for #{elixir_course.title}")

# Create lessons for Phoenix course
phoenix_lessons = [
  %{
    title: "Phoenix Setup and Architecture",
    description: "Get started with Phoenix",
    content: "Learn how to set up Phoenix and understand its architecture.",
    order: 0,
    duration: 25,
    published: true
  },
  %{
    title: "Building Your First Phoenix App",
    description: "Create a simple Phoenix application",
    content: "Build a simple CRUD application with Phoenix.",
    order: 1,
    duration: 40,
    published: true
  },
  %{
    title: "Phoenix LiveView Basics",
    description: "Introduction to real-time with LiveView",
    content: "Learn the fundamentals of Phoenix LiveView.",
    order: 2,
    duration: 50,
    published: true
  }
]

Enum.each(phoenix_lessons, fn lesson_attrs ->
  %Lesson{
    course_id: phoenix_course.id,
    title: lesson_attrs.title,
    description: lesson_attrs.description,
    content: lesson_attrs.content,
    order: lesson_attrs.order,
    duration: lesson_attrs.duration,
    published: lesson_attrs.published
  }
  |> Repo.insert!()
end)

IO.puts("Created #{length(phoenix_lessons)} lessons for #{phoenix_course.title}")

# Create lessons for free course
free_lessons = [
  %{
    title: "What is Functional Programming?",
    description: "Introduction to FP concepts",
    content: """
    Functional programming is a programming paradigm that treats computation as the evaluation of mathematical functions.

    In this video, you'll learn:
    - What makes FP different from other paradigms
    - Core principles: immutability, pure functions, first-class functions
    - Why Elixir is a great functional language

    Watch the video and discover the power of functional programming!
    """,
    order: 0,
    duration: 15,
    video_url: "https://youtu.be/NjBUcTEVsJo",
    published: true
  },
  %{
    title: "Immutability Explained",
    description: "Understanding immutable data",
    content: "Discover why immutability is important.",
    order: 1,
    duration: 20,
    published: true
  }
]

Enum.each(free_lessons, fn lesson_attrs ->
  %Lesson{
    course_id: free_course.id,
    title: lesson_attrs.title,
    description: lesson_attrs.description,
    content: lesson_attrs.content,
    order: lesson_attrs.order,
    duration: lesson_attrs.duration,
    video_url: Map.get(lesson_attrs, :video_url),
    published: lesson_attrs.published
  }
  |> Repo.insert!()
end)

IO.puts("Created #{length(free_lessons)} lessons for #{free_course.title}")

# Create lessons for video course with real YouTube URLs
video_lessons = [
  %{
    title: "Elixir Fundamentals - Getting Started",
    description: "Introduction to Elixir programming language basics",
    content: """
    In this video lesson, you'll learn the fundamentals of Elixir:

    - Setting up your development environment
    - Understanding the basic syntax
    - Working with data types
    - Interactive Elixir shell (IEx)

    Watch the video above and follow along with the examples!
    """,
    order: 0,
    duration: 15,
    video_url: "https://youtu.be/NjBUcTEVsJo",
    published: true
  },
  %{
    title: "Pattern Matching Deep Dive",
    description: "Master pattern matching in Elixir",
    content: """
    Pattern matching is one of Elixir's most powerful features!

    This lesson covers:
    - Basic pattern matching
    - Destructuring lists and maps
    - Using pattern matching in function heads
    - Advanced matching techniques

    Follow along with the video tutorial above.
    """,
    order: 1,
    duration: 20,
    video_url: "https://youtu.be/IbHyK6a0-xQ",
    published: true
  }
]

Enum.each(video_lessons, fn lesson_attrs ->
  %Lesson{
    course_id: video_course.id,
    title: lesson_attrs.title,
    description: lesson_attrs.description,
    content: lesson_attrs.content,
    order: lesson_attrs.order,
    duration: lesson_attrs.duration,
    video_url: lesson_attrs.video_url,
    published: lesson_attrs.published
  }
  |> Repo.insert!()
end)

IO.puts(
  "Created #{length(video_lessons)} lessons for #{video_course.title} (with YouTube videos)"
)

# Create enrollments
_student_elixir_enrollment =
  %Enrollment{
    user_id: student_user.id,
    course_id: elixir_course.id,
    status: "active",
    enrolled_at: DateTime.utc_now(:second)
  }
  |> Repo.insert!()

_student_free_enrollment =
  %Enrollment{
    user_id: student_user.id,
    course_id: free_course.id,
    status: "completed",
    enrolled_at: DateTime.add(DateTime.utc_now(:second), -30, :day),
    completed_at: DateTime.add(DateTime.utc_now(:second), -5, :day)
  }
  |> Repo.insert!()

_regular_free_enrollment =
  %Enrollment{
    user_id: regular_user.id,
    course_id: free_course.id,
    status: "active",
    enrolled_at: DateTime.utc_now(:second)
  }
  |> Repo.insert!()

IO.puts("\nCreated enrollments:")
IO.puts("  - Student enrolled in #{elixir_course.title}")
IO.puts("  - Student completed #{free_course.title}")
IO.puts("  - User enrolled in #{free_course.title}")

# Create payment records
student_payment =
  %Payment{
    user_id: student_user.id,
    course_id: elixir_course.id,
    amount: elixir_course.price,
    status: "completed",
    stripe_payment_intent_id: "pi_demo_#{System.unique_integer([:positive])}",
    stripe_checkout_session_id: "cs_demo_#{System.unique_integer([:positive])}",
    metadata: %{
      "course_title" => elixir_course.title,
      "user_email" => student_user.email
    }
  }
  |> Repo.insert!()

IO.puts("\nCreated payments:")
IO.puts("  - Student paid $#{student_payment.amount} for #{elixir_course.title}")

IO.puts("\n✅ Course feature seeds completed successfully!")
IO.puts("\n📚 Summary:")
IO.puts("  - 5 courses created (4 published, 1 unpublished)")

IO.puts(
  "  - #{length(elixir_lessons) + length(phoenix_lessons) + length(free_lessons) + length(video_lessons)} lessons created"
)

IO.puts("  - 3 enrollments created")
IO.puts("  - 1 payment record created")
IO.puts("\n👤 Test Accounts:")
IO.puts("  - Admin: admin@alchemistdrops.com / AdminPassword123!")
IO.puts("  - Student: student@alchemistdrops.com / StudentPassword123!")
IO.puts("  - User: user@alchemistdrops.com / UserPassword123!")
