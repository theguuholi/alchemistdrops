# Codebase Skill Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the AlchemistDrops codebase into conformance with the repository's Elixir, Ecto, Phoenix, authentication, LiveView, LiveView testing, and JavaScript hook skills without changing product behavior.

**Architecture:** Preserve existing context and web boundaries, then correct documented violations at their current ownership layer. Work from narrow tests to the full completion gates, keeping public APIs, routes, persistence behavior, ordering, and rendered behavior compatible.

**Tech Stack:** Elixir 1.18, Phoenix 1.8, LiveView 1.1, Ecto, PostgreSQL, ExUnit, ExDoc doctests, Dialyzer, Vitest, and jsdom.

**Spec:** `AGENTS.md` and `.agents/skills/*/SKILL.md`

## Global Constraints

- Preserve all existing public behavior and APIs unless a failing regression test proves a skill violation requires a correction.
- Do not add dependencies or change database structure.
- Keep authentication in the existing router pipelines and `live_session` blocks.
- Use contexts for business and persistence rules; keep LiveViews as orchestration layers.
- Run `mix precommit` and `npm run test --prefix assets` before completion.

---

### Task 1: Ecto schema contracts

**Files:**
- Modify: `lib/alchemistdrops/{accounts,courses,enrollments,payments,posts}/**/*.ex`
- Create or modify: `test/alchemistdrops/{accounts,courses,enrollments,payments,posts}/**/*_test.exs`

**Interfaces:**
- Consumes: Existing schemas, changesets, migrations, and fixture APIs.
- Produces: Documented schema `t()` types, precise changeset specs, doctests, and dedicated schema coverage.

- [ ] Add a domain-focused `@moduledoc`, documented field types, `@type t`, and changeset `@spec` declarations to each schema.
- [ ] Add deterministic `iex>` examples for public changeset functions that can run under `DataCase`.
- [ ] Add `doctest SchemaModule` and cover required fields, boundaries, normalization, constraints, defaults, protected fields, associations, and public changeset variants.
- [ ] Run `mix test test/alchemistdrops/accounts test/alchemistdrops/courses test/alchemistdrops/enrollments test/alchemistdrops/payments test/alchemistdrops/posts` and retain the passing output.

Example contract shape:

```elixir
@typedoc "A persisted or newly built course record."
@type t :: %__MODULE__{id: Ecto.UUID.t() | nil, title: String.t() | nil}

@doc "Builds a validated course changeset."
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

### Task 2: Context and general Elixir API contracts

**Files:**
- Modify: `lib/alchemistdrops/*.ex`
- Modify: `lib/alchemistdrops/{accounts,courses,enrollments,payments,posts}/**/*.ex`
- Modify: Corresponding context test modules under `test/alchemistdrops/`

**Interfaces:**
- Consumes: Existing public context functions and domain schema types from Task 1.
- Produces: Accurate module documentation, public function documentation, doctests, and typespecs without API changes.

- [ ] Replace generic context module descriptions with domain-boundary documentation.
- [ ] Add precise specs using concrete schema types and actual success/error results for every public context function.
- [ ] Add deterministic doctest examples for public APIs; use test adapters for side effects.
- [ ] Run focused context tests and `mix dialyzer`.

Example context contract shape:

```elixir
@doc "Returns the published courses visible to anonymous visitors."
@spec list_published_courses() :: [Course.t()]
def list_published_courses do
  # existing implementation remains unchanged
end
```

### Task 3: Phoenix, authentication, and LiveView boundaries

**Files:**
- Modify: `lib/alchemistdrops_web/router.ex`
- Modify: `lib/alchemistdrops_web/user_auth.ex`
- Modify: `lib/alchemistdrops_web/live/**/*.{ex,html.heex}`
- Modify: Corresponding tests under `test/alchemistdrops_web/live/`

**Interfaces:**
- Consumes: Existing router sessions, context APIs, component helpers, and templates.
- Produces: Existing routes and behavior with context-owned domain logic, `current_scope` propagation, semantic HEEx, stable IDs, URL-driven filters, and observable LiveView tests.

- [ ] Audit every route against the existing optional-user, authenticated-user, and admin sessions without moving correct routes.
- [ ] Move only proven business/query logic out of callbacks into the responsible context.
- [ ] Ensure templates use `Layouts.app`, semantic landmarks, mobile-first structure, and stable IDs for controls and test targets.
- [ ] Rewrite raw-HTML LiveView assertions as `has_element?`, `element`, redirect, patch, persistence, or focused LazyHTML assertions.
- [ ] Organize LiveView tests by callback with Gherkin scenario names and test authorized, anonymous, wrong-role, invalid, empty, and navigation outcomes where applicable.
- [ ] Run each affected LiveView test file, then all `test/alchemistdrops_web/live` tests.

Example interaction proof:

```elixir
view |> element("#resource-save", "Save") |> render_click()
assert has_element?(view, "#flash-info", "Saved successfully")
```

### Task 4: JavaScript hook boundary

**Files:**
- Inspect or modify: `assets/js/app.js`
- Inspect or modify: `assets/js/hooks.js`
- Inspect or modify: `assets/js/hooks/Mermaid/*`
- Modify: LiveView hook markup tests when needed.

**Interfaces:**
- Consumes: Existing `Mermaid` hook registry and LiveSocket initialization.
- Produces: The same rendered diagrams with explicit lifecycle cleanup, edge-case tests, and verified hook markup.

- [ ] Verify the central registry merges after colocated hooks and preserves CSRF, fallback, and topbar behavior.
- [ ] Verify hook ownership, idempotent updates, stale async protection, missing/malformed input handling, theme changes, and cleanup.
- [ ] Add only missing Vitest/jsdom cases and matching LiveView hook-contract assertions.
- [ ] Run `PATH="/Users/gustavooliveira/.asdf/shims:$PATH" npm run test --prefix assets`.

### Task 5: Completion proof and PR

**Files:**
- Review: all files changed by Tasks 1-4.

**Interfaces:**
- Consumes: Passing focused checks from every task.
- Produces: A reviewable branch and pull request with no unrelated changes.

- [ ] Run `mix format --check-formatted`, `mix precommit`, the JavaScript suite, and `git diff --check`.
- [ ] Review the diff for behavior changes, duplicated documentation, stale instruction files, and missing tests.
- [ ] Commit by coherent domain boundary and push `codex/extract-agent-skills`.
- [ ] Update PR #29 with the completed codebase refactor and verification evidence.
