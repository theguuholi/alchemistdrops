defmodule AlchemistdropsWeb.Admin.CourseLive.Show do
  @moduledoc """
  Admin LiveView for displaying course details and managing lessons.
  Mobile-first responsive design.
  """
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Money

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Courses.get_course_with_lessons!(id)
    lessons = course.lessons

    {:ok,
     socket
     |> assign(:page_title, course.title)
     |> assign(:course, course)
     |> assign(:lessons_count, length(lessons))
     |> assign(:lessons_empty?, lessons == [])
     |> stream(:lessons, lessons)}
  end

  @impl true
  def handle_event("delete_lesson", %{"id" => id}, socket) do
    lesson = Enum.find(socket.assigns.course.lessons, &(to_string(&1.id) == to_string(id)))

    if lesson do
      {:ok, _} = Courses.delete_lesson(lesson)
      new_count = max(0, socket.assigns.lessons_count - 1)

      {:noreply,
       socket
       |> assign(:lessons_count, new_count)
       |> assign(:lessons_empty?, new_count == 0)
       |> stream_delete(:lessons, lesson)}
    else
      {:noreply, socket}
    end
  end

  defp price_free?(nil), do: true
  defp price_free?(%Money{amount: 0}), do: true
  defp price_free?(_), do: false

  defp format_price(nil), do: "Free"
  defp format_price(%Money{amount: 0}), do: "Free"
  defp format_price(price), do: Money.to_string(price)
end
