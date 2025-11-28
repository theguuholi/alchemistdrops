defmodule Alchemistdrops.Courses.CourseTest do
  @moduledoc """
  Feature: Course Schema Validation
    As a system administrator
    I want to ensure courses are properly validated
    So that only valid course data is stored in the database
  """
  use Alchemistdrops.DataCase

  alias Alchemistdrops.Courses.Course

  describe "Feature: Course Changeset Validation" do
    test "Scenario: Creating a course with valid required fields" do
      # Given valid course attributes with title and description
      attrs = %{
        title: "Introduction to Elixir",
        description: "Learn the basics of Elixir programming"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating a course without a title" do
      # Given course attributes without a title
      attrs = %{description: "Description without title"}

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a title required error
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a course without a description" do
      # Given course attributes without a description
      attrs = %{title: "Title without description"}

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a description required error
      assert %{description: ["can't be blank"]} = errors_on(changeset)
    end

    test "Scenario: Creating a course with a negative price" do
      # Given course attributes with a negative price
      attrs = %{
        title: "Test Course",
        description: "Test Description",
        price: Decimal.new("-10.00")
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a price validation error
      assert %{price: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "Scenario: Creating a course with zero price (free course)" do
      # Given course attributes with zero price
      attrs = %{
        title: "Free Course",
        description: "A free course for everyone",
        price: Decimal.new("0.00")
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Creating a course with an invalid currency format" do
      # Given course attributes with an invalid currency code
      attrs = %{
        title: "Test Course",
        description: "Test Description",
        currency: "INVALID"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a currency format error
      assert %{currency: ["must be a 3-letter currency code"]} = errors_on(changeset)
    end

    test "Scenario: Creating a course with lowercase currency code" do
      # Given course attributes with lowercase currency code
      attrs = %{
        title: "Test Course",
        description: "Test Description",
        currency: "usd"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a currency format error
      assert %{currency: ["must be a 3-letter currency code"]} = errors_on(changeset)
    end

    test "Scenario: Default values are set when not provided" do
      # Given minimal course attributes without price, currency, or published status
      attrs = %{
        title: "Test Course",
        description: "Test Description"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And default price should be 0.00
      assert Ecto.Changeset.get_field(changeset, :price) == Decimal.new("0.00")

      # And default currency should be USD
      assert Ecto.Changeset.get_field(changeset, :currency) == "USD"

      # And default published status should be false
      assert Ecto.Changeset.get_field(changeset, :published) == false
    end

    test "Scenario: Title whitespace is trimmed" do
      # Given course attributes with whitespace around the title
      attrs = %{
        title: "  Test Course  ",
        description: "Test Description"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the title should be trimmed
      assert Ecto.Changeset.get_change(changeset, :title) == "Test Course"
    end

    test "Scenario: Title exceeds maximum length" do
      # Given course attributes with a title longer than 255 characters
      attrs = %{
        title: String.duplicate("a", 256),
        description: "Test Description"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be invalid
      refute changeset.valid?

      # And it should have a title length error
      assert %{title: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "Scenario: Title at maximum length is accepted" do
      # Given course attributes with a title exactly 255 characters
      attrs = %{
        title: String.duplicate("a", 255),
        description: "Test Description"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Valid currency codes are accepted" do
      # Given a list of valid currency codes
      valid_currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY"]

      # When I create changesets with each currency
      for currency <- valid_currencies do
        attrs = %{
          title: "Test Course",
          description: "Test Description",
          currency: currency
        }

        changeset = Course.changeset(%Course{}, attrs)

        # Then each changeset should be valid
        assert changeset.valid?, "Expected #{currency} to be valid"
      end
    end

    test "Scenario: All optional fields are accepted" do
      # Given course attributes with all optional fields populated
      attrs = %{
        title: "Complete Course",
        description: "Full description",
        body: "Full course body content",
        price: Decimal.new("99.99"),
        currency: "EUR",
        stripe_product_id: "prod_123",
        stripe_price_id: "price_123",
        published: true,
        thumbnail_url: "https://example.com/thumb.jpg"
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And all fields should be set correctly
      assert Ecto.Changeset.get_change(changeset, :title) == "Complete Course"
      assert Ecto.Changeset.get_change(changeset, :body) == "Full course body content"
      assert Ecto.Changeset.get_change(changeset, :stripe_product_id) == "prod_123"
      assert Ecto.Changeset.get_change(changeset, :stripe_price_id) == "price_123"
      assert Ecto.Changeset.get_change(changeset, :published) == true

      assert Ecto.Changeset.get_change(changeset, :thumbnail_url) ==
               "https://example.com/thumb.jpg"
    end

    test "Scenario: Published flag can be set to false explicitly" do
      # Given course attributes with published set to false
      attrs = %{
        title: "Draft Course",
        description: "This is a draft",
        published: false
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And published should be false
      assert Ecto.Changeset.get_field(changeset, :published) == false
    end

    test "Scenario: Published flag can be set to true" do
      # Given course attributes with published set to true
      attrs = %{
        title: "Published Course",
        description: "This is published",
        published: true
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?

      # And published should be true
      assert Ecto.Changeset.get_change(changeset, :published) == true
    end

    test "Scenario: Empty string for optional fields is accepted" do
      # Given course attributes with empty strings for optional fields
      attrs = %{
        title: "Test Course",
        description: "Test Description",
        body: "",
        stripe_product_id: "",
        stripe_price_id: "",
        thumbnail_url: ""
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Nil values for optional fields are accepted" do
      # Given course attributes with nil for optional fields
      attrs = %{
        title: "Test Course",
        description: "Test Description",
        body: nil,
        stripe_product_id: nil,
        stripe_price_id: nil,
        thumbnail_url: nil
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Large price values are accepted" do
      # Given course attributes with a large price
      attrs = %{
        title: "Premium Course",
        description: "Very expensive course",
        price: Decimal.new("99999.99")
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end

    test "Scenario: Small decimal price values are accepted" do
      # Given course attributes with a small decimal price
      attrs = %{
        title: "Budget Course",
        description: "Affordable course",
        price: Decimal.new("0.99")
      }

      # When I create a changeset with these attributes
      changeset = Course.changeset(%Course{}, attrs)

      # Then the changeset should be valid
      assert changeset.valid?
    end
  end
end
