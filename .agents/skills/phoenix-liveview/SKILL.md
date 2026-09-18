---
name: phoenix-liveview
description: Use when implementing or reviewing Phoenix LiveViews, navigation, streams, events, stateful components, or changeset-backed forms.
---

# Phoenix LiveView

Keep socket state deliberate, templates component-driven, and collection/form updates consistent between server state and rendered DOM.

## Generator-first page ownership

Treat the structure produced by `mix phx.gen.live Cars Car cars name` as the default for new LiveView resources and substantial page refactors:

```text
lib/alchemistdrops_web/live/car_live/index.ex
lib/alchemistdrops_web/live/car_live/index.html.heex
lib/alchemistdrops_web/live/car_live/show.ex
lib/alchemistdrops_web/live/car_live/show.html.heex
lib/alchemistdrops_web/live/car_live/form.ex
lib/alchemistdrops_web/live/car_live/form.html.heex
```

- Keep route, module, source folder, template, and test ownership aligned: `live "/cars", CarLive.Index, :index` maps to `car_live/index.ex` and `car_live/index.html.heex`.
- A shared page module is valid when the generator uses one responsibility for multiple actions. In particular, keep `CarLive.Form` for both `:new` and `:edit`, including modal form flows, when that matches the interaction.
- Mirror router namespaces in source paths. For example, `Admin.CarLive.Index` belongs in `live/admin/car_live/index.ex`.
- Keep page markup in the matching `.html.heex` template. Do not add an inline `render/1` with `~H` when Phoenix can auto-render the matching template.
- When a product-specific flow does not fit the generator exactly, preserve its page-focused module, external template, route action, and test organization as closely as the interaction allows.
- Apply this standard prospectively. Do not reorganize unrelated legacy pages merely because they predate it; propose broad migrations separately.

## LiveView structure

- Name LiveViews with a `Live` suffix and place routes in the existing router scope without repeating its module alias.
- Keep LiveView page and stateful LiveComponent modules focused on framework callbacks: do not add `@moduledoc`, `@doc`, callback/helper `@spec`, local `@type`/`@typedoc`, ExDoc examples, or doctests. Retain `@impl true`, and document reusable APIs in the context, presenter, or function-component module that owns them.
- Use `<.link navigate={...}>`, `<.link patch={...}>`, `push_navigate/2`, and `push_patch/2`; do not use deprecated `live_redirect` or `live_patch` APIs.
- Reuse existing function components and LiveComponents. Creating a new component requires the approval process in the `phoenix-development` skill.
- Assign only state needed to render or process later events. Do not retain large collections as ordinary assigns when a stream fits the interaction.
- Name boolean assigns with a `?` suffix, such as `:empty?` or `:can_edit?`, so their intent remains clear in callbacks and templates.

## Clean semantic HEEx

- Keep templates readable and shallow. Extract repeated or conceptually independent UI into focused function components instead of accumulating nested markup, inline transformations, or callback logic in HEEx.
- Use semantic HTML5 landmarks and elements according to meaning: `header`, `nav`, `main`, `section`, `article`, `aside`, `footer`, `form`, `fieldset`, `label`, and `button`. Avoid generic `div` containers when a semantic element fits.
- Give every navigation region an accessible label and structure links as navigation content, normally with `nav`, `ul`, `li`, and `<.link>`.
- Use Emmet notation to communicate or plan markup hierarchy, for example `main>section>p{name}`, but always expand it into valid HEEx. Never leave an Emmet abbreviation in a template.
- Keep IDs unique and purposeful for accessibility, LiveView updates, hooks, and stable tests. Do not add IDs solely to mirror styling structure.

## Mobile-first layout

- Design the smallest viewport first. Base markup and Tailwind classes must work on mobile; add `sm:`, `md:`, and larger breakpoint variants only as progressive enhancements.
- Start with single-column flow, readable spacing, touch-friendly controls, and no horizontal overflow. Expand into grids, sidebars, or denser navigation only when viewport space permits.
- Preserve semantic reading order and keyboard navigation across breakpoints; do not use CSS reordering to make desktop structure inaccessible on mobile.
- Verify forms, navigation, tables or card alternatives, empty states, validation errors, and interactive controls at mobile width before considering the layout complete.

## Callback responsibility

LiveView is an interface and orchestration layer. Its callbacks call a context/domain function, interpret the result, and return the new socket state. Never implement business rules, authorization policy, domain validation, pricing/calculation logic, state transitions, persistence transactions, or reusable query construction inside a LiveView.

- `mount/3` loads initial state through contexts and establishes UI-only assigns or streams.
- `on_mount/4` delegates authentication/authorization decisions to the established account or policy APIs, then halts or continues navigation.
- `handle_params/3` translates URL state into a context query and assigns or streams the result.
- `handle_event/3` converts UI input into a context call, then updates forms, streams, flash, or navigation from the returned result.
- `handle_info/2` delegates message handling to the appropriate context/domain operation before reflecting the result in the socket.

Small UI transformations such as selecting params, setting a changeset action for display, `to_form/2`, assigning values, updating streams, flash, and navigation belong in LiveView. If a decision changes domain behavior independently of the page, move it to a context or domain module and test it there.

- Never call `Repo` directly from a LiveView, including for association preloads. Add or use a scoped context API that returns the data the page needs.
- Guard PubSub subscriptions in `mount/3` with `connected?(socket)` so disconnected rendering does not subscribe or duplicate messages.
- Order module contents as imports and aliases, public `@impl true` callbacks in lifecycle order, then private helpers.
- When a context operation returns result tuples, handle both `{:ok, value}` and `{:error, reason}` deliberately. Do not silently assert away user-recoverable errors.

## URL-driven search and filters

- Make the URL query string the source of truth for search, filters, sorting, and pagination. Handle those values in `handle_params/3`, including initial entry and every patch.
- Search events only normalize UI input enough to build a resource URL and call `push_patch/2`. They do not run the query or keep a separate socket-only filter state.
- Use RESTful resource paths with query parameters, for example `~p"/products?#{%{q: query, page: page}}"`; do not encode search state as imperative event names or opaque path segments.
- Let the context validate supported filters, construct the Ecto query, enforce scope, and return results. `handle_params/3` maps that result into assigns or a stream, including empty and invalid-query states.
- Preserve bookmark, refresh, share, and browser back/forward behavior by ensuring the rendered state can be reconstructed from the URL.

## Collections and streams

Use streams for growing, frequently updated, or server-patched collections. A small static or computed list can remain a normal assign.

- Initialize or bulk-load with `stream/3`. For one record, use `stream_insert/4`: the default `at: -1` appends and `at: 0` prepends. Delete with `stream_delete/3`; replace/filter by refetching then streaming with `reset: true`.
- Configure custom IDs with `stream_configure/3` before the first stream operation when domain-stable DOM IDs are needed.
- Render a stream inside a stable parent ID with `phx-update="stream"`; use each emitted stream ID on its child.
- Streams are not enumerable and do not provide counts. Track counts and other derived state separately.
- Use a sibling empty-state element with `hidden only:block` when its stream container supports that structure.
- Do not use deprecated `phx-update="append"` or `phx-update="prepend"`.
- Name stream keys with the schema's plural snake_case form and use that name consistently in callbacks and templates, such as `LoyaltyCard` becoming `:loyalty_cards`.

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
