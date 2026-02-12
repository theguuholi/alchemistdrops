defmodule AlchemistdropsWeb.Admin.LessonLive.Form do
  @moduledoc """
  Admin LiveView for creating and editing lessons.
  Mobile-first responsive design with proper validation.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Courses.Lesson

  @impl true
  def mount(params, _session, socket) do
    course = Courses.get_course!(params["course_id"])

    {:ok,
     socket
     |> assign(:course, course)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    lesson = Enum.find(socket.assigns.course.lessons, &(&1.id == id))

    if lesson do
      socket
      |> assign(:page_title, "Edit Lesson")
      |> assign(:lesson, lesson)
      |> assign(:form, to_form(Courses.change_lesson(lesson)))
    else
      socket
      |> put_flash(:error, "Lesson not found")
      |> push_navigate(to: ~p"/admin/courses/#{socket.assigns.course}")
    end
  end

  defp apply_action(socket, :new, _params) do
    lesson = %Lesson{course_id: socket.assigns.course.id}

    socket
    |> assign(:page_title, "New Lesson")
    |> assign(:lesson, lesson)
    |> assign(:form, to_form(Courses.change_lesson(lesson)))
  end

  @impl true
  def handle_event("validate", %{"lesson" => lesson_params}, socket) do
    changeset = Courses.change_lesson(socket.assigns.lesson, lesson_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"lesson" => lesson_params}, socket) do
    save_lesson(socket, socket.assigns.live_action, lesson_params)
  end

  defp save_lesson(socket, :edit, lesson_params) do
    case Courses.update_lesson(socket.assigns.lesson, lesson_params) do
      {:ok, _lesson} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lesson updated successfully")
         |> push_navigate(to: ~p"/admin/courses/#{socket.assigns.course}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_lesson(socket, :new, lesson_params) do
    case Courses.create_lesson(socket.assigns.course, lesson_params) do
      {:ok, _lesson} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lesson created successfully")
         |> push_navigate(to: ~p"/admin/courses/#{socket.assigns.course}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
