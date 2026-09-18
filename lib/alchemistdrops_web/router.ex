defmodule AlchemistdropsWeb.Router do
  use AlchemistdropsWeb, :router

  import AlchemistdropsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlchemistdropsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :stripe_webhook do
    plug :accepts, ["json"]
    plug AlchemistdropsWeb.Plugs.RawBody
  end

  pipeline :xml do
    plug :accepts, ["xml"]
  end

  scope "/", AlchemistdropsWeb do
    pipe_through :xml

    get "/sitemap.xml", BlogDiscoveryController, :sitemap
    get "/blog/feed.xml", BlogDiscoveryController, :feed
  end

  # Stripe webhook endpoint
  scope "/webhooks", AlchemistdropsWeb do
    pipe_through :stripe_webhook

    post "/stripe", StripeWebhookController, :webhook
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:alchemistdrops, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AlchemistdropsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", AlchemistdropsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AlchemistdropsWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/student/courses/:course_id/lessons", StudentLive.Lesson, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", AlchemistdropsWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{AlchemistdropsWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive.Index, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new

      live "/blog", PostLive.Index, :index
      live "/blog/:slug", PostLive.Show, :show
      live "/about", AboutLive.Index, :index
      live "/skills", SkillsLive.Index, :index

      live "/courses", CourseLive.Index, :index
      live "/courses/:id", CourseLive.Show, :show
    end

    scope "/admin", Admin do
      live_session :required_admin_user,
        on_mount: [{AlchemistdropsWeb.UserAuth, :require_admin_user}] do
        live "/posts", PostLive.Index, :index
        live "/posts/new", PostLive.Form, :new
        live "/posts/:id", PostLive.Show, :show
        live "/posts/:id/edit", PostLive.Form, :edit

        live "/courses", CourseLive.Index, :index
        live "/courses/new", CourseLive.Form, :new
        live "/courses/:id", CourseLive.Show, :show
        live "/courses/:id/edit", CourseLive.Form, :edit

        live "/courses/:course_id/lessons/new", LessonLive.Form, :new
        live "/courses/:course_id/lessons/:id/edit", LessonLive.Form, :edit

        live "/enrollments", EnrollmentLive.Index, :index
        live "/users", UserLive.Index, :index
      end
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
