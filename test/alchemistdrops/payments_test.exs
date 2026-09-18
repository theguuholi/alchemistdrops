defmodule Alchemistdrops.PaymentsTest do
  use Alchemistdrops.DataCase

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.PaymentsFixtures

  alias Alchemistdrops.Enrollments
  alias Alchemistdrops.Payments
  alias Alchemistdrops.Payments.MockHttpClient
  alias Alchemistdrops.Payments.Payment

  doctest Alchemistdrops.Payments

  describe "create_payment/1" do
    test "creates a payment with valid attrs" do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(1000, :USD)})

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(1000, :USD)
      }

      assert {:ok, %Payment{} = payment} = Payments.create_payment(attrs)
      assert payment.user_id == user.id
      assert payment.course_id == course.id
      assert payment.amount == Money.new(1000, :USD)
      assert payment.status == "pending"
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = Payments.create_payment(%{})
    end

    test "returns error changeset with no attrs (default parameter)" do
      assert {:error, %Ecto.Changeset{}} = Payments.create_payment()
    end

    test "validates amount must be positive" do
      user = user_fixture()
      course = course_fixture()

      attrs = %{
        user_id: user.id,
        course_id: course.id,
        amount: Money.new(0, :USD)
      }

      assert {:error, changeset} = Payments.create_payment(attrs)
      assert "must be greater than 0" in errors_on(changeset).amount
    end
  end

  describe "get_payment!/1" do
    test "returns the payment with given id" do
      payment = payment_fixture()
      assert Payments.get_payment!(payment.id).id == payment.id
    end

    test "raises if payment does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Payments.get_payment!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_payment_by_checkout_session/1" do
    test "returns the payment with given session id" do
      payment = payment_fixture()

      {:ok, updated} =
        Payments.update_payment(payment, %{stripe_checkout_session_id: "cs_test_123"})

      assert Payments.get_payment_by_checkout_session("cs_test_123").id == updated.id
    end

    test "returns nil if not found" do
      assert Payments.get_payment_by_checkout_session("cs_nonexistent") == nil
    end
  end

  describe "update_payment/2" do
    test "updates the payment with valid attrs" do
      payment = payment_fixture()

      assert {:ok, %Payment{} = updated} =
               Payments.update_payment(payment, %{status: "completed"})

      assert updated.status == "completed"
    end

    test "returns error with invalid status" do
      payment = payment_fixture()
      assert {:error, changeset} = Payments.update_payment(payment, %{status: "invalid"})
      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "change_payment/2" do
    test "returns a changeset" do
      payment = payment_fixture()
      assert %Ecto.Changeset{} = Payments.change_payment(payment)
    end
  end

  describe "create_checkout_session/4" do
    test "creates checkout session for paid course" do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(2999, :USD),
          stripe_price_id: "price_test_123"
        })

      success_url = "https://example.com/success"
      cancel_url = "https://example.com/cancel"

      # Set up mock response
      MockHttpClient.expect_response(%{
        status: 200,
        body: %{
          "id" => "cs_test_session123",
          "url" => "https://checkout.stripe.com/test",
          "payment_intent" => "pi_test_intent123"
        }
      })

      assert {:ok, result} =
               Payments.create_checkout_session(user, course, success_url, cancel_url)

      assert %{payment: %Payment{}, checkout_url: checkout_url} = result
      assert checkout_url == "https://checkout.stripe.com/test"

      # Verify the payment was created
      assert result.payment.user_id == user.id
      assert result.payment.course_id == course.id
      assert result.payment.status == "pending"
      assert result.payment.stripe_checkout_session_id == "cs_test_session123"

      # Verify the request was made correctly
      request = MockHttpClient.last_request()
      assert request[:method] == :post
      assert request[:url] =~ "/checkout/sessions"
      assert request[:body] =~ "price_test_123"
      # Email is URL-encoded in the body
      assert request[:body] =~ URI.encode_www_form(user.email)
    end

    test "sends mode=subscription when course has price_recurring" do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(4999, :USD),
          stripe_price_id: "price_sub_123",
          price_recurring: true
        })

      MockHttpClient.expect_response(%{
        status: 200,
        body: %{
          "id" => "cs_sub_session",
          "url" => "https://checkout.stripe.com/sub",
          "subscription" => "sub_123"
        }
      })

      assert {:ok, result} =
               Payments.create_checkout_session(
                 user,
                 course,
                 "https://example.com/success",
                 "https://example.com/cancel"
               )

      assert result.checkout_url == "https://checkout.stripe.com/sub"
      assert result.payment.stripe_checkout_session_id == "cs_sub_session"
      assert result.payment.stripe_payment_intent_id == "sub_123"

      request = MockHttpClient.last_request()
      assert request[:body] =~ "mode=subscription"
    end

    test "returns error for free course" do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(0, :USD)})

      assert {:error, :course_is_free} =
               Payments.create_checkout_session(user, course, "success", "cancel")
    end

    test "returns error on Stripe API failure" do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(1000, :USD), stripe_price_id: "price_123"})

      MockHttpClient.expect_response(%{
        status: 400,
        body: %{"error" => %{"message" => "Invalid request"}}
      })

      assert {:error, {:stripe_error, 400, _body}} =
               Payments.create_checkout_session(user, course, "success", "cancel")
    end

    test "returns error on network failure" do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(1000, :USD), stripe_price_id: "price_123"})

      MockHttpClient.expect_error(:timeout)

      assert {:error, {:request_failed, :timeout}} =
               Payments.create_checkout_session(user, course, "success", "cancel")
    end
  end

  describe "process_webhook_event/2" do
    test "checkout.session.completed enrolls user and completes payment" do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(1000, :USD)})
      payment = payment_fixture(%{user: user, course: course})

      {:ok, _payment} =
        Payments.update_payment(payment, %{stripe_checkout_session_id: "cs_test_webhook"})

      event_data = %{
        "id" => "cs_test_webhook",
        "payment_intent" => "pi_completed",
        "amount_total" => 1000,
        "currency" => "usd",
        "payment_status" => "paid"
      }

      assert {:ok, result} =
               Payments.process_webhook_event("checkout.session.completed", event_data)

      assert %{payment: updated_payment, enrollment: enrollment} = result
      assert updated_payment.status == "completed"
      assert updated_payment.stripe_payment_intent_id == "pi_completed"
      assert enrollment.user_id == user.id
      assert enrollment.course_id == course.id
      assert Enrollments.user_enrolled?(user.id, course.id)
    end

    test "checkout.session.completed with subscription id enrolls user and completes payment" do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(1000, :USD)})
      payment = payment_fixture(%{user: user, course: course})

      {:ok, _payment} =
        Payments.update_payment(payment, %{stripe_checkout_session_id: "cs_sub_webhook"})

      # Subscription checkout has "subscription" not "payment_intent"
      event_data = %{
        "id" => "cs_sub_webhook",
        "subscription" => "sub_completed_123",
        "amount_total" => 1000,
        "currency" => "usd",
        "payment_status" => "paid"
      }

      assert {:ok, result} =
               Payments.process_webhook_event("checkout.session.completed", event_data)

      assert %{payment: updated_payment, enrollment: enrollment} = result
      assert updated_payment.status == "completed"
      assert updated_payment.stripe_payment_intent_id == "sub_completed_123"
      assert enrollment.user_id == user.id
      assert enrollment.course_id == course.id
      assert Enrollments.user_enrolled?(user.id, course.id)
    end

    test "checkout.session.completed returns error if payment not found" do
      event_data = %{"id" => "cs_nonexistent"}

      assert {:error, :payment_not_found} =
               Payments.process_webhook_event("checkout.session.completed", event_data)
    end

    test "unknown event type returns :ignored" do
      assert {:ok, :ignored} = Payments.process_webhook_event("unknown.event", %{})
    end
  end

  describe "stripe_secret_key configuration" do
    test "raises when stripe secret key is not configured" do
      # Temporarily remove the secret_key from config
      original = Application.get_env(:alchemistdrops, :stripe)
      new_config = Keyword.delete(original || [], :secret_key)
      Application.put_env(:alchemistdrops, :stripe, new_config)

      try do
        user = user_fixture()
        course = course_fixture(%{price: Money.new(1000, :USD), stripe_price_id: "price_123"})

        assert_raise RuntimeError, "Stripe secret key not configured", fn ->
          Payments.create_checkout_session(user, course, "http://success", "http://cancel")
        end
      after
        # Restore original config
        Application.put_env(:alchemistdrops, :stripe, original)
      end
    end
  end

  describe "verify_webhook_signature/3" do
    @webhook_secret "whsec_test_mock"

    test "valid signature returns :ok" do
      payload = ~s({"test": "data"})
      signature = generate_webhook_signature(payload, @webhook_secret)

      assert :ok = Payments.verify_webhook_signature(payload, signature, @webhook_secret)
    end

    test "invalid signature returns error" do
      payload = ~s({"test": "data"})
      # Use current timestamp to avoid :timestamp_too_old error
      timestamp = System.system_time(:second)
      signature = "t=#{timestamp},v1=invalidsig"

      assert {:error, :invalid_signature} =
               Payments.verify_webhook_signature(payload, signature, @webhook_secret)
    end

    test "missing signature components returns error" do
      payload = ~s({"test": "data"})

      assert {:error, :invalid_signature_format} =
               Payments.verify_webhook_signature(payload, "invalid", @webhook_secret)
    end

    test "old timestamp returns error" do
      payload = ~s({"test": "data"})
      old_timestamp = System.system_time(:second) - 600
      signature = generate_webhook_signature(payload, @webhook_secret, old_timestamp)

      assert {:error, :timestamp_too_old} =
               Payments.verify_webhook_signature(payload, signature, @webhook_secret)
    end
  end

  describe "ensure_stripe_product_and_price_for_course/1" do
    test "returns error when Stripe product creation returns non-2xx" do
      MockHttpClient.expect_response(%{status: 400, body: %{"error" => "Bad request"}})

      assert {:error, {:stripe_error, 400, _}} =
               Payments.ensure_stripe_product_and_price_for_course(
                 name: "Course",
                 description: "Desc",
                 amount_cents: 1000,
                 currency: "usd",
                 stripe_product_id: nil,
                 stripe_price_id: nil
               )
    end

    test "returns error when Stripe price creation returns non-2xx" do
      # First request (product) is skipped because we pass existing product id
      # Only price creation is called
      MockHttpClient.expect_response(%{status: 500, body: %{"error" => "Server error"}})

      assert {:error, {:stripe_error, 500, _}} =
               Payments.ensure_stripe_product_and_price_for_course(
                 name: "Course",
                 description: "Desc",
                 amount_cents: 1000,
                 currency: "usd",
                 stripe_product_id: "prod_existing",
                 stripe_price_id: nil
               )
    end

    test "returns error when Stripe price creation fails with request_failed" do
      MockHttpClient.expect_error(:econnrefused)

      assert {:error, {:request_failed, :econnrefused}} =
               Payments.ensure_stripe_product_and_price_for_course(
                 name: "Course",
                 description: "Desc",
                 amount_cents: 1000,
                 currency: "usd",
                 stripe_product_id: "prod_existing",
                 stripe_price_id: nil
               )
    end
  end
end
