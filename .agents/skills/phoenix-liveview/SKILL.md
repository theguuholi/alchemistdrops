---
name: phoenix-liveview
description: Use when implementing or reviewing Phoenix LiveViews, navigation, streams, events, stateful components, or changeset-backed forms.
---

# Phoenix LiveView

Keep socket state deliberate, templates component-driven, and collection/form updates consistent between server state and rendered DOM.

## LiveView structure

- Name LiveViews with a `Live` suffix and place routes in the existing router scope without repeating its module alias.
- Use `<.link navigate={...}>`, `<.link patch={...}>`, `push_navigate/2`, and `push_patch/2`; do not use deprecated `live_redirect` or `live_patch` APIs.
- Prefer function components. Introduce a LiveComponent only when isolated state, event targeting, or component lifecycle is necessary.
- Assign only state needed to render or process later events. Do not retain large collections as ordinary assigns when a stream fits the interaction.

## Collections and streams

Use streams for growing, frequently updated, or server-patched collections. A small static or computed list can remain a normal assign.

- Initialize or bulk-load with `stream/3`. For one record, use `stream_insert/4`: the default `at: -1` appends and `at: 0` prepends. Delete with `stream_delete/3`; replace/filter by refetching then streaming with `reset: true`.
- Configure custom IDs with `stream_configure/3` before the first stream operation when domain-stable DOM IDs are needed.
- Render a stream inside a stable parent ID with `phx-update="stream"`; use each emitted stream ID on its child.
- Streams are not enumerable and do not provide counts. Track counts and other derived state separately.
- Use a sibling empty-state element with `hidden only:block` when its stream container supports that structure.
- Do not use deprecated `phx-update="append"` or `phx-update="prepend"`.

When PubSub or concurrent events update a stream, make insert/update/delete handling idempotent and keep any separate count in sync.

## Forms

- Build forms with `to_form/2`, store the form in a socket assign, render `<.form for={@form}>`, and pass fields as `@form[:field]` to `<.input>`.
- Never pass a changeset directly to the template or access changeset fields through Access syntax.
- Give every form an explicit stable DOM ID.
- For parameter-only forms, pass string-keyed params to `to_form/2` and use `as:` when nesting is required.
- For schema forms, build the changeset in the context or LiveView, then convert it with `to_form/2`.
- On validation, set the changeset action to `:validate` before assigning the form so errors render. On submit failure, return the context changeset as a form. On success, update the stream or assigns, clear/reset the form when the flow calls for it, and navigate or display feedback deliberately.

## Verification

Test mount state, events, navigation, form validation/submission, persistence, and collection updates through stable element IDs. If browser JavaScript owns part of the interaction, also use the JavaScript test suite; LiveViewTest does not execute hooks.
