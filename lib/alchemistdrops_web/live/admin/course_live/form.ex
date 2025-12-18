defmodule AlchemistdropsWeb.Admin.CourseLive.Form do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Courses.Course

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
    course = Courses.get_course!(id)

    socket
    |> assign(:page_title, "Edit Course")
    |> assign(:course, course)
    |> assign(:form, to_form(Courses.change_course(course)))
  end

  defp apply_action(socket, :new, _params) do
    course = %Course{}

    socket
    |> assign(:page_title, "New Course")
    |> assign(:course, course)
    |> assign(:form, to_form(Courses.change_course(course)))
  end

  @impl true
  def handle_event("validate", %{"course" => course_params}, socket) do
    course_params = normalize_price(course_params)
    changeset = Courses.change_course(socket.assigns.course, course_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"course" => course_params}, socket) do
    course_params = normalize_price(course_params)
    save_course(socket, socket.assigns.live_action, course_params)
  end

  defp save_course(socket, :edit, course_params) do
    case Courses.update_course(socket.assigns.course, course_params) do
      {:ok, course} ->
        {:noreply,
         socket
         |> put_flash(:info, "Course updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, course))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_course(socket, :new, course_params) do
    case Courses.create_course(course_params) do
      {:ok, course} ->
        {:noreply,
         socket
         |> put_flash(:info, "Course created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, course))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def return_path("index", _course), do: ~p"/admin/courses"
  def return_path("show", course), do: ~p"/admin/courses/#{course}"

  # Convert price from cents string to Money struct
  defp normalize_price(params) do
    case params["price"] do
      "" ->
        Map.put(params, "price", Money.new(0, :USD))

      price when is_binary(price) ->
        case Integer.parse(price) do
          {cents, _} -> Map.put(params, "price", Money.new(cents, :USD))
          :error -> params
        end

      _ ->
        params
    end
  end
end
