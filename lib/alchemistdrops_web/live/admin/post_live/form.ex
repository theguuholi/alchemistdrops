defmodule AlchemistdropsWeb.Admin.PostLive.Form do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Posts
  alias Alchemistdrops.Posts.Post

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
