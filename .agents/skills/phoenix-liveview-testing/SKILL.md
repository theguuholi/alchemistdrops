---
name: phoenix-liveview-testing
description: Use when writing, reviewing, or debugging Phoenix LiveView tests, HEEx selectors, form interactions, navigation assertions, stream updates, or hook markup integration.
---

# Phoenix LiveView Testing

Test LiveViews exclusively through observable behavior and stable DOM contracts. Keep persistence assertions in context or domain tests.

## Mirror page ownership

Follow the resource and page structure used by `mix phx.gen.live` when adding tests:

```text
lib/alchemistdrops_web/live/car_live/index.ex
test/alchemistdrops_web/live/car_live/index_test.exs

lib/alchemistdrops_web/live/car_live/show.ex
test/alchemistdrops_web/live/car_live/show_test.exs

lib/alchemistdrops_web/live/car_live/form.ex
test/alchemistdrops_web/live/car_live/form_test.exs
```

- Keep the tests for one page module in its matching test file. A shared `Form` module serving `:new` and `:edit` remains one page responsibility and belongs in `form_test.exs`.
- Mirror nested namespaces in test folders: tests for `Admin.CarLive.Index` belong in `test/alchemistdrops_web/live/admin/car_live/index_test.exs`.
- When a product-specific flow differs from generator output, keep test ownership aligned with the actual page module rather than forcing one test file per route action.
- Apply this layout to new tests and substantial page refactors. Moving unrelated legacy tests requires a separately reviewed migration.

## Test foundation

- Use the application's `ConnCase`, not `ExUnit.Case` directly, and import `Phoenix.LiveViewTest` plus only the fixture modules the test needs.
- Do not add `doctest` for LiveView page or stateful LiveComponent modules. Their contracts are callbacks and rendered interactions, so cover them through `Phoenix.LiveViewTest`; doctests remain appropriate for separately documented contexts, presenters, and function-component modules.
- Use the project's authentication and scope setup helpers. Create all setup state through fixtures with the correct scope.
- LiveView test modules must never alias or call `Repo` or application contexts. A fixture may use those boundaries internally to establish Given state, including deliberate legacy or exceptional records.
- Fixtures are setup tools only. Never hide a persistence assertion in a fixture or call a fixture from the Then phase to inspect state.
- Put setup that only serves one callback or behavior inside its `describe` block, and return named context values from setup helpers.
- Match successful mounts as `{:ok, view, _html}`. Discard the initial HTML and make assertions against the current `view`.

## Build the test around outcomes

- Use `Phoenix.LiveViewTest` for server-rendered interaction and LazyHTML for focused DOM inspection.
- Split major behaviors into small cases: mount/access, validation, successful interaction, failure, navigation, and authorization.
- Group tests by the callback and behavior that owns the interaction. Use names such as `describe "mount/3 - initial state"`, `describe "on_mount/4 - authorization"`, `describe "handle_params/3 - search"`, `describe "handle_event/3 - validate"`, and `describe "handle_info/2 - refresh"`.
- Cover every observable scenario for each callback: success, empty or missing input, invalid input, context errors, unauthorized access, missing records, and repeated messages/events when applicable.
- Authenticate through the project's test helpers and include anonymous, wrong-user, or wrong-role cases for protected LiveViews.
- Select stable IDs, names, roles, and `data-*` contracts that the template intentionally exposes. Avoid styling classes and incidental text when a structural selector is available.
- Prefer `element/2`, `has_element?/2`, `render_click/1`, `render_change/2`, and `render_submit/2` over assertions against a full raw HTML string.

Raw fragment inspection is diagnostic only. Never keep assertions such as `assert html =~ "error"`: unrelated markup can make them pass while the correct field remains broken. Add or use a stable selector for the responsible element, then assert it with `has_element?/2`, `has_element?/3`, or `element/2`.

## Given, When, Then

Write scenario names in Gherkin form: `test "given ..., when ..., then ..."`. Keep the body in the same order and mark non-obvious phases with `# Given`, `# When`, and `# Then` comments.

```elixir
describe "handle_event/3 - validate" do
  test "given a loaded LiveView, when a required field is missing, then it renders the context validation error",
       %{conn: conn} do
    # Given
    {:ok, view, _html} = live(conn, ~p"/users/new")

    # When
    view |> form("#user-form", user: %{email: ""}) |> render_change()

    # Then
    assert has_element?(view, "#user-email-error", "can't be blank")
  end
end
```

Describe user-visible behavior, not implementation trivia. Given establishes state with fixtures, When performs one action, and Then proves a rendered, navigation, flash, message, log, or external-integration outcome.

## Assert the right layer

- Rendered state: assert the relevant element appears, changes, or disappears.
- Validation errors: assert the field's dedicated error element through a stable ID, such as `#user-email-error`; never search the full rendered HTML for the message.
- Navigation: use redirect, live redirect, patch, or current-path assertions matching the action.
- Persistence: cover writes and domain invariants in context or domain tests, never by querying a context or `Repo` from a LiveView test.
- Rejected actions: verify the visible rejection. Cover the unchanged data invariant at the context or domain layer.
- Streams: assert inserted/removed row IDs, reset/filter results, empty state, and separately tracked counts.
- Forms: drive `phx-change` and `phx-submit` through the form element with realistic nested params; test validation errors and successful results.
- Context results: assert only how the LiveView exposes the result through DOM, flash, navigation, logs, messages, or an external test adapter. Test delegation and business rules in context/domain tests.

## Interactions and navigation

- When a clickable element has a visible label, use `element(view, selector, label)` so the action identifies both its stable target and user-visible control.
- Do not assert against the HTML returned by `render_click/1`, `render_change/1`, or `render_submit/1`. Perform the action, then assert the resulting `view`, navigation, flash, message, log, or external interaction.
- Drive forms through their stable form ID with params matching the actual field namespace.
- Use `follow_redirect/3` when an action must mount the destination LiveView, `assert_patch/2` for `push_patch`, and `assert_redirect/2` for redirects that do not need to mount the destination.

## State changes and isolation

- For PubSub behavior, broadcast on the exact topic exposed by the context subscription API, render the view, and assert the observable update through stable selectors.
- To reproduce a race or stale-state case, mount first, change the persisted state through a purpose-built fixture, then perform the user action and verify the observable outcome.
- When a test overrides application configuration, capture the complete previous value and restore it with `on_exit/1`.
- Do not assert internal socket assigns, CSS classes, context implementation details, or database state. Do not add hidden markup or `data-*` attributes solely to expose internal state to tests. Assert intentional DOM contracts and user-visible behavior; cover domain rules in context tests.

## URL-driven search and filters

- Search, filtering, sorting, and pagination tests must drive URL query parameters and exercise `handle_params/3`.
- Assert that form or control events patch to a RESTful resource URL, then assert the patched URL and rendered result. Do not treat socket-only search assigns as the source of truth.
- Cover direct entry, patching, browser back/forward-compatible state, missing parameters, invalid parameters, empty results, and combinations of supported filters.
- Verify that `handle_params/3` updates the visible collection; keep context delegation, search rules, and query construction covered in context tests.

Test the output that Phoenix actually renders. Function components such as `<.form>` may produce markup different from an assumed hand-written structure.

## JavaScript boundary

LiveViewTest verifies that a stable element has the expected `phx-hook` and `phx-update` attributes, but it does not execute hook JavaScript. Test hook lifecycle, DOM mutation, browser events, and cleanup with the repository's JavaScript runner and DOM/browser environment.

## Debugging selectors

When a selector fails, render once, parse the fragment with LazyHTML, filter to the smallest relevant subtree, and inspect those matches. Update the implementation or selector according to the intended DOM contract; do not weaken the assertion merely to match accidental markup.
