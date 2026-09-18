---
name: phoenix-js-hooks
description: Use when creating or changing Phoenix LiveView JavaScript hooks, phx-hook markup, client-owned DOM, pushEvent/handleEvent integration, or hook lifecycle tests.
---

# Phoenix JavaScript Hooks

Define an explicit ownership boundary between LiveView patches and client JavaScript, then make every acquired browser resource releasable.

## Choose the hook form

- Use a colocated hook when behavior belongs to one component and the project already compiles colocated hooks.
- When the repository uses a central hooks registry, place substantial or shared hooks under its established structure, such as `assets/js/hooks/<Name>/index.js`. Export through that registry and merge it into the `LiveSocket` hooks option without replacing colocated hooks.
- Never embed custom `<script>` tags in HEEx.

## Attach the hook

- Give the hook root a stable unique `id` and set `phx-hook="Name"`.
- Add `phx-update="ignore"` only when JavaScript owns the root's descendants and server patches must not replace them.
- Omit `ignore` when the server must deliver new descendants. In that case, implement an idempotent `updated()` callback that reconciles or rerenders from the latest DOM.
- Do not place server-updated controls inside an ignored subtree unless the hook itself maintains them.

## Lifecycle contract

- `mounted()`: initialize local state, bind listeners, subscribe, and perform the first render.
- `beforeUpdate()`: capture transient DOM state only when it must survive the patch.
- `updated()`: reconcile safely; repeated calls must not duplicate controls, listeners, observers, or generated markup.
- `destroyed()`: remove global and element listeners, disconnect observers, clear timers, cancel pending work where possible, unsubscribe, and destroy third-party instances.
- `disconnected()` / `reconnected()`: pause and restore connection-dependent behavior when needed.

Store references to callbacks and acquired resources on `this`; anonymous listeners cannot be removed reliably. For async rendering, use an incrementing token or `AbortController` so stale completions cannot write into a newer or disconnected DOM.

## Events, HTML, and accessibility

- Use `this.pushEvent` for client-to-server events. Keep every reference returned by `this.handleEvent` and release it with `this.removeHandleEvent(ref)` during cleanup.
- Do not insert unsanitized user-controlled HTML. Prefer DOM APIs or trusted library output with an explicit sanitization boundary.
- Preserve keyboard access, focus behavior, roles, labels, and reduced-motion expectations for interactions created by the hook.

## Verification

Test the hook with the repository's JavaScript runner and DOM environment:

- mount and initial render;
- repeated `updated()` calls without duplication;
- server-patched content when `phx-update="ignore"` is absent;
- event exchange and error behavior;
- async stale-result protection;
- cleanup of listeners, observers, timers, subscriptions, and third-party instances in `destroyed()`.

Use LiveViewTest separately to assert the stable hook root, `phx-hook`, and the intended `phx-update` boundary. LiveViewTest does not execute JavaScript hooks.
