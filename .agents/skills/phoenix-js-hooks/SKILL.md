---
name: phoenix-js-hooks
description: Use when creating or changing Phoenix LiveView JavaScript hooks, phx-hook markup, client-owned DOM, pushEvent/handleEvent integration, or hook lifecycle tests.
---

# Phoenix JavaScript Hooks

Define an explicit ownership boundary between LiveView patches and client JavaScript, then make every acquired browser resource releasable.

## Choose the hook form

- Use a colocated hook when behavior belongs to one component and the project already compiles colocated hooks.
- Inspect `assets/js/hooks.js` and `assets/js/hooks/` before adding a hook. Follow their naming, exports, directory layout, and colocated test conventions.
- Place substantial or shared hooks under `assets/js/hooks/<Name>/index.js`, with focused helpers and their tests beside it. Register every hook in `assets/js/hooks.js`.
- If the project has no central registry, create `assets/js/hooks.js` and the `assets/js/hooks/<Name>/` structure rather than defining shared hooks inline in `app.js`.
- Never embed custom `<script>` tags in HEEx.

Keep the registry explicit and small:

```javascript
import Mermaid from "./hooks/Mermaid"

const Hooks = {
  Mermaid,
}

export default Hooks
```

## LiveSocket registration

Preserve Phoenix's generated LiveSocket and navigation setup. Import the central registry and merge it after the colocated hooks so both forms remain available:

```javascript
import Hooks from "./hooks"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())
```

Do not replace `colocatedHooks`, omit the CSRF params, duplicate `LiveSocket`, or remove the generated topbar listeners while registering a hook.

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

Create a colocated `*.test.js` for every hook and every non-trivial JavaScript helper under `assets/js/hooks/`. Use the repository's JavaScript runner and DOM environment; in this project, use Vitest with jsdom. Test:

- mount and initial render;
- repeated `updated()` calls without duplication;
- server-patched content when `phx-update="ignore"` is absent;
- event exchange and error behavior;
- async stale-result protection;
- missing elements, attributes, payload fields, malformed input, and empty content;
- `disconnected()` and `reconnected()` when implemented;
- cleanup of listeners, observers, timers, subscriptions, and third-party instances in `destroyed()`.

When the hook calls `pushEvent`, add a LiveViewTest that uses `render_hook/3` to exercise the matching server `handle_event/3`, including valid and invalid payloads. Separately assert the stable hook root, `phx-hook`, and intended `phx-update` boundary.

`render_hook/3` tests the server side of the hook contract; it does not execute JavaScript. Vitest/jsdom must cover the actual hook lifecycle, DOM changes, `pushEvent`, `handleEvent`, and cleanup. Run both the focused JavaScript tests and the relevant LiveView tests before completion.
