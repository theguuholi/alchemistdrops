defmodule Alchemistdrops.PaymentsFixtures do
  @moduledoc """
  This module defines test fixtures for the Payments context.
  """

  alias Alchemistdrops.AccountsFixtures
  alias Alchemistdrops.CoursesFixtures
  alias Alchemistdrops.Payments.Payment
  alias Alchemistdrops.Repo

  @doc """
  Generate a payment with default or custom attributes.
  """
  def payment_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || AccountsFixtures.user_fixture()
    course = Map.get(attrs, :course) || CoursesFixtures.course_fixture()

    attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:course_id, course.id)
      |> Enum.into(%{
        amount: Money.new(9999, :USD),
        status: "pending"
      })

    %Payment{}
    |> Payment.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate a completed payment.
  """
  def completed_payment_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:status, "completed")
      |> Map.put(:stripe_payment_intent_id, "pi_#{System.unique_integer([:positive])}")

    payment_fixture(attrs)
  end

  @doc """
  Generate a failed payment.
  """
  def failed_payment_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :status, "failed")
    payment_fixture(attrs)
  end

  @doc """
  Generate a refunded payment.
  """
  def refunded_payment_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:status, "refunded")
      |> Map.put(:stripe_payment_intent_id, "pi_#{System.unique_integer([:positive])}")

    payment_fixture(attrs)
  end
end
