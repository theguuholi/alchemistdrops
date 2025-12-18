defmodule AlchemistdropsWeb.Admin.CourseLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Courses.get_course_with_lessons!(id)

    {:ok,
     socket
     |> assign(:page_title, course.title)
     |> assign(:course, course)}
  end

  @impl true
  def handle_event("delete_lesson", %{"id" => id}, socket) do
    lesson = Enum.find(socket.assigns.course.lessons, &(&1.id == id))

    if lesson do
      {:ok, _} = Courses.delete_lesson(lesson)
      course = Courses.get_course_with_lessons!(socket.assigns.course.id)
      {:noreply, assign(socket, :course, course)}
    else
      {:noreply, socket}
    end
  end

  def format_price(nil), do: "Free"

  def format_price(%Money{} = money) do
    if Money.zero?(money) do
      "Free"
    else
      Money.to_string(money)
    end
  end

  def format_price(_), do: "Free"
end
