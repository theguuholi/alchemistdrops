---
name: phoenix-liveview-testing
description: Use when writing, reviewing, or debugging Phoenix LiveView tests, HEEx selectors, form interactions, navigation assertions, stream updates, or hook markup integration.
---

# Phoenix LiveView Testing

Test observable behavior through stable DOM contracts and verify persistence or navigation separately from rendered markup.

## Build the test around outcomes

- Use `Phoenix.LiveViewTest` for server-rendered interaction and LazyHTML for focused DOM inspection.
- Split major behaviors into small cases: mount/access, validation, successful interaction, failure, navigation, authorization, and persistence as applicable.
- Authenticate through the project's test helpers and include anonymous, wrong-user, or wrong-role cases for protected LiveViews.
- Select stable IDs, names, roles, and `data-*` contracts that the template intentionally exposes. Avoid styling classes and incidental text when a structural selector is available.
- Prefer `element/2`, `has_element?/2`, `render_click/1`, `render_change/2`, and `render_submit/2` over assertions against a full raw HTML string.

Raw fragment inspection is appropriate when diagnosing output or when a framework component has no stable higher-level assertion. Parse only the relevant fragment with LazyHTML rather than printing the entire page.

## Assert the right layer

- Rendered state: assert the relevant element appears, changes, or disappears.
- Navigation: use redirect, live redirect, patch, or current-path assertions matching the action.
- Persistence: query the context or database after the event; HTML alone does not prove a write occurred.
- Rejected actions: verify both the visible outcome and that data did not change.
- Streams: assert inserted/removed row IDs, reset/filter results, empty state, and separately tracked counts.
- Forms: drive `phx-change` and `phx-submit` through the form element with realistic nested params; test validation errors and successful results.

Test the output that Phoenix actually renders. Function components such as `<.form>` may produce markup different from an assumed hand-written structure.

## JavaScript boundary

LiveViewTest verifies that a stable element has the expected `phx-hook` and `phx-update` attributes, but it does not execute hook JavaScript. Test hook lifecycle, DOM mutation, browser events, and cleanup with the repository's JavaScript runner and DOM/browser environment.

## Debugging selectors

When a selector fails, render once, parse the fragment with LazyHTML, filter to the smallest relevant subtree, and inspect those matches. Update the implementation or selector according to the intended DOM contract; do not weaken the assertion merely to match accidental markup.
