defmodule Alchemistdrops.PaymentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Alchemistdrops.Payments` context.
  """

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures

  @doc """
  Generate a payment.
  """
  def payment_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    course = attrs[:course] || course_fixture(%{price: Money.new(1000, :USD)})

    {:ok, payment} =
      %{
        amount: course.price,
        status: "pending"
      }
      |> Map.merge(Map.new(attrs))
      |> Map.put(:user_id, user.id)
      |> Map.put(:course_id, course.id)
      |> Alchemistdrops.Payments.create_payment()

    payment
  end

  @doc """
  Generate a completed payment.
  """
  def completed_payment_fixture(attrs \\ %{}) do
    payment = payment_fixture(attrs)

    {:ok, payment} =
      Alchemistdrops.Payments.update_payment(payment, %{
        status: "completed",
        stripe_checkout_session_id: "cs_test_#{Ecto.UUID.generate()}",
        stripe_payment_intent_id: "pi_test_#{Ecto.UUID.generate()}"
      })

    payment
  end

  @doc """
  Generate a valid Stripe webhook signature.
  """
  def generate_webhook_signature(payload, secret, timestamp \\ nil) do
    timestamp = timestamp || System.system_time(:second)
    signed_payload = "#{timestamp}.#{payload}"

    signature =
      :hmac |> :crypto.mac(:sha256, secret, signed_payload) |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end

  @doc """
  Generate a mock checkout.session.completed event payload.
  """
  def checkout_completed_event(payment) do
    Jason.encode!(%{
      "type" => "checkout.session.completed",
      "data" => %{
        "object" => %{
          "id" => payment.stripe_checkout_session_id || "cs_test_mock",
          "payment_intent" => "pi_test_completed",
          "amount_total" => 1000,
          "currency" => "usd",
          "payment_status" => "paid"
        }
      }
    })
  end
end
