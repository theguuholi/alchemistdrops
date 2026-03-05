# Stripe Setup Guide

This guide will walk you through setting up Stripe payment integration for the Alchemistdrops Phoenix application.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Stripe Account Setup](#stripe-account-setup)
3. [Get Your API Keys](#get-your-api-keys)
4. [Configure Environment Variables](#configure-environment-variables)
5. [Create Products and Prices in Stripe](#create-products-and-prices-in-stripe)
6. [Configure Webhooks](#configure-webhooks)
7. [Update Course Records](#update-course-records)
8. [Test the Integration](#test-the-integration)
9. [Production Deployment](#production-deployment)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- A Stripe account (sign up at [https://stripe.com](https://stripe.com))
- Access to your application's environment variables
- Admin access to your Phoenix application
- Basic understanding of Stripe Dashboard

---

## Step 1: Stripe Account Setup

1. **Sign up for a Stripe account** (if you don't have one)
   - Go to [https://stripe.com](https://stripe.com)
   - Click "Start now" or "Sign in"
   - Complete the account setup process

2. **Activate your account**
   - Complete business information
   - Add bank account details (for receiving payments)
   - Verify your email address

3. **Switch to Test Mode** (for development)
   - In the Stripe Dashboard, toggle the "Test mode" switch in the top right
   - This allows you to test payments without processing real transactions

---

## Step 2: Get Your API Keys

1. **Navigate to API Keys**
   - In Stripe Dashboard, go to **Developers** → **API keys**
   - Or visit: [https://dashboard.stripe.com/test/apikeys](https://dashboard.stripe.com/test/apikeys) (test mode)
   - Or visit: [https://dashboard.stripe.com/apikeys](https://dashboard.stripe.com/apikeys) (live mode)

2. **Copy your Secret Key**
   - Find the **Secret key** (starts with `sk_test_` for test mode or `sk_live_` for production)
   - Click "Reveal test key" or "Reveal live key" to see the full key
   - Copy this key - you'll need it in the next step
   - ⚠️ **Never commit this key to version control**

3. **Note your Publishable Key** (optional, if you need client-side Stripe integration later)
   - The Publishable key (starts with `pk_test_` or `pk_live_`) is safe to expose in frontend code
   - Currently, this application uses server-side integration only

---

## Step 3: Configure Environment Variables

### For Development

1. **Create or update `.env` file** (if you're using one)
   ```bash
   STRIPE_SECRET_KEY=sk_test_your_test_secret_key_here
   STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
   ```

2. **Or export environment variables directly**
   ```bash
   export STRIPE_SECRET_KEY=sk_test_your_test_secret_key_here
   export STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
   ```

3. **For development with `mix phx.server`**
   - Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.) or use a `.env` file
   - The application reads these from `config/runtime.exs`

### For Production

The application is already configured to read these from environment variables in `config/runtime.exs`:

```elixir
config :alchemistdrops, :stripe,
  secret_key:
    System.get_env("STRIPE_SECRET_KEY") ||
      raise("environment variable STRIPE_SECRET_KEY is missing"),
  webhook_secret:
    System.get_env("STRIPE_WEBHOOK_SECRET") ||
      raise("environment variable STRIPE_WEBHOOK_SECRET is missing"),
```

**Set these in your production environment:**
- Heroku: `heroku config:set STRIPE_SECRET_KEY=sk_live_...`
- Docker: Add to your `docker-compose.yml` or `.env` file
- Systemd/System services: Add to your service file's `Environment` section
- Platform-specific: Use your hosting provider's environment variable configuration

---

## Step 4: Create Products and Prices in Stripe

For each course in your application, you need to create a corresponding Product and Price in Stripe.

### Option A: Using Stripe Dashboard (Recommended for Manual Setup)

1. **Create a Product**
   - Go to **Products** → **Add product** in Stripe Dashboard
   - Enter product name (e.g., "Introduction to Elixir")
   - Add description (optional)
   - Click **Save product**

2. **Create a Price**
   - In the product page, click **Add price**
   - Set pricing:
     - **Price**: Enter the amount (e.g., `100.00` for $100.00)
     - **Billing period**: One time
     - **Currency**: Select your currency (e.g., USD)
   - Click **Save price**

3. **Copy the Price ID**
   - After creating the price, you'll see a **Price ID** (starts with `price_`)
   - Copy this ID - you'll need it to link to your course

### Option B: Using Stripe API (Recommended for Bulk Setup)

You can create products and prices programmatically using the Stripe API or Stripe CLI:

```bash
# Install Stripe CLI (if not already installed)
# macOS: brew install stripe/stripe-cli/stripe
# Or download from: https://stripe.com/docs/stripe-cli

# Login to Stripe
stripe login

# Create a product and price
stripe products create \
  --name="Introduction to Elixir" \
  --description="Learn the basics of Elixir programming"

# Create a price for the product (replace prod_xxx with your product ID)
stripe prices create \
  --product=prod_xxx \
  --unit-amount=10000 \
  --currency=usd
```

**Note:** Prices in Stripe are stored in the smallest currency unit (cents). So $100.00 = 10000 cents.

---

## Step 5: Update Course Records

After creating products and prices in Stripe, you need to link them to your courses in the database.

### Using IEx (Interactive Elixir)

1. **Start your Phoenix application**
   ```bash
   mix phx.server
   ```

2. **Open IEx console in another terminal**
   ```bash
   iex -S mix
   ```

3. **Update a course with Stripe IDs**
   ```elixir
   alias Alchemistdrops.Courses
   alias Alchemistdrops.Repo
   import Ecto.Query

   # Find your course
   course = Courses.get_course!(course_id)

   # Update with Stripe IDs
   Courses.update_course(course, %{
     stripe_product_id: "prod_xxxxxxxxxxxxx",  # Replace with your Stripe Product ID
     stripe_price_id: "price_xxxxxxxxxxxxx"     # Replace with your Stripe Price ID
   })
   ```

### Using Admin Interface (recommended)

1. Log in as an admin and open **Admin → Courses** in the header.
2. Create a new course or edit an existing one.
3. Set **Price (cents)** (e.g. `9900` for $99.00). Use `0` for free courses.
4. Save the course.

**Automatic Stripe association:** When you save a course with a **positive price** and leave the Stripe IDs blank, the app will create a Stripe Product and Price for you and store the IDs on the course. You do not need to create them in the Stripe Dashboard.

**Optional – manual Stripe IDs:** If you prefer to create the product/price in the [Stripe Dashboard](https://dashboard.stripe.com/products) first, paste the **Stripe Product ID** and **Stripe Price ID** in the form’s “Stripe (for paid courses)” section. If both are set, the app will not create new ones.

For paid courses, checkout only works when a **Stripe Price ID** is set (either auto-created or manual). Free courses (price 0) do not need Stripe IDs.

### Using Database Seeds

You can also update your `priv/repo/seeds.exs` file to include Stripe IDs when creating courses:

```elixir
# In priv/repo/seeds.exs
Courses.create_course(%{
  title: "Introduction to Elixir",
  description: "Learn the basics",
  price: Money.new(10000, :USD),  # $100.00
  stripe_product_id: "prod_xxxxxxxxxxxxx",
  stripe_price_id: "price_xxxxxxxxxxxxx",
  published: true
})
```

Then run:
```bash
mix run priv/repo/seeds.exs
```

---

## Step 6: Configure Webhooks

Webhooks allow Stripe to notify your application when payment events occur (e.g., when a payment is completed).

### For Local Development

1. **Install Stripe CLI** (if not already installed)
   ```bash
   # macOS
   brew install stripe/stripe-cli/stripe
   
   # Or download from: https://stripe.com/docs/stripe-cli
   ```

2. **Login to Stripe CLI**
   ```bash
   stripe login
   ```

3. **Forward webhooks to your local server**
   ```bash
   stripe listen --forward-to localhost:4000/webhooks/stripe
   ```
   
   This will:
   - Display a webhook signing secret (starts with `whsec_`)
   - Forward all Stripe events to your local server
   - Keep running until you stop it (Ctrl+C)

4. **Copy the webhook signing secret**
   - The CLI will output: `Ready! Your webhook signing secret is whsec_...`
   - Use this as your `STRIPE_WEBHOOK_SECRET` environment variable

5. **Trigger test events** (optional)
   ```bash
   # In another terminal, trigger a test event
   stripe trigger checkout.session.completed
   ```

### For Production

1. **Go to Stripe Dashboard**
   - Navigate to **Developers** → **Webhooks**
   - Or visit: [https://dashboard.stripe.com/webhooks](https://dashboard.stripe.com/webhooks)

2. **Add endpoint**
   - Click **Add endpoint**
   - Enter your webhook URL: `https://yourdomain.com/webhooks/stripe`
   - Select events to listen to:
     - `checkout.session.completed` (required for this application)

3. **Get webhook signing secret**
   - After creating the endpoint, click on it
   - In the **Signing secret** section, click **Reveal**
   - Copy the secret (starts with `whsec_`)
   - Use this as your `STRIPE_WEBHOOK_SECRET` environment variable

4. **Test the webhook**
   - In the webhook endpoint page, click **Send test webhook**
   - Select `checkout.session.completed` event
   - Verify your application receives and processes it correctly

---

## Step 7: Test the Integration

### Test Payment Flow

1. **Start your application**
   ```bash
   mix phx.server
   ```

2. **Start Stripe webhook forwarding** (in another terminal)
   ```bash
   stripe listen --forward-to localhost:4000/webhooks/stripe
   ```

3. **Navigate to a course page**
   - Go to `http://localhost:4000/courses/:id`
   - Ensure the course has a `stripe_price_id` set

4. **Initiate a purchase**
   - Click the purchase button (if available)
   - You'll be redirected to Stripe Checkout

5. **Complete test payment**
   - Use Stripe test card: `4242 4242 4242 4242`
   - Use any future expiry date (e.g., `12/34`)
   - Use any 3-digit CVC (e.g., `123`)
   - Use any ZIP code (e.g., `12345`)
   - Complete the checkout

6. **Verify the result**
   - You should be redirected back to your success URL
   - Check your application logs for webhook processing
   - Verify the payment was marked as completed in your database
   - Verify the user was enrolled in the course

### Run Test Suite

The application includes comprehensive tests for Stripe integration:

```bash
# Run all payment tests
mix test test/alchemistdrops/payments_test.exs

# Run webhook controller tests
mix test test/alchemistdrops_web/controllers/stripe_webhook_controller_test.exs

# Run all tests
mix test
```

---

## Step 8: Production Deployment

### Switch to Live Mode

1. **Get Live API Keys**
   - In Stripe Dashboard, toggle off "Test mode"
   - Go to **Developers** → **API keys**
   - Copy your **Live Secret Key** (starts with `sk_live_`)

2. **Update Environment Variables**
   ```bash
   # Set production environment variables
   export STRIPE_SECRET_KEY=sk_live_your_live_secret_key
   export STRIPE_WEBHOOK_SECRET=whsec_your_live_webhook_secret
   ```

3. **Update Course Stripe IDs**
   - Create products and prices in **Live mode** in Stripe Dashboard
   - Update your course records with the live `stripe_product_id` and `stripe_price_id`
   - ⚠️ **Test mode and Live mode have different product/price IDs**

4. **Configure Production Webhook**
   - Create a webhook endpoint in **Live mode**
   - Point it to your production URL: `https://yourdomain.com/webhooks/stripe`
   - Copy the live webhook signing secret

5. **Verify SSL/HTTPS**
   - Stripe requires HTTPS for webhooks in production
   - Ensure your production server has valid SSL certificates
   - The application should handle HTTPS properly (configured in `config/prod.exs`)

### Security Checklist

- [ ] Never commit API keys to version control
- [ ] Use environment variables for all secrets
- [ ] Enable HTTPS in production
- [ ] Verify webhook signatures (already implemented)
- [ ] Use different keys for test and production
- [ ] Regularly rotate API keys
- [ ] Monitor webhook events in Stripe Dashboard
- [ ] Set up alerts for failed payments

---

## Step 9: Troubleshooting

### Common Issues

#### Issue: "Stripe secret key not configured"

**Solution:**
- Verify `STRIPE_SECRET_KEY` environment variable is set
- Check that it's exported in your current shell session
- Restart your Phoenix server after setting the variable

#### Issue: "Stripe webhook secret not configured"

**Solution:**
- Verify `STRIPE_WEBHOOK_SECRET` environment variable is set
- For local development, use the secret from `stripe listen` command
- For production, use the secret from Stripe Dashboard webhook endpoint

#### Issue: Webhook signature verification fails

**Solution:**
- Ensure you're using the correct webhook secret for your environment (test vs live)
- Verify the `RawBody` plug is working correctly
- Check that the webhook payload hasn't been modified
- Ensure timestamps are within the 5-minute tolerance window

#### Issue: Payment created but not completed

**Solution:**
- Check webhook endpoint is accessible from the internet (for production)
- Verify webhook events are being sent (check Stripe Dashboard → Webhooks → Events)
- Check application logs for webhook processing errors
- Ensure the course has a valid `stripe_price_id`

#### Issue: "Course is free" error when creating checkout

**Solution:**
- Verify the course has a non-zero price
- Check that `course.price` is set correctly in the database
- Ensure the price is a `Money` struct, not a plain number

#### Issue: Stripe API errors (400, 401, etc.)

**Solution:**
- Verify your API key is correct and active
- Check that the `stripe_price_id` exists in Stripe
- Ensure you're using test keys in test mode and live keys in live mode
- Check Stripe Dashboard for API error details

### Debugging Tips

1. **Check Application Logs**
   ```bash
   # In development, logs appear in the terminal
   # Look for Stripe-related errors or webhook processing messages
   ```

2. **Check Stripe Dashboard**
   - **Events**: View all API requests and webhook events
   - **Logs**: See detailed request/response information
   - **Webhooks**: Check webhook delivery status

3. **Test Webhook Locally**
   ```bash
   # Use Stripe CLI to forward webhooks
   stripe listen --forward-to localhost:4000/webhooks/stripe
   
   # Trigger test events
   stripe trigger checkout.session.completed
   ```

4. **Verify Database State**
   ```elixir
   # In IEx console
   alias Alchemistdrops.Payments
   alias Alchemistdrops.Repo
   import Ecto.Query
   
   # Check recent payments
   Payments.list_payments() |> Repo.all()
   
   # Check a specific payment
   payment = Payments.get_payment!(payment_id)
   ```

---

## Additional Resources

- [Stripe API Documentation](https://stripe.com/docs/api)
- [Stripe Checkout Documentation](https://stripe.com/docs/payments/checkout)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)
- [Stripe Testing Guide](https://stripe.com/docs/testing)
- [Stripe CLI Documentation](https://stripe.com/docs/stripe-cli)

---

## Architecture Overview

This application uses:

- **Server-side integration**: All Stripe API calls are made from the Phoenix backend
- **Checkout Sessions**: Uses Stripe Checkout for payment UI
- **Webhooks**: Processes `checkout.session.completed` events to complete enrollments
- **Signature Verification**: Verifies webhook signatures for security
- **Req HTTP Client**: Uses the `Req` library for HTTP requests (as per project guidelines)

The payment flow:
1. User initiates purchase → Creates pending payment record
2. Application creates Stripe Checkout Session → Returns checkout URL
3. User completes payment on Stripe → Redirected back to application
4. Stripe sends webhook → Application verifies signature
5. Application processes webhook → Marks payment complete & enrolls user

---

## Support

If you encounter issues not covered in this guide:

1. Check the [Stripe Support Center](https://support.stripe.com/)
2. Review application logs and Stripe Dashboard
3. Consult the codebase documentation in `docs/`
4. Check test files for usage examples: `test/alchemistdrops/payments_test.exs`
