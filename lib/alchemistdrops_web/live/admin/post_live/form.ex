defmodule AlchemistdropsWeb.Admin.PostLive.Form do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Post

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
              <article class="max-w-3xl prose">
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
  end

  defp apply_action(socket, :new, _params) do
    post = %Post{}

    socket
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

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.live_action, post_params)
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

  defp render_preview(nil), do: Phoenix.HTML.raw("")
  defp render_preview(""), do: Phoenix.HTML.raw("")

  defp render_preview(content) when is_binary(content) do
    case MDEx.to_html(content) do
      {:ok, html} -> Phoenix.HTML.raw(html)
      _ -> Phoenix.HTML.raw("")
    end
  end
end
