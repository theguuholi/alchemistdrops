defmodule AlchemistdropsWeb.Admin.CourseLive.Show do
  @moduledoc """
  Admin LiveView for displaying course details and managing lessons.
  Mobile-first responsive design.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Courses.get_course_with_lessons!(id)

    {:ok,
     socket
     |> assign(:page_title, course.title)
     |> assign(:course, course)
     |> stream(:lessons, course.lessons)}
  end

  @impl true
  def handle_event("delete_lesson", %{"id" => id}, socket) do
    lesson = Enum.find(socket.assigns.course.lessons, &(&1.id == id))

    if lesson do
      {:ok, _} = Courses.delete_lesson(lesson)
      {:noreply, stream_delete(socket, :lessons, lesson)}
    else
      {:noreply, socket}
    end
  end
end
