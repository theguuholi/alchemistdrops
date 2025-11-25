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
