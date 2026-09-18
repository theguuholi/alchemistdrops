# LiveView Generator Standards Design

## Objective

Make the Phoenix generator output the default architectural reference for future LiveView work while keeping valid existing flows intact. Consolidate the useful conventions currently stored in `lib/alchemistdrops_web/live/CLAUDE.md` into the project skills that agents already load through `AGENTS.md`, then remove the duplicated instruction file.

## Scope

- Update the existing `phoenix-liveview`, `phoenix-development`, and `phoenix-liveview-testing` skills.
- Remove `lib/alchemistdrops_web/live/CLAUDE.md` after its useful rules have an explicit destination.
- Apply the standard prospectively to new or substantially changed LiveView pages.
- Preserve current application behavior and route structure.

This change does not reorganize existing LiveViews or tests, add components, update dependencies, or change runtime code.

## Generator-first architecture

Treat `mix phx.gen.live Cars Car cars name` as the default reference for naming, file ownership, routes, templates, and tests. A resource should normally use page-focused modules such as:

```text
lib/alchemistdrops_web/live/car_live/index.ex
lib/alchemistdrops_web/live/car_live/index.html.heex
lib/alchemistdrops_web/live/car_live/show.ex
lib/alchemistdrops_web/live/car_live/show.html.heex
lib/alchemistdrops_web/live/car_live/form.ex
lib/alchemistdrops_web/live/car_live/form.html.heex

test/alchemistdrops_web/live/car_live/index_test.exs
test/alchemistdrops_web/live/car_live/show_test.exs
test/alchemistdrops_web/live/car_live/form_test.exs
```

The router should name the LiveView module and action in the same style:

```elixir
live "/cars", CarLive.Index, :index
live "/cars/new", CarLive.Form, :new
live "/cars/:id/edit", CarLive.Form, :edit
live "/cars/:id", CarLive.Show, :show
```

This is a responsibility standard, not a mechanical one-route-one-module rule. `CarLive.Form` may intentionally serve both `:new` and `:edit`, including modal flows. When the generator does not fit a product-specific interaction exactly, preserve its module, template, route, and test organization as closely as the interaction allows.

Nested namespaces must remain aligned across router modules, source folders, and test folders. For example, `Admin.CarLive.Index` belongs under `live/admin/car_live/index.ex` and its tests under `live/admin/car_live/index_test.exs`.

## File responsibilities

- A page module owns LiveView callbacks, orchestration, assigns, streams, and private UI helpers.
- Its matching `.html.heex` file owns markup. Do not add an inline `render/1` template when Phoenix can auto-render the matching file.
- LiveViews call contexts rather than `Repo` directly. Domain rules, authorization, persistence, reusable queries, and preloads belong behind context APIs.
- Tests mirror the page module they exercise. Shared form behavior can remain in one `form_test.exs` file.

## Component approval gate

Agents must not create a new function component or LiveComponent by default. Before proposing one, they must:

1. Search the existing components and page-local helpers for a suitable implementation.
2. Explain why composition or reuse of an existing component is insufficient.
3. Define the proposed component's responsibility, location, attributes, slots, and expected reuse.
4. Obtain explicit approval from the software engineer before creating it.

This gate applies to new components only. It does not prohibit using, extending, or composing an existing component within its established responsibility.

## Retained LiveView conventions

The project skills will preserve these useful conventions from the removed file:

- semantic, mobile-first HEEx;
- `:for` on the repeated HTML/component element instead of block-style markup loops;
- stable DOM IDs and accessible controls;
- one meaningful `page_title` and one corresponding page `<h1>`;
- boolean assigns ending in `?`;
- PubSub subscriptions guarded by `connected?/1`;
- callbacks before private helpers;
- plural schema-aligned stream names;
- explicit success and error handling for context results;
- no direct `Repo` access from LiveViews;
- tests organized around observable behavior and page ownership.

## Compatibility and rollout

Existing code is not automatically noncompliant merely because it predates this standard. Apply the standard when generating a page or substantially changing its architecture. Any broad migration of old pages or tests requires a separately reviewed change.

## Verification

- Validate all three edited skill folders with the Codex skill validator.
- Confirm the skills contain no contradictory collection-loop guidance.
- Confirm every retained convention has a destination before deleting `CLAUDE.md`.
- Run formatting and the repository completion check to prove documentation-only changes do not disturb the application.
