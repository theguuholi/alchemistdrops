defmodule Alchemistdrops.Payments.PaymentTest do
  @moduledoc """
  Feature: Payment Schema Validation
    As a payment processor
    I want to ensure payments are properly validated
    So that only valid payment data is stored in the database
  """
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Accounts.User
  alias Alchemistdrops.Courses.Course
  alias Alchemistdrops.Payments.Payment

  setup do
    # Given a user exists in the system
    user =
      %User{}
      |> User.email_changeset(%{email: "test@example.com", role: :user})
      |> User.password_changeset(%{password: "TestPassword123!"}, hash_password: false)
      |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt("TestPassword123!"))
      |> Repo.insert!()

    # And a course exists in the system
    course =
      %Course{}
      |> Course.changeset(%{
        title: "Test Course",
        description: "Test Description",
        price: Decimal.new("99.99")
      })
      |> Repo.insert!()

    %{user: user, course: course}
  end

  describe "Feature: Payment Changeset Validation" do
    test "Scenario: Creating a payment with valid required fields", %{user: user, course: course} do
      # Given valid payment attributes with user_id, course_id, and amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99")
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
        amount: Decimal.new("99.99")
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
        amount: Decimal.new("99.99")
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
        amount: Decimal.new("0")
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have an amount validation error
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment with negative amount", %{user: user, course: course} do
      # Given payment attributes with a negative amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("-10.00")
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have an amount validation error
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment with small decimal amount", %{user: user, course: course} do
      # Given payment attributes with a small decimal amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("0.01")
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
        amount: Decimal.new("99.99"),
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
      # Given a list of valid status values
      valid_statuses = ["pending", "completed", "failed", "refunded"]

      # When I create changesets with each status
      for status <- valid_statuses do
        attrs = %{
          user_id: user.id,
          course_id: course.id,
          amount: Decimal.new("99.99"),
          status: status
        }

        changeset = Payment.changeset(%Payment{}, attrs)

        # Then each changeset should be valid
        assert changeset.valid?, "Expected #{status} to be valid"
      end
    end

    test "Scenario: Default status is set to pending", %{user: user, course: course} do
      # Given payment attributes without status
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99")
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then default status should be pending
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "Scenario: Default currency is set to USD", %{user: user, course: course} do
      # Given payment attributes without currency
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99")
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then default currency should be USD
      assert Ecto.Changeset.get_field(changeset, :currency) == "USD"
    end

    test "Scenario: Metadata can be stored as a map", %{user: user, course: course} do
      # Given payment attributes with metadata
      metadata = %{
        "customer_name" => "John Doe",
        "customer_email" => "john@example.com",
        "notes" => "Special request"
      }

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99"),
        metadata: metadata
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And metadata should be stored correctly
      assert Ecto.Changeset.get_change(changeset, :metadata) == metadata
    end

    test "Scenario: All optional fields are accepted", %{user: user, course: course} do
      # Given payment attributes with all optional fields populated
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("149.99"),
        currency: "EUR",
        stripe_payment_intent_id: "pi_123456789",
        stripe_checkout_session_id: "cs_test_123456789",
        status: "completed",
        metadata: %{"key" => "value"}
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And all fields should be set correctly
      assert Ecto.Changeset.get_change(changeset, :currency) == "EUR"
      assert Ecto.Changeset.get_change(changeset, :stripe_payment_intent_id) == "pi_123456789"

      assert Ecto.Changeset.get_change(changeset, :stripe_checkout_session_id) ==
               "cs_test_123456789"

      assert Ecto.Changeset.get_change(changeset, :status) == "completed"
      assert Ecto.Changeset.get_change(changeset, :metadata) == %{"key" => "value"}
    end

    test "Scenario: Creating a payment with an invalid currency format", %{
      user: user,
      course: course
    } do
      # Given payment attributes with an invalid currency code
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99"),
        currency: "INVALID"
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a currency format error
      assert %{currency: ["must be a 3-letter currency code"]} = errors_on(changeset)
    end

    test "Scenario: Creating a payment with lowercase currency code", %{
      user: user,
      course: course
    } do
      # Given payment attributes with lowercase currency code
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99"),
        currency: "usd"
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a currency format error
      assert %{currency: ["must be a 3-letter currency code"]} = errors_on(changeset)
    end

    test "Scenario: Valid currency codes are accepted", %{user: user, course: course} do
      # Given a list of valid currency codes
      valid_currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY"]

      # When I create changesets with each currency
      for currency <- valid_currencies do
        attrs = %{
          user_id: user.id,
          course_id: course.id,
          amount: Decimal.new("99.99"),
          currency: currency
        }

        changeset = Payment.changeset(%Payment{}, attrs)

        # Then each changeset should be valid
        assert changeset.valid?, "Expected #{currency} to be valid"
      end
    end

    test "Scenario: Large payment amounts are accepted", %{user: user, course: course} do
      # Given payment attributes with a large amount
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99999.99")
      }

      # When I create a changeset with these attributes
      changeset = Payment.changeset(%Payment{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Empty metadata map is accepted", %{user: user, course: course} do
      # Given payment attributes with empty metadata
      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Decimal.new("99.99"),
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
        amount: Decimal.new("99.99"),
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
        amount: Decimal.new("99.99"),
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
        amount: Decimal.new("99.99"),
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
        amount: Decimal.new("99.99"),
        currency: "USD",
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
        amount: Decimal.new("99.99"),
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
        amount: Decimal.new("99.99"),
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
  end
end
