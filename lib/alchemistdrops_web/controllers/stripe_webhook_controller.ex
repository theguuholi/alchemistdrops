defmodule AlchemistdropsWeb.StripeWebhookController do
  @moduledoc """
  Controller for handling Stripe webhook events.

  Verifies webhook signatures and processes payment events.
  """

  use AlchemistdropsWeb, :controller

  alias Alchemistdrops.Payments

  @doc """
  Handles incoming Stripe webhook events.

  Verifies the webhook signature before processing the event.
  """
  def webhook(conn, _params) do
    payload = conn.assigns[:raw_body]
    signature = get_req_header(conn, "stripe-signature") |> List.first()
    webhook_secret = webhook_secret()

    with :ok <- Payments.verify_webhook_signature(payload, signature, webhook_secret),
         {:ok, event} <- Jason.decode(payload),
         {:ok, _result} <- process_event(event) do
      json(conn, %{received: true})
    else
      {:error, :invalid_signature} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid signature"})

      {:error, :invalid_signature_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid signature format"})

      {:error, :timestamp_too_old} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Timestamp too old"})

      {:error, :payment_not_found} ->
        # Log but don't fail - could be a duplicate or test event
        json(conn, %{received: true, warning: "Payment not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  defp process_event(%{"type" => event_type, "data" => %{"object" => object}}) do
    Payments.process_webhook_event(event_type, object)
  end

  defp process_event(_), do: {:ok, :ignored}

  defp webhook_secret do
    Application.get_env(:alchemistdrops, :stripe)[:webhook_secret] ||
      raise "Stripe webhook secret not configured"
  end
end
