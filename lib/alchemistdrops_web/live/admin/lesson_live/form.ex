defmodule AlchemistdropsWeb.Admin.LessonLive.Form do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Courses.Lesson

  @impl true
  def mount(params, _session, socket) do
    course_id = params["course_id"]
    course = Courses.get_course!(course_id)

    {:ok,
     socket
     |> assign(:course, course)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    lesson =
      socket.assigns.course.lessons
      |> Enum.find(&(&1.id == id))

    # If lesson not in preloaded list, fetch directly
    lesson = lesson || Alchemistdrops.Repo.get!(Lesson, id)

    socket
    |> assign(:page_title, "Edit Lesson")
    |> assign(:lesson, lesson)
    |> assign(:form, to_form(Courses.change_lesson(lesson)))
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
