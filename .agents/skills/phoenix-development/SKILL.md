---
name: phoenix-development
description: Use when adding or reviewing Phoenix 1.8 routes, function components, HEEx templates, layouts, icons, inputs, or frontend assets.
---

# Phoenix Development

Follow Phoenix 1.8 component, router, template, and asset conventions while preserving the host application's existing structure.

## Decide the boundary

- Use a controller for request/response endpoints and a LiveView for stateful server-rendered interaction.
- Reuse and compose the application's existing components before proposing another abstraction.
- Inspect the existing router scope before adding a route. A scope alias already prefixes route modules; do not duplicate that namespace with a manual alias.
- Do not introduce `Phoenix.View`; modern Phoenix applications use components and verified routes.

## New component approval gate

Do not create a new function component or LiveComponent without explicit approval from the software engineer. Before requesting approval:

1. Search the existing shared components and page-local helpers for a suitable implementation.
2. Explain why composing, extending, or reusing them does not fit.
3. Define the proposed component's single responsibility, location, attributes, slots, and expected reuse.
4. Wait for explicit approval before adding the component.

When approved, use a function component with explicit `attr` and `slot` contracts by default. Use a LiveComponent only when isolated state, event targeting, or component lifecycle is necessary. This gate does not prevent using or extending an existing component within its established responsibility.

## Phoenix 1.8 components

- Begin LiveView templates with `<Layouts.app flash={@flash} ...>` and pass every assign required by the host layout.
- Keep `<.flash_group>` inside the layouts module.
- Use the imported `<.icon>` component rather than calling an icon library module directly.
- Use the application's imported `<.input>` component when available. Supplying a custom `class` replaces its default classes, so provide the complete styling intentionally.
- Build nested component forms with `Phoenix.Component.inputs_for/1`; do not reintroduce legacy `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` APIs.
- Inspect `CoreComponents` and nearby feature components before creating new markup. Reuse a component only when its semantic contract, heading level, slots, DOM contract, and styling responsibility fit the new region; do not force reuse through incorrect headings or extensive overrides.
- When one page contains several substantial, conceptually independent sections that are not reused elsewhere, define them as function components in a `components.ex` file beside that page. Keep the page template as a semantic composition of those sections, and keep section-specific child markup inside its owning component.
- Promote a page-local component to `CoreComponents` or shared HTML helpers only after multiple pages genuinely reuse it. Name local components for the content responsibility or purpose they render, such as `toolkit_introduction`, not for their container tag or visual styling.
- Put shared imports and aliases in the web module's `html_helpers` block when they genuinely apply to all HTML modules.

## HEEx rules

- Use `~H` and `.html.heex`, never legacy `~E` templates.
- Give forms, controls, stream containers, hook roots, and other test targets stable unique DOM IDs.
- Render markup collections with `:for` on the repeated HTML or component element, such as `<li :for={item <- @items}>`. For streams, put `:for` on the child inside the stable `phx-update="stream"` container. Do not wrap repeated markup in a block-style `<%= for ... do %>` expression.
- Use `<%!-- --%>` for template comments.
- Use `{expression}` for attribute interpolation and ordinary values in tag bodies. Prefer `:if` on an element for a single conditional element; use `<%= ... %>` for multi-branch block constructs such as `case` and `cond`.
- Use `cond` or `case` for multiple branches; Elixir has no `else if` syntax.
- Express multiple or conditional classes as a list: `class={["base", @active && "active"]}`.
- Add `phx-no-curly-interpolation` to a parent that displays literal braces in code snippets.
- Choose HTML5 elements by document meaning: use `header`, `nav`, `main`, `section`, `article`, `aside`, `footer`, and lists when their semantics match the content. Reserve `div` and `span` for layout or decoration when no semantic element fits, and mark purely decorative elements with `aria-hidden="true"`.
- Do not replace generic wrappers mechanically with landmarks. Each semantic region must have a real purpose and, when required, an accessible heading or label.

## Semantics, accessibility, and page metadata

- Use one `main` landmark and one meaningful `h1` for a page. Preserve heading order and choose semantic elements such as `nav`, `section`, `article`, `aside`, `header`, `footer`, lists, tables, `figure`, and `time` according to content meaning.
- Set a meaningful `page_title` during LiveView mount or parameter handling and keep the page `h1` consistent with it. Provide a meta description through the established layout API when the page has useful descriptive copy.
- Give informative images descriptive `alt` text and decorative images `alt=""`. Use links for navigation and buttons for actions; label icon-only controls with an accessible name.
- Render dates with a machine-readable `datetime` value when using `time`, and use descriptive link text rather than generic phrases.

## Frontend assets

- Keep JavaScript and CSS in the configured `app.js` and `app.css` entrypoints. Import dependencies through those entrypoints instead of adding ad-hoc external or inline tags to layouts.
- For Tailwind CSS v4 projects generated by Phoenix, preserve the existing `@import "tailwindcss" source(none)` and `@source` declarations. Do not add a Tailwind config or use `@apply` unless the repository already established that pattern.
- Reuse the application's design language and component primitives. Include responsive, focus, loading, hover, and reduced-motion behavior where the interaction needs them.

## Verification

- Check route ordering and verified-route compilation.
- Render the component or page and test stable IDs and observable outcomes.
- Run the repository's formatter, focused tests, and completion check.
