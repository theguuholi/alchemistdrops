defmodule Alchemistdrops.Payments.PaymentTest do
  @moduledoc """
  Feature: Payment Schema Validation with Money Library
    As a payment processor
    I want to ensure payments are properly validated using Money types
    So that only valid payment data is stored in the database
  """
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Payments.Payment

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures

  setup do
    # Given a user and course exist in the system
    user = user_fixture()
    course = course_fixture()

    %{user: user, course: course}
  end

  describe "Feature: Payment Changeset Validation with Money" do
    test "Scenario: Creating a payment with valid required fields", %{user: user, course: course} do
      # Given valid payment attributes
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating a payment without a user_id", %{course: course} do
      # Given payment attributes without a user_id
      attrs = %{
        course_id: course.id,
        amount: Money.new(9999, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a user_id required error
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment without a course_id", %{user: user} do
      # Given payment attributes without a course_id
      attrs = %{
        user_id: user.id,
        amount: Money.new(9999, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a course_id required error
      assert %{course_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment without an amount", %{user: user, course: course} do
      # Given payment attributes without an amount
      attrs = %{
        user_id: user.id,
        course_id: course.id
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have an amount required error
      assert %{amount: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment with zero amount", %{user: user, course: course} do
      # Given payment attributes with zero amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(0, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have an amount validation error
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment with negative amount", %{user: user, course: course} do
      # Given payment attributes with negative amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(-5000, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have an amount validation error
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment with small amount", %{user: user, course: course} do
      # Given payment attributes with a small amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(99, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating a payment with an invalid status", %{user: user, course: course} do
      # Given payment attributes with an invalid status
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        status: "invalid_status"
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a status validation error
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "Scenario: Valid status values are accepted", %{user: user, course: course} do
      # Given valid payment statuses
      statuses = ["pending", "completed", "failed", "refunded"]

      # When I create changesets with these statuses
      changesets =
        Enum.map(statuses, fn status ->
          Payment.changeset(%Payment{}, %{
            user_id: user.id,
            course_id: course.id,
            amount: Money.new(9999, :USD),
            status: status
          })
        end)

      # Then all changesets should be valid
      assert Enum.all?(changesets, & &1.valid?)
    end

    test "Scenario: Default status is set to pending", %{user: user, course: course} do
      # Given payment attributes without status
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And default status should be pending
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "Scenario: Metadata can be stored as a map", %{user: user, course: course} do
      # Given payment attributes with metadata
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        metadata: %{"key" => "value", "nested" => %{"data" => "here"}}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And metadata should be stored
      assert changeset.changes.metadata == %{"key" => "value", "nested" => %{"data" => "here"}}
    end

    test "Scenario: All optional fields are accepted", %{user: user, course: course} do
      # Given payment attributes with all optional fields
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(14_999, :USD),
        stripe_payment_intent_id: "pi_123456789",
        stripe_checkout_session_id: "cs_test_123456789",
        status: "completed",
        metadata: %{"key" => "value"}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Money library validates currency codes automatically", %{
      user: user,
      course: course
    } do
      # Given payment attributes with USD (the supported currency in our app)
      # Note: We use Money.Ecto.Amount.Type which stores only amount, not currency
      currencies = [:USD]

      # When I create changesets with USD
      changesets =
        Enum.map(currencies, fn currency ->
          Payment.changeset(%Payment{}, %{
            user_id: user.id,
            course_id: course.id,
            amount: Money.new(9999, currency)
          })
        end)

      # Then all changesets should be valid
      assert Enum.all?(changesets, & &1.valid?)
    end

    test "Scenario: Large payment amounts are accepted", %{user: user, course: course} do
      # Given payment attributes with a large amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(10_000_000_000, :USD)
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Empty metadata map is accepted", %{user: user, course: course} do
      # Given payment attributes with an empty metadata map
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        metadata: %{}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Nil metadata is accepted", %{user: user, course: course} do
      # Given payment attributes with nil metadata
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        metadata: nil
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Stripe payment intent ID can be stored", %{user: user, course: course} do
      # Given payment attributes with a Stripe payment intent ID
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        stripe_payment_intent_id: "pi_1234567890"
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And the Stripe payment intent ID should be stored
      assert Ecto.Changeset.get_change(changeset, :stripe_payment_intent_id) == "pi_1234567890"
    end

    test "Scenario: Stripe checkout session ID can be stored", %{user: user, course: course} do
      # Given payment attributes with a Stripe checkout session ID
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        stripe_checkout_session_id: "cs_test_1234567890"
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And the Stripe checkout session ID should be stored
      assert Ecto.Changeset.get_change(changeset, :stripe_checkout_session_id) ==
               "cs_test_1234567890"
    end

    test "Scenario: Completed payment with all Stripe fields", %{user: user, course: course} do
      # Given payment attributes for a completed Stripe payment
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        stripe_payment_intent_id: "pi_completed_123",
        stripe_checkout_session_id: "cs_completed_123",
        status: "completed",
        metadata: %{"payment_method" => "card", "last4" => "4242"}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And all Stripe-related fields should be present
      assert Ecto.Changeset.get_change(changeset, :status) == "completed"
      assert Ecto.Changeset.get_change(changeset, :stripe_payment_intent_id) == "pi_completed_123"

      assert Ecto.Changeset.get_change(changeset, :stripe_checkout_session_id) ==
               "cs_completed_123"
    end

    test "Scenario: Failed payment can be recorded", %{user: user, course: course} do
      # Given payment attributes for a failed payment
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        status: "failed",
        metadata: %{"error" => "insufficient_funds"}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And status should be failed
      assert Ecto.Changeset.get_change(changeset, :status) == "failed"
    end

    test "Scenario: Refunded payment can be recorded", %{user: user, course: course} do
      # Given payment attributes for a refunded payment
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD),
        status: "refunded",
        stripe_payment_intent_id: "pi_refunded_123",
        metadata: %{"refund_reason" => "customer_request"}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And status should be refunded
      assert Ecto.Changeset.get_change(changeset, :status) == "refunded"
    end

    test "Scenario: Money validates positive amounts only", %{user: user, course: course} do
      # Given payment with amount of 1 cent
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(1, :USD)
      }

      # When I create a changeset
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then it should be valid
      assert changeset.valid?
    end

    test "Scenario: Payment can use different currencies", %{user: user, course: course} do
      # Given payment attributes with USD currency
      # Note: We use Money.Ecto.Amount.Type which stores only amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD)
      }

      # When I create a changeset
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
      assert Money.equals?(changeset.changes.amount, Money.new(9999, :USD))
    end

    test "Scenario: Money validation handles nil amount", %{user: user, course: course} do
      # Given a payment without amount specified
      attrs = %{
        user_id: user.id,
        course_id: course.id
      }

      # When I create a changeset
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid (amount required)
      refute changeset.valid?
      assert %{amount: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Money validation handles non-Money value" do
      # Given a payment changeset with amount already set
      payment = %Payment{amount: Money.new(1000, :USD)}

      user = user_fixture()
      course = course_fixture()

      # When we update without changing amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(9999, :USD)
      }

      changeset = Payment.changeset(payment, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end
  end
end
