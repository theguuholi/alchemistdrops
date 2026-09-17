defmodule AlchemistdropsWeb.Admin.PostLive.Form do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Post

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Create, organize, and publish the article when it is ready.</:subtitle>
        <:actions>
          <span class={["badge", @post.status == :published && "badge-success"]}>
            {status_label(@post)}
          </span>
          <.link
            :if={@post.status == :published}
            id="public-post-link"
            navigate={~p"/blog/#{@post.slug}"}
            class="btn btn-sm btn-ghost"
          >
            View article <.icon name="hero-arrow-up-right" class="size-4" />
          </.link>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 xl:gap-8">
        <div class="min-w-0">
          <.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
            <div class="space-y-6">
              <section class="rounded-2xl border border-base-300 bg-base-100 p-5">
                <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/60">
                  Content
                </h2>
                <.input field={@form[:title]} type="text" label="Title" />
                <.input
                  field={@form[:summary]}
                  type="textarea"
                  label="Summary"
                  rows="3"
                  maxlength="240"
                />
                <.input
                  field={@form[:body]}
                  id="post-form_body"
                  type="textarea"
                  label="Body (Markdown)"
                  rows="18"
                  phx-debounce="200"
                  class="w-full textarea min-h-[420px] font-mono text-sm resize-y"
                  placeholder="Write your post in Markdown..."
                />
              </section>

              <section class="rounded-2xl border border-base-300 bg-base-100 p-5">
                <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/60">
                  Organization
                </h2>
                <.input
                  field={@form[:category_name]}
                  id="post-category"
                  type="text"
                  label="Primary category"
                  list="post-category-options"
                  placeholder="Choose or create a category"
                />
                <p
                  :for={msg <- form_errors(@form, :category_id)}
                  class="-mt-1 mb-2 flex items-center gap-2 text-sm text-error"
                >
                  <.icon name="hero-exclamation-circle" class="size-5" /> {msg}
                </p>
                <datalist id="post-category-options">
                  <option :for={category <- @categories} value={category.name}></option>
                </datalist>
                <.input
                  field={@form[:tag_names]}
                  id="post-tags"
                  type="text"
                  label="Tags"
                  placeholder="Elixir, LiveView, OTP"
                />
                <p
                  :for={msg <- form_errors(@form, :tags)}
                  class="-mt-1 mb-2 flex items-center gap-2 text-sm text-error"
                >
                  <.icon name="hero-exclamation-circle" class="size-5" /> {msg}
                </p>
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  Up to five comma-separated tags.
                </p>
                <.input
                  field={@form[:language]}
                  type="select"
                  label="Language"
                  options={[{"English", :en}, {"Português (Brasil)", :pt_br}]}
                />
              </section>

              <section class="rounded-2xl border border-base-300 bg-base-100 p-5">
                <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/60">
                  Conversion
                </h2>
                <.input
                  field={@form[:related_course_id]}
                  id="post-related-course"
                  type="select"
                  label="Related course (optional)"
                  prompt="No related course"
                  options={Enum.map(@courses, &{&1.title, &1.id})}
                />
              </section>

              <section class="rounded-2xl border border-base-300 bg-base-100 p-5">
                <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/60">
                  Search and sharing
                </h2>
                <.input field={@form[:seo_title]} type="text" label="SEO title" maxlength="60" />
                <.input
                  field={@form[:seo_description]}
                  type="textarea"
                  label="SEO description"
                  rows="3"
                  maxlength="160"
                />
                <.input field={@form[:cover_image_url]} type="url" label="Cover image URL" />
                <.input field={@form[:cover_image_alt]} type="text" label="Cover image alt text" />
                <div
                  id="seo-preview"
                  class="mt-4 rounded-xl border border-base-300 bg-base-200/50 p-4"
                >
                  <p class="text-xs uppercase tracking-wider text-base-content/50">Search preview</p>
                  <p class="mt-2 font-semibold text-primary">{seo_preview_title(@form)}</p>
                  <p class="mt-1 text-sm text-base-content/70">{seo_preview_description(@form)}</p>
                </div>
              </section>

              <details class="rounded-2xl border border-base-300 bg-base-100 p-5">
                <summary class="cursor-pointer font-medium">Advanced appearance</summary>
                <div class="mt-4 grid gap-4 sm:grid-cols-2">
                  <.input field={@form[:background]} type="text" label="Background" />
                  <.input field={@form[:views]} type="number" label="Views" />
                </div>
              </details>
            </div>

            <footer class="mt-6 flex flex-wrap gap-3">
              <.button
                id="save-draft"
                name="intent"
                value="draft"
                phx-disable-with="Saving..."
                variant="primary"
              >
                {if @post.status == :published, do: "Save changes", else: "Save draft"}
              </.button>
              <.button
                :if={@post.status == :draft}
                id="publish-post"
                name="intent"
                value="publish"
                phx-disable-with="Publishing..."
              >
                Publish article
              </.button>
              <.button
                :if={@post.status == :published}
                id="unpublish-post"
                type="button"
                phx-click="unpublish"
                data-confirm="Return this article to draft?"
              >
                Unpublish
              </.button>
              <.button navigate={return_path(@return_to, @post)}>Cancel</.button>
            </footer>
          </.form>
        </div>

        <div class="min-w-0 flex flex-col">
          <div class="label mb-1 flex items-center gap-2">
            <.icon name="hero-eye" class="w-4 h-4 text-base-content/60" /> Preview
          </div>
          <div
            id="post-preview"
            class="flex-1 min-h-[420px] rounded-lg border border-base-300 overflow-auto bg-base-100"
          >
            <%!-- Same layout as post show: post-body section + article.prose max-w-3xl; bg-base-100 respects current theme --%>
            <section class="px-6 sm:px-8 py-8 sm:py-10">
              <article id="preview-article" class="max-w-3xl prose" phx-hook="Mermaid">
                {@preview_html}
              </article>
            </section>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    post = Posts.get_admin_post!(id)

    socket
    |> assign_editorial_options()
    |> assign(:page_title, "Edit Post")
    |> assign(:post, post)
    |> assign(:form, post_form(post))
    |> assign(:preview_html, render_preview(post.body))
  end

  defp apply_action(socket, :new, _params) do
    post = %Post{}

    socket
    |> assign_editorial_options()
    |> assign(:page_title, "New Post")
    |> assign(:post, post)
    |> assign(:form, to_form(Posts.change_post(post)))
    |> assign(:preview_html, render_preview(nil))
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset = Posts.change_post(socket.assigns.post, post_params)
    body = post_params["body"]
    preview_html = render_preview(body)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, action: :validate))
     |> assign(:preview_html, preview_html)}
  end

  def handle_event("save", %{"post" => post_params, "intent" => intent}, socket) do
    save_post(socket, post_params, intent)
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, post_params, "draft")
  end

  def handle_event("unpublish", _params, socket) do
    case Posts.unpublish_post(socket.assigns.post) do
      {:ok, post} ->
        post = Posts.get_admin_post!(post.id)

        {:noreply,
         socket
         |> assign(:post, post)
         |> assign(:form, post_form(post))
         |> put_flash(:info, "Draft saved")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_post(socket, post_params, "publish") do
    with {:ok, post} <- persist_post(socket.assigns.post, post_params),
         {:ok, published} <- Posts.publish_post(post) do
      {:noreply,
       socket
       |> put_flash(:info, "Article published")
       |> push_navigate(to: ~p"/admin/posts/#{published}/edit")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        post = changeset.data

        {:noreply,
         socket
         |> assign(:post, post)
         |> assign(:form, to_form(changeset, action: :validate))}
    end
  end

  defp save_post(socket, post_params, _intent) do
    case persist_post(socket.assigns.post, post_params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, success_message(socket.assigns.post))
         |> push_navigate(to: return_path(socket.assigns.return_to, post))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp persist_post(%Post{id: nil}, post_params), do: Posts.create_post(post_params)
  defp persist_post(%Post{} = post, post_params), do: Posts.update_post(post, post_params)

  defp success_message(%Post{id: nil}), do: "Post created successfully"
  defp success_message(%Post{}), do: "Post updated successfully"

  defp return_path("index", _post), do: ~p"/admin/posts"
  defp return_path("show", post), do: ~p"/admin/posts/#{post}"

  defp render_preview(nil), do: Phoenix.HTML.raw("")
  defp render_preview(""), do: Phoenix.HTML.raw("")

  defp render_preview(content) when is_binary(content) do
    {:ok, html} = Alchemistdrops.Markdown.to_html(content)
    Phoenix.HTML.raw(html)
  end

  defp assign_editorial_options(socket) do
    socket
    |> assign(:categories, Posts.list_categories())
    |> assign(:courses, Courses.list_all_courses())
  end

  defp post_form(post) do
    attrs = %{
      "category_name" => association_name(post.category),
      "tag_names" => association_names(post.tags)
    }

    post
    |> Posts.change_post(attrs)
    |> to_form()
  end

  defp association_name(%Ecto.Association.NotLoaded{}), do: ""
  defp association_name(nil), do: ""
  defp association_name(category), do: category.name

  defp association_names(%Ecto.Association.NotLoaded{}), do: ""
  defp association_names(tags), do: Enum.map_join(tags, ", ", & &1.name)

  defp status_label(%Post{status: :published}), do: "Published"
  defp status_label(%Post{}), do: "Draft"

  defp seo_preview_title(form),
    do:
      present_value(form[:seo_title].value) || present_value(form[:title].value) ||
        "Article title"

  defp seo_preview_description(form),
    do:
      present_value(form[:seo_description].value) || present_value(form[:summary].value) ||
        "Add a summary to preview the search description."

  defp present_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      present -> present
    end
  end

  defp present_value(_value), do: nil

  defp form_errors(form, field) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.map(&translate_error/1)
  end
end
