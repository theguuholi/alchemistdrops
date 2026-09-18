defmodule Alchemistdrops.Payments do
  @moduledoc """
  Owns payment persistence and the Stripe checkout boundary.

  This context is important because checkout creation, webhook reconciliation,
  payment state, and enrollment creation must succeed or fail consistently. It
  also keeps external HTTP behavior injectable so tests never call Stripe.
  """

  import Ecto.Query, warn: false

  alias Alchemistdrops.Accounts.User
  alias Alchemistdrops.Courses.Course
  alias Alchemistdrops.Enrollments
  alias Alchemistdrops.Payments.Payment
  alias Alchemistdrops.Repo
  alias Money

  @stripe_api_base "https://api.stripe.com/v1"

  ## Payment CRUD

  @doc """
  Creates a payment record.

  ## Examples

      iex> user = Alchemistdrops.AccountsFixtures.user_fixture()
      iex> course = Alchemistdrops.CoursesFixtures.course_fixture()
      iex> {:ok, payment} = Alchemistdrops.Payments.create_payment(%{user_id: user.id, course_id: course.id, amount: Money.new(1000, :USD)})
      iex> {payment.user_id, payment.course_id, payment.status}
      {user.id, course.id, "pending"}

  """
  @spec create_payment() :: {:ok, Payment.t()} | {:error, Ecto.Changeset.t()}
  @spec create_payment(map()) :: {:ok, Payment.t()} | {:error, Ecto.Changeset.t()}
  def create_payment(attrs \\ %{}) do
    %Payment{}
    |> Payment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single payment.

  Raises `Ecto.NoResultsError` if the Payment does not exist.

  ## Examples

      iex> payment = Alchemistdrops.PaymentsFixtures.payment_fixture()
      iex> Alchemistdrops.Payments.get_payment!(payment.id).id == payment.id
      true

  """
  @spec get_payment!(Ecto.UUID.t()) :: Payment.t()
  def get_payment!(id), do: Repo.get!(Payment, id)

  @doc """
  Gets a payment by Stripe checkout session ID.

  Returns nil if not found.

  ## Examples

      iex> payment = Alchemistdrops.PaymentsFixtures.completed_payment_fixture()
      iex> found = Alchemistdrops.Payments.get_payment_by_checkout_session(payment.stripe_checkout_session_id)
      iex> found.id == payment.id
      true

  """
  @spec get_payment_by_checkout_session(String.t()) :: Payment.t() | nil
  def get_payment_by_checkout_session(session_id) do
    Repo.get_by(Payment, stripe_checkout_session_id: session_id)
  end

  @doc """
  Updates a payment.

  ## Examples

      iex> payment = Alchemistdrops.PaymentsFixtures.payment_fixture()
      iex> {:ok, updated} = Alchemistdrops.Payments.update_payment(payment, %{status: "completed"})
      iex> updated.status
      "completed"

  """
  @spec update_payment(Payment.t(), map()) ::
          {:ok, Payment.t()} | {:error, Ecto.Changeset.t()}
  def update_payment(%Payment{} = payment, attrs) do
    payment
    |> Payment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking payment changes.

  ## Examples

      iex> changeset = Alchemistdrops.Payments.change_payment(%Alchemistdrops.Payments.Payment{})
      iex> match?(%Ecto.Changeset{}, changeset)
      true

  """
  @spec change_payment(Payment.t()) :: Ecto.Changeset.t()
  @spec change_payment(Payment.t(), map()) :: Ecto.Changeset.t()
  def change_payment(%Payment{} = payment, attrs \\ %{}) do
    Payment.changeset(payment, attrs)
  end

  ## Stripe Integration

  @doc """
  Creates a Stripe checkout session for purchasing a course.

  Returns {:ok, %{payment: payment, checkout_url: url}} on success.
  Returns {:error, reason} on failure.

  ## Examples

      iex> user = Alchemistdrops.AccountsFixtures.user_fixture()
      iex> course = Alchemistdrops.CoursesFixtures.free_course_fixture()
      iex> Alchemistdrops.Payments.create_checkout_session(user, course, "https://example.com/success", "https://example.com/cancel")
      {:error, :course_is_free}

  """
  @spec create_checkout_session(User.t(), Course.t(), String.t(), String.t()) ::
          {:ok, %{payment: Payment.t(), checkout_url: String.t() | nil}}
          | {:error, :course_is_free | term()}
  def create_checkout_session(%User{} = user, %Course{} = course, success_url, cancel_url) do
    if price_zero_or_nil?(course.price) do
      {:error, :course_is_free}
    else
      do_create_checkout_session(user, course, success_url, cancel_url)
    end
  end

  defp do_create_checkout_session(user, course, success_url, cancel_url) do
    with {:ok, payment} <- create_pending_payment(user, course),
         {:ok, session} <- create_stripe_session(course, user, payment, success_url, cancel_url),
         {:ok, updated_payment} <- update_payment_with_session(payment, session) do
      {:ok, %{payment: updated_payment, checkout_url: session["url"]}}
    end
  end

  defp create_pending_payment(user, course) do
    create_payment(%{
      user_id: user.id,
      course_id: course.id,
      amount: course.price,
      status: "pending"
    })
  end

  defp create_stripe_session(course, user, payment, success_url, cancel_url) do
    mode = if Map.get(course, :price_recurring), do: "subscription", else: "payment"

    body =
      URI.encode_query(%{
        "mode" => mode,
        "success_url" => success_url,
        "cancel_url" => cancel_url,
        "client_reference_id" => payment.id,
        "customer_email" => user.email,
        "line_items[0][price]" => course.stripe_price_id,
        "line_items[0][quantity]" => "1",
        "metadata[payment_id]" => payment.id,
        "metadata[course_id]" => course.id,
        "metadata[user_id]" => user.id
      })

    case stripe_request(:post, "/checkout/sessions", body) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:stripe_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp update_payment_with_session(payment, session) do
    # One-time payments have payment_intent; subscriptions have subscription id
    intent_or_subscription = session["payment_intent"] || session["subscription"]

    update_payment(payment, %{
      stripe_checkout_session_id: session["id"],
      stripe_payment_intent_id: intent_or_subscription
    })
  end

  ## Webhook Processing

  @doc """
  Processes a Stripe webhook event.

  Handles the following events:
  - checkout.session.completed: Marks payment as completed and enrolls user

  ## Examples

      iex> Alchemistdrops.Payments.process_webhook_event("unknown.event", %{})
      {:ok, :ignored}

  """
  @spec process_webhook_event(String.t(), map()) ::
          {:ok,
           :ignored
           | %{payment: Payment.t(), enrollment: Alchemistdrops.Enrollments.Enrollment.t()}}
          | {:error, term()}
  def process_webhook_event("checkout.session.completed", %{"id" => session_id} = data) do
    case get_payment_by_checkout_session(session_id) do
      nil ->
        {:error, :payment_not_found}

      payment ->
        complete_payment_and_enroll(payment, data)
    end
  end

  def process_webhook_event(_event_type, _data), do: {:ok, :ignored}

  defp complete_payment_and_enroll(payment, session_data) do
    intent_or_subscription = session_data["payment_intent"] || session_data["subscription"]

    Repo.transaction(fn ->
      with {:ok, updated_payment} <-
             update_payment(payment, %{
               status: "completed",
               stripe_payment_intent_id: intent_or_subscription,
               metadata: %{
                 "amount_total" => session_data["amount_total"],
                 "currency" => session_data["currency"],
                 "payment_status" => session_data["payment_status"]
               }
             }),
           {:ok, enrollment} <- Enrollments.enroll_user(payment.user_id, payment.course_id) do
        %{payment: updated_payment, enrollment: enrollment}
      else
        {:error, changeset} -> Repo.rollback({:enrollment_failed, changeset})
      end
    end)
  end

  ## Webhook Signature Verification

  @doc """
  Verifies the Stripe webhook signature.

  Returns :ok if valid, {:error, reason} if invalid.

  ## Examples

      iex> payload = ~s({"type":"test"})
      iex> secret = "whsec_test"
      iex> signature = Alchemistdrops.PaymentsFixtures.generate_webhook_signature(payload, secret)
      iex> Alchemistdrops.Payments.verify_webhook_signature(payload, signature, secret)
      :ok

  """
  @spec verify_webhook_signature(binary(), String.t() | nil, binary()) ::
          :ok | {:error, :invalid_signature_format | :timestamp_too_old | :invalid_signature}
  def verify_webhook_signature(payload, signature_header, webhook_secret) do
    with {:ok, %{"t" => timestamp, "v1" => signature}} <-
           parse_signature_header(signature_header),
         :ok <- verify_timestamp(timestamp) do
      verify_signature(payload, timestamp, signature, webhook_secret)
    end
  end

  defp parse_signature_header(nil), do: {:error, :invalid_signature_format}

  defp parse_signature_header(header) when is_binary(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.filter(&(length(&1) == 2))
      |> Map.new(fn [k, v] -> {k, v} end)

    if Map.has_key?(parts, "t") and Map.has_key?(parts, "v1") do
      {:ok, parts}
    else
      {:error, :invalid_signature_format}
    end
  end

  defp verify_timestamp(timestamp) do
    timestamp_int = String.to_integer(timestamp)
    current_time = System.system_time(:second)
    # Allow 5 minute tolerance
    if abs(current_time - timestamp_int) <= 300 do
      :ok
    else
      {:error, :timestamp_too_old}
    end
  end

  defp verify_signature(payload, timestamp, signature, secret) do
    signed_payload = "#{timestamp}.#{payload}"

    expected =
      :hmac |> :crypto.mac(:sha256, secret, signed_payload) |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  ## Stripe Product & Price (for course association)

  @doc """
  Ensures a Stripe Product and Price exist for the given course attributes.

  When the course has a positive price and no `stripe_price_id`, creates a Stripe
  Product (and Price). When `stripe_price_id` is already set, returns existing IDs
  without calling the API. Free courses (zero price) are skipped.

  ## Options

  - `:name` - Product name (e.g. course title)
  - `:description` - Product description (optional)
  - `:amount_cents` - Price in smallest currency unit (e.g. cents)
  - `:currency` - ISO currency code string (e.g. "usd"), defaults to "usd"
  - `:stripe_product_id` - Existing Stripe Product ID (skip product creation if set)
  - `:stripe_price_id` - Existing Stripe Price ID (skip creation if set)

  ## Returns

  - `{:ok, %{stripe_product_id: "...", stripe_price_id: "..."}}` when created or already set
  - `{:ok, %{}}` when price is zero (no Stripe needed)
  - `{:error, reason}` on Stripe API failure

  ## Examples

      iex> Alchemistdrops.Payments.ensure_stripe_product_and_price_for_course(name: "Free", amount_cents: 0)
      {:ok, %{}}
  """
  @spec ensure_stripe_product_and_price_for_course(keyword()) ::
          {:ok, %{}}
          | {:ok, %{stripe_product_id: String.t() | nil, stripe_price_id: String.t() | nil}}
          | {:error, {:request_failed, term()} | {:stripe_error, integer(), term()}}
  def ensure_stripe_product_and_price_for_course(opts) do
    amount = Keyword.get(opts, :amount_cents)
    currency = (Keyword.get(opts, :currency) || "usd") |> String.downcase()
    existing_product_id = Keyword.get(opts, :stripe_product_id)
    existing_price_id = Keyword.get(opts, :stripe_price_id)

    cond do
      is_nil(amount) or amount == 0 ->
        {:ok, %{}}

      existing_price_id != nil and existing_price_id != "" ->
        {:ok,
         %{
           stripe_product_id: existing_product_id,
           stripe_price_id: existing_price_id
         }}

      true ->
        do_create_stripe_product_and_price(
          name: Keyword.fetch!(opts, :name),
          description: Keyword.get(opts, :description) || "",
          amount_cents: amount,
          currency: currency,
          existing_product_id: existing_product_id
        )
    end
  end

  defp do_create_stripe_product_and_price(
         name: name,
         description: description,
         amount_cents: amount_cents,
         currency: currency,
         existing_product_id: existing_product_id
       ) do
    with {:ok, product_id} <- ensure_stripe_product(name, description, existing_product_id),
         {:ok, price_id} <- create_stripe_price(product_id, amount_cents, currency) do
      {:ok, %{stripe_product_id: product_id, stripe_price_id: price_id}}
    end
  end

  defp ensure_stripe_product(name, description, nil), do: create_stripe_product(name, description)
  defp ensure_stripe_product(_name, _description, existing_id), do: {:ok, existing_id}

  defp create_stripe_product(name, description) do
    body =
      URI.encode_query(%{
        "name" => name,
        "description" => String.slice(description, 0, 500)
      })

    case stripe_request(:post, "/products", body) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body["id"]}

      {:ok, %{status: status, body: body}} ->
        {:error, {:stripe_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp create_stripe_price(product_id, unit_amount, currency) do
    body =
      URI.encode_query(%{
        "product" => product_id,
        "unit_amount" => to_string(unit_amount),
        "currency" => currency
      })

    case stripe_request(:post, "/prices", body) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body["id"]}

      {:ok, %{status: status, body: body}} ->
        {:error, {:stripe_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  ## HTTP Client (using Req as per workspace guidelines)

  defp stripe_request(method, path, body) do
    url = @stripe_api_base <> path

    headers = [
      {"authorization", "Bearer #{stripe_secret_key()}"},
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    request_opts = [
      method: method,
      url: url,
      headers: headers,
      body: body
    ]

    http_client().request(request_opts)
  end

  defp stripe_secret_key do
    Application.get_env(:alchemistdrops, :stripe)[:secret_key] ||
      raise "Stripe secret key not configured"
  end

  # Allow injecting HTTP client for testing
  defp http_client do
    Application.get_env(:alchemistdrops, :stripe)[:http_client] ||
      Alchemistdrops.Payments.ReqClient
  end

  defp price_zero_or_nil?(nil), do: true
  defp price_zero_or_nil?(%Money{amount: 0}), do: true
  defp price_zero_or_nil?(_), do: false
end
