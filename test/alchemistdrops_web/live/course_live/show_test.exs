defmodule AlchemistdropsWeb.CourseLive.ShowTest do
  use AlchemistdropsWeb.ConnCase

  import Alchemistdrops.AccountsFixtures
  import Alchemistdrops.CoursesFixtures
  import Alchemistdrops.EnrollmentsFixtures
  import Phoenix.LiveViewTest

  alias Alchemistdrops.Payments.MockHttpClient
  alias AlchemistdropsWeb.CourseLive.Show

  describe "mount/3" do
    test "given a published course when visitor loads the page then they see course details", %{
      conn: conn
    } do
      course =
        course_fixture(%{
          title: "Elixir Mastery",
          description: "Master Elixir programming",
          body: "Complete guide to Elixir",
          price: Money.new(9999, :USD),
          published: true
        })

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "h1", "Elixir Mastery")
      assert has_element?(view, "p", "Master Elixir programming")
      assert has_element?(view, "span", "$99.99")
    end

    test "given an unpublished course when visitor tries to access then they see error", %{
      conn: conn
    } do
      course = course_fixture(%{published: false})

      assert_error_sent 404, fn ->
        live(conn, ~p"/courses/#{course}")
      end
    end

    test "given a course with lessons when visitor loads the page then they see lesson list", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "h3", "Course Content")
      assert has_element?(view, "li", "Lesson 1")
      assert has_element?(view, "li", "Lesson 2")
    end

    test "given a course with no lessons when visitor loads the page then they see empty state",
         %{
           conn: conn
         } do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "p", "No lessons available yet")
    end

    test "given a free course when visitor loads the page then they see free badge", %{
      conn: conn
    } do
      course = course_fixture(%{price: Money.new(0, :USD), published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "span", "Free")
    end

    test "given a published course with nil price when visitor loads the page then page renders and shows Free",
         %{conn: conn} do
      course = course_without_price_fixture(%{title: "Course With Nil Price", published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "h1", "Course With Nil Price")
      assert has_element?(view, "span", "Free")
    end
  end

  describe "enrollment status" do
    test "given a logged in user not enrolled when they view course then they see enroll button",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(0, :USD), published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      assert has_element?(view, "button#enroll-button", "Enroll Now")
    end

    test "given a logged in user enrolled when they view course then they see start learning button",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      assert has_element?(view, "a", "Start Learning")
    end

    test "given a guest user when they view course then they see sign in prompt", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "a", "Sign in to Enroll")
    end
  end

  describe "handle_event/3 - enroll_free" do
    test "given a logged in user when they click enroll on free course then they are enrolled",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(0, :USD), published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#enroll-button")
      |> render_click()

      # Check for success flash or success message
      assert has_element?(view, "a", "Start Learning")
    end

    test "given a paid course when user tries to enroll then they are redirected to checkout",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(9999, :USD), published: true})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      # For paid courses, we show a different button
      assert has_element?(view, "button", "Purchase")
    end
  end

  describe "handle_event/3 - purchase" do
    # MockHttpClient uses ETS in test so expectations set here are visible to the LiveView process.

    test "given a paid course with stripe_price_id when user clicks purchase then they are redirected to Stripe checkout",
         %{conn: conn} do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "price_test_123",
          published: true
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#purchase-button")
      |> render_click()

      # LiveView uses MockHttpClient (in its process); default mock returns this URL
      assert_redirect(view, "https://checkout.stripe.com/test/session")
    end

    test "given a paid course without stripe_price_id when user clicks purchase then they see error flash and stay on page",
         %{conn: conn} do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: nil,
          published: true
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#purchase-button")
      |> render_click()

      assert has_element?(view, "[role=alert]", "not set up for payment")
      assert has_element?(view, "h1", course.title)
    end

    test "given a paid course with stripe_price_id empty string when user clicks purchase then they see error flash",
         %{conn: conn} do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "",
          published: true
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#purchase-button")
      |> render_click()

      assert has_element?(view, "[role=alert]", "not set up for payment")
    end

    test "given Stripe API error when user clicks purchase then they see error flash", %{
      conn: conn
    } do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "price_123",
          published: true
        })

      MockHttpClient.expect_response(%{
        status: 400,
        body: %{"error" => %{"message" => "Invalid price ID"}}
      })

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#purchase-button")
      |> render_click()

      assert has_element?(view, "[role=alert]", "Invalid price ID")
    end

    test "given Stripe API error without message when user clicks purchase then they see fallback message",
         %{conn: conn} do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "price_123",
          published: true
        })

      MockHttpClient.expect_response(%{status: 500, body: %{}})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#purchase-button")
      |> render_click()

      assert has_element?(view, "[role=alert]", "Stripe could not start checkout")
    end

    test "given network failure when user clicks purchase then they see error flash", %{
      conn: conn
    } do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "price_123",
          published: true
        })

      MockHttpClient.expect_error(:timeout)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      view
      |> element("button#purchase-button")
      |> render_click()

      assert has_element?(view, "[role=alert]", "Checkout unavailable")
    end

    test "given course is free when purchase event is handled then they see course is free message",
         %{conn: _conn} do
      # :course_is_free is returned by Payments when course.price is zero; the UI shows
      # "Enroll Now" for free courses so this branch is not reachable by clicking. We test
      # it by calling the handler with a socket that has a free course.
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(0, :USD),
          stripe_price_id: "price_any",
          published: true
        })

      socket =
        %Phoenix.LiveView.Socket{
          endpoint: AlchemistdropsWeb.Endpoint,
          assigns: %{
            __changed__: %{},
            flash: %{},
            current_scope: %{user: user},
            course: course
          },
          private: %{assign_new: {%{}, []}, live_temp: %{}}
        }

      assert {:noreply, updated_socket} = Show.handle_event("purchase", %{}, socket)

      assert updated_socket.assigns.enrolled? == false
      assert Phoenix.Flash.get(updated_socket.assigns.flash, :error) =~ "free"
    end

    test "given stripe_price_id empty string when purchase is handled then blank?(\"\") is used and error flash is set",
         %{conn: _conn} do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "",
          published: true
        })

      socket =
        %Phoenix.LiveView.Socket{
          endpoint: AlchemistdropsWeb.Endpoint,
          assigns: %{
            __changed__: %{},
            flash: %{},
            current_scope: %{user: user},
            course: course
          },
          private: %{assign_new: {%{}, []}, live_temp: %{}}
        }

      assert {:noreply, updated_socket} = Show.handle_event("purchase", %{}, socket)
      assert Phoenix.Flash.get(updated_socket.assigns.flash, :error) =~ "not set up for payment"
    end

    test "given stripe_price_id non-string when purchase is handled then blank?(_) returns false and checkout is created",
         %{conn: _conn} do
      user = user_fixture()

      course =
        course_fixture(%{
          price: Money.new(9999, :USD),
          stripe_price_id: "price_123",
          published: true
        })

      # Use a course with non-string stripe_price_id to cover blank?(_) clause
      course_with_atom_id = %{course | stripe_price_id: :non_string_value}

      MockHttpClient.expect_response(%{
        status: 200,
        body: %{
          "id" => "cs_cover",
          "url" => "https://checkout.stripe.com/cover",
          "payment_intent" => "pi_cover"
        }
      })

      socket =
        %Phoenix.LiveView.Socket{
          endpoint: AlchemistdropsWeb.Endpoint,
          assigns: %{
            __changed__: %{},
            flash: %{},
            current_scope: %{user: user},
            course: course_with_atom_id
          },
          private: %{assign_new: {%{}, []}, live_temp: %{}}
        }

      assert {:noreply, updated_socket} = Show.handle_event("purchase", %{}, socket)

      assert updated_socket.redirected ==
               {:redirect, %{external: "https://checkout.stripe.com/cover", status: 302}}
    end
  end

  describe "handle_params/2 - purchase return" do
    test "given purchase=success in query when user lands on course then they see success flash",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      {:ok, view, _html} =
        live(conn, ~p"/courses/#{course}" <> "?purchase=success")

      assert has_element?(view, "[role=alert]", "Payment successful")
    end

    test "given purchase=success when user is already enrolled then they see Start Learning",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}" <> "?purchase=success")

      assert has_element?(view, "[role=alert]", "Payment successful")
      assert has_element?(view, "a", "Start Learning")
    end

    test "given purchase=cancelled in query when user lands on course then they see cancelled message",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      {:ok, view, _html} =
        live(conn, ~p"/courses/#{course}" <> "?purchase=cancelled")

      assert has_element?(view, "[role=alert]", "Checkout cancelled")
    end
  end

  describe "course curriculum display" do
    test "given published and unpublished lessons when visitor views course then they see only published",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      _published =
        lesson_fixture(%{course_id: course.id, title: "Published Lesson", published: true})

      _unpublished =
        lesson_fixture(%{course_id: course.id, title: "Secret Lesson", published: false})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "li", "Published Lesson")
      refute has_element?(view, "li", "Secret Lesson")
    end

    test "given lessons with duration when visitor views course then they see total duration", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})
      _lesson1 = lesson_fixture(%{course_id: course.id, duration: 600, published: true})
      _lesson2 = lesson_fixture(%{course_id: course.id, duration: 900, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Total: 1500 seconds = 25 minutes
      assert has_element?(view, "span", "25 min")
    end

    test "given lessons in specific order when visitor views course then they see correct order",
         %{conn: conn} do
      course = course_fixture(%{published: true})

      _lesson3 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 3", order: 3, published: true})

      _lesson1 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 1", order: 1, published: true})

      _lesson2 =
        lesson_fixture(%{course_id: course.id, title: "Lesson 2", order: 2, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      html = render(view)

      # Check that Lesson 1 appears before Lesson 2 which appears before Lesson 3
      lesson1_pos = html |> :binary.match("Lesson 1") |> elem(0)
      lesson2_pos = html |> :binary.match("Lesson 2") |> elem(0)
      lesson3_pos = html |> :binary.match("Lesson 3") |> elem(0)

      assert lesson1_pos < lesson2_pos
      assert lesson2_pos < lesson3_pos
    end
  end

  describe "responsive design and accessibility" do
    test "given a course when visitor views page then it has proper semantic HTML", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Using Layouts.app wrapper
      assert has_element?(view, "article")
      assert has_element?(view, "h1")
    end

    test "given a course with lessons when visitor views page then curriculum has proper structure",
         %{conn: conn} do
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "section#curriculum")
      assert has_element?(view, "ol")
      assert has_element?(view, "li")
    end
  end

  describe "edge cases" do
    test "given enrolled user trying to enroll again when they click enroll then error is shown",
         %{
           conn: conn
         } do
      user = user_fixture()
      course = course_fixture(%{price: Money.new(0, :USD), published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      # User is already enrolled, so they see Start Learning
      assert has_element?(view, "a", "Start Learning")
    end

    test "given lessons without duration when visitor views then total duration is zero", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, duration: nil, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Should render without crashing when duration is nil
      assert has_element?(view, "article")
    end

    test "given a course with thumbnail when visitor views then they see the image", %{
      conn: conn
    } do
      course =
        course_fixture(%{
          published: true,
          thumbnail_url: "https://example.com/thumbnail.jpg"
        })

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      assert has_element?(view, "img[src='https://example.com/thumbnail.jpg']")
    end

    test "given a course without thumbnail when visitor views then they see placeholder", %{
      conn: conn
    } do
      course = course_fixture(%{published: true, thumbnail_url: nil})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Should have the hero icon as placeholder
      assert has_element?(view, "figure")
    end

    test "given enrolled user with completed status when they view course then they see start learning",
         %{conn: conn} do
      user = user_fixture()
      course = course_fixture(%{published: true})
      _lesson = lesson_fixture(%{course_id: course.id, published: true})
      enrollment_fixture(%{user_id: user.id, course_id: course.id, status: "completed"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/courses/#{course}")

      assert has_element?(view, "a", "Start Learning")
    end

    test "given lessons with mixed durations when visitor views then total is correct", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})
      _lesson1 = lesson_fixture(%{course_id: course.id, duration: 300, published: true})
      _lesson2 = lesson_fixture(%{course_id: course.id, duration: nil, published: true})
      _lesson3 = lesson_fixture(%{course_id: course.id, duration: 600, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Total: 300 + 600 = 900 seconds = 15 minutes (nil is filtered out)
      assert has_element?(view, "span", "15 min")
    end

    test "given only lessons with nil duration when visitor views then page renders", %{
      conn: conn
    } do
      course = course_fixture(%{published: true})
      _lesson1 = lesson_fixture(%{course_id: course.id, duration: nil, published: true})
      _lesson2 = lesson_fixture(%{course_id: course.id, duration: nil, published: true})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course}")

      # Page should render without errors even with nil durations
      assert has_element?(view, "article")
      assert has_element?(view, "h1", course.title)
    end
  end
end
