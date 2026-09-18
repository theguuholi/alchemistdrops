---
name: phoenix-liveview-testing
description: Use when writing, reviewing, or debugging Phoenix LiveView tests, HEEx selectors, form interactions, navigation assertions, stream updates, or hook markup integration.
---

# Phoenix LiveView Testing

Test observable behavior through stable DOM contracts and verify persistence or navigation separately from rendered markup.

## Build the test around outcomes

- Use `Phoenix.LiveViewTest` for server-rendered interaction and LazyHTML for focused DOM inspection.
- Split major behaviors into small cases: mount/access, validation, successful interaction, failure, navigation, authorization, and persistence as applicable.
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
    assert has_element?(
             view,
             "#user-form [data-error-for='user_email']",
             "can't be blank"
           )
  end
end
```

Describe user-visible behavior, not implementation trivia. Given establishes state, When performs one action, and Then proves the rendered, navigation, message, or persistence outcome.

## Assert the right layer

- Rendered state: assert the relevant element appears, changes, or disappears.
- Validation errors: assert the field's dedicated error element through a stable ID or `data-error-for` contract; never search the full rendered HTML for the message.
- Navigation: use redirect, live redirect, patch, or current-path assertions matching the action.
- Persistence: query the context or database after the event; HTML alone does not prove a write occurred.
- Rejected actions: verify both the visible outcome and that data did not change.
- Streams: assert inserted/removed row IDs, reset/filter results, empty state, and separately tracked counts.
- Forms: drive `phx-change` and `phx-submit` through the form element with realistic nested params; test validation errors and successful results.
- Context delegation: assert the LiveView exposes the context result correctly. Test business rules exhaustively in the context/domain tests rather than duplicating them through every UI path.

## URL-driven search and filters

- Search, filtering, sorting, and pagination tests must drive URL query parameters and exercise `handle_params/3`.
- Assert that form or control events patch to a RESTful resource URL, then assert the patched URL and rendered result. Do not treat socket-only search assigns as the source of truth.
- Cover direct entry, patching, browser back/forward-compatible state, missing parameters, invalid parameters, empty results, and combinations of supported filters.
- Verify `handle_params/3` delegates the query to the context and updates the visible collection; keep search rules and query construction covered in context tests.

Test the output that Phoenix actually renders. Function components such as `<.form>` may produce markup different from an assumed hand-written structure.

## JavaScript boundary

LiveViewTest verifies that a stable element has the expected `phx-hook` and `phx-update` attributes, but it does not execute hook JavaScript. Test hook lifecycle, DOM mutation, browser events, and cleanup with the repository's JavaScript runner and DOM/browser environment.

## Debugging selectors

When a selector fails, render once, parse the fragment with LazyHTML, filter to the smallest relevant subtree, and inspect those matches. Update the implementation or selector according to the intended DOM contract; do not weaken the assertion merely to match accidental markup.
