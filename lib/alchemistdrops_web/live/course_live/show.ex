defmodule AlchemistdropsWeb.CourseLive.Show do
  use AlchemistdropsWeb, :live_view

  alias Alchemistdrops.Courses
  alias Alchemistdrops.Enrollments
  alias Alchemistdrops.Payments

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Courses.get_course!(id)

    if course.published do
      {:ok,
       socket
       |> assign(:course, course)
       |> assign_enrollment_status()
       |> load_lessons()}
    else
      raise Ecto.NoResultsError, queryable: Alchemistdrops.Courses.Course
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, socket.assigns.course.title)
      |> maybe_handle_purchase_return(params)

    {:noreply, socket}
  end

  defp maybe_handle_purchase_return(socket, %{"purchase" => "success"}) do
    socket
    |> assign_enrollment_status()
    |> put_flash(:info, "Payment successful! You're now enrolled in this course.")
  end

  defp maybe_handle_purchase_return(socket, %{"purchase" => "cancelled"}) do
    put_flash(socket, :info, "Checkout cancelled. You can purchase when you're ready.")
  end

  defp maybe_handle_purchase_return(socket, _params), do: socket

  @impl true
  def handle_event("enroll_free", _params, socket) do
    current_user = socket.assigns.current_scope.user
    course = socket.assigns.course

    {:ok, _enrollment} = Enrollments.enroll_user(current_user.id, course.id)

    {:noreply,
     socket
     |> put_flash(:info, "Successfully enrolled!")
     |> assign(:enrolled?, true)}
  end

  @impl true
  def handle_event("purchase", _params, socket) do
    current_user = socket.assigns.current_scope.user
    course = socket.assigns.course

    if blank?(course.stripe_price_id) do
      {:noreply,
       put_flash(
         socket,
         :error,
         "This course is not set up for payment. The administrator must set a Stripe Price ID on the course."
       )}
    else
      base = AlchemistdropsWeb.Endpoint.url()
      success_url = base <> ~p"/courses/#{course.id}" <> "?purchase=success"
      cancel_url = base <> ~p"/courses/#{course.id}" <> "?purchase=cancelled"

      case Payments.create_checkout_session(current_user, course, success_url, cancel_url) do
        {:ok, %{checkout_url: checkout_url}} ->
          {:noreply, redirect(socket, external: checkout_url)}

        {:error, :course_is_free} ->
          {:noreply,
           socket
           |> put_flash(:error, "This course is free. Use Enroll Now instead.")
           |> assign(:enrolled?, false)}

        {:error, {:stripe_error, _status, body}} ->
          message =
            get_in(body, ["error", "message"]) ||
              "Stripe could not start checkout. Check the course has a Stripe Price ID set."

          {:noreply, put_flash(socket, :error, message)}

        {:error, {:request_failed, reason}} ->
          {:noreply,
           put_flash(socket, :error, "Checkout unavailable. Please try again. #{inspect(reason)}")}
      end
    end
  end

  defp blank?(nil), do: true
  defp blank?(s) when is_binary(s), do: String.trim(s) == ""
  defp blank?(_), do: false

  defp assign_enrollment_status(socket) do
    current_user =
      case socket.assigns do
        %{current_scope: %{user: user}} -> user
        _ -> nil
      end

    course = socket.assigns.course

    enrolled =
      if current_user do
        Enrollments.user_enrolled?(current_user.id, course.id)
      else
        false
      end

    assign(socket, :enrolled?, enrolled)
  end

  defp load_lessons(socket) do
    course = socket.assigns.course
    lessons = Courses.list_course_lessons(course.id, only_published: true)

    socket
    |> assign(:lessons, lessons)
    |> assign(:total_duration, calculate_total_duration(lessons))
  end

  defp calculate_total_duration(lessons) do
    lessons
    |> Enum.map(& &1.duration)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.sum()
    |> seconds_to_minutes()
  end

  defp seconds_to_minutes(seconds), do: div(seconds, 60)

  defp price_free?(nil), do: true
  defp price_free?(%Money{amount: 0}), do: true
  defp price_free?(_), do: false

  defp format_price(nil), do: "Free"
  defp format_price(%Money{amount: 0}), do: "Free"
  defp format_price(price), do: Money.to_string(price)

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    "#{minutes} min"
  end
end
