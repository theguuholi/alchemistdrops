defmodule AlchemistdropsWeb.Admin.PostLive.Form do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Post
  alias Alchemistdrops.Social

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage post records in your database.</:subtitle>
      </.header>

      <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 xl:gap-8">
        <div class="min-w-0">
          <.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:background]} type="text" label="Background" />
            <.input field={@form[:title]} type="text" label="Title" />
            <div class="fieldset mb-2">
              <label>
                <span class="label mb-1">Body (Markdown)</span>
                <textarea
                  id="post-form_body"
                  name="post[body]"
                  phx-debounce="200"
                  class={[
                    "w-full textarea min-h-[420px] font-mono text-sm resize-y",
                    @form[:body].errors != [] && "textarea-error"
                  ]}
                  placeholder="Write your post in Markdown..."
                >{Phoenix.HTML.Form.normalize_value("textarea", @form[:body].value)}</textarea>
              </label>
              <p
                :for={msg <- Enum.map(@form[:body].errors, &translate_error(&1))}
                class="mt-1.5 flex gap-2 items-center text-sm text-error"
              >
                <.icon name="hero-exclamation-circle" class="size-5" />
                {msg}
              </p>
            </div>
            <.input field={@form[:views]} type="number" label="Views" />
            <footer>
              <.button phx-disable-with="Saving..." variant="primary">Save Post</.button>
              <.button navigate={return_path(@return_to, @post)}>Cancel</.button>
            </footer>
          </.form>

          <section :if={@post.id} id="linkedin-section" class="mt-8 border-t border-base-300 pt-6">
            <div class="mb-4 flex items-center gap-2">
              <.icon name="hero-link" class="size-5 text-base-content/70" />
              <h2 class="text-base font-semibold">LinkedIn</h2>
            </div>

            <%= cond do %>
              <% published_share?(@linkedin_share) -> %>
                <div id="linkedin-published" class="alert alert-success items-start">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0" />
                  <div>
                    <p class="font-medium">Published to LinkedIn</p>
                    <p class="text-sm">{published_share_details(@linkedin_share)}</p>
                  </div>
                </div>
              <% not @linkedin_connected? -> %>
                <.button
                  id="linkedin-connect"
                  href={~p"/admin/linkedin/connect?post_id=#{@post.id}"}
                >
                  <.icon name="hero-link" class="size-4" /> Connect LinkedIn
                </.button>
              <% true -> %>
                <div class="flex flex-wrap items-center gap-3">
                  <.button
                    id="generate-linkedin"
                    phx-click="generate_linkedin"
                    phx-disable-with="Generating LinkedIn preview..."
                    disabled={@linkedin_dirty?}
                  >
                    <.icon name="hero-share" class="size-4" />
                    {if @linkedin_share,
                      do: "Regenerate LinkedIn preview",
                      else: "Generate LinkedIn preview"}
                  </.button>
                  <p :if={@linkedin_dirty?} class="text-sm text-base-content/70">
                    Save article changes before generating or publishing.
                  </p>
                </div>

                <div :if={editable_share?(@linkedin_share)} class="mt-4 space-y-3">
                  <.form
                    for={@linkedin_share_form}
                    id="linkedin-share-form"
                    phx-change="edit_linkedin_share"
                  >
                    <.input
                      field={@linkedin_share_form[:text]}
                      type="textarea"
                      label="LinkedIn preview"
                      rows="8"
                      maxlength="3000"
                      phx-debounce="300"
                    />
                  </.form>

                  <p class="text-sm text-base-content/70">
                    Detected language: {@linkedin_share.language}
                  </p>

                  <div :if={@linkedin_share.status == :failed} class="alert alert-error items-start">
                    <.icon name="hero-exclamation-circle" class="mt-0.5 size-5 shrink-0" />
                    <p>{@linkedin_share.error_message}</p>
                  </div>

                  <.button
                    id="publish-linkedin"
                    phx-click="publish_linkedin"
                    phx-disable-with="Publishing to LinkedIn..."
                    data-confirm="Publish this post to your LinkedIn profile?"
                    disabled={@linkedin_dirty?}
                    variant="primary"
                  >
                    <.icon name="hero-share" class="size-4" /> Publish to LinkedIn
                  </.button>
                </div>
            <% end %>
          </section>
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
    post = Posts.get_post!(id)

    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, post)
    |> assign(:form, to_form(Posts.change_post(post)))
    |> assign(:preview_html, render_preview(post.body))
    |> assign_linkedin_state(post)
  end

  defp apply_action(socket, :new, _params) do
    post = %Post{}

    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, post)
    |> assign(:form, to_form(Posts.change_post(post)))
    |> assign(:preview_html, render_preview(nil))
    |> assign(:linkedin_connected?, false)
    |> assign(:linkedin_share, nil)
    |> assign(:linkedin_share_form, linkedin_share_form(nil))
    |> assign(:linkedin_dirty?, false)
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset = Posts.change_post(socket.assigns.post, post_params)
    body = post_params["body"]
    preview_html = render_preview(body)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, action: :validate))
     |> assign(:preview_html, preview_html)
     |> assign(:linkedin_dirty?, map_size(changeset.changes) > 0)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.live_action, post_params)
  end

  def handle_event("generate_linkedin", _params, socket) do
    if linkedin_action_allowed?(socket) do
      post = socket.assigns.post

      case Social.generate_share(post, article_url(post)) do
        {:ok, share} ->
          {:noreply, assign_linkedin_share(socket, share)}

        {:error, _reason} ->
          {:noreply,
           socket
           |> assign_linkedin_share(Social.get_share(post))
           |> put_flash(:error, "LinkedIn preview could not be generated. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("edit_linkedin_share", %{"linkedin_share" => %{"text" => text}}, socket) do
    case socket.assigns.linkedin_share do
      nil ->
        {:noreply, socket}

      share ->
        case Social.update_share_text(share, text) do
          {:ok, updated_share} ->
            {:noreply, assign_linkedin_share(socket, updated_share)}

          {:error, _reason} ->
            {:noreply, assign_linkedin_share(socket, Social.get_share(socket.assigns.post))}
        end
    end
  end

  def handle_event("publish_linkedin", _params, socket) do
    if linkedin_action_allowed?(socket) and editable_share?(socket.assigns.linkedin_share) do
      post = socket.assigns.post

      case Social.publish_share(post, article_url(post)) do
        {:ok, share} ->
          {:noreply, assign_linkedin_share(socket, share)}

        {:error, :linkedin_connection_required} ->
          {:noreply,
           socket
           |> refresh_linkedin_connection()
           |> assign_linkedin_share(Social.get_share(post))}

        {:error, _reason} ->
          {:noreply, assign_linkedin_share(socket, Social.get_share(post))}
      end
    else
      {:noreply, socket}
    end
  end

  defp save_post(socket, :edit, post_params) do
    case Posts.update_post(socket.assigns.post, post_params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, post))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_post(socket, :new, post_params) do
    case Posts.create_post(post_params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, post))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _post), do: ~p"/admin/posts"
  defp return_path("show", post), do: ~p"/admin/posts/#{post}"

  defp assign_linkedin_state(socket, post) do
    socket
    |> refresh_linkedin_connection()
    |> assign(:linkedin_dirty?, false)
    |> assign_linkedin_share(Social.get_share(post))
  end

  defp refresh_linkedin_connection(socket) do
    assign(socket, :linkedin_connected?, Social.connected?())
  end

  defp assign_linkedin_share(socket, share) do
    socket
    |> assign(:linkedin_share, share)
    |> assign(:linkedin_share_form, linkedin_share_form(share))
  end

  defp linkedin_share_form(share) do
    to_form(%{"text" => share_text(share)}, as: :linkedin_share)
  end

  defp share_text(nil), do: ""
  defp share_text(share), do: share.edited_text || share.generated_text || ""

  defp linkedin_action_allowed?(socket) do
    socket.assigns.linkedin_connected? and not socket.assigns.linkedin_dirty?
  end

  defp editable_share?(nil), do: false
  defp editable_share?(share), do: share.status in [:draft, :failed]
  defp published_share?(nil), do: false
  defp published_share?(share), do: share.status == :published

  defp article_url(post), do: url(~p"/blog/#{post.slug}")

  defp published_share_details(share) do
    published_at = Calendar.strftime(share.published_at, "%B %-d, %Y at %H:%M UTC")
    "#{published_at} - #{share.linkedin_post_urn}"
  end

  defp render_preview(nil), do: Phoenix.HTML.raw("")
  defp render_preview(""), do: Phoenix.HTML.raw("")

  defp render_preview(content) when is_binary(content) do
    {:ok, html} = Alchemistdrops.Markdown.to_html(content)
    Phoenix.HTML.raw(html)
  end
end
