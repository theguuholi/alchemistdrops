---
name: ecto-development
description: Use when adding or reviewing Ecto schemas, migrations, queries, changesets, associations, ownership boundaries, seeds, or data-integrity tests.
---

# Ecto Development

Enforce invariants at the changeset and database layers, and enforce ownership at the context/query boundary.

## Schema and changeset

- Use `:string` in `Ecto.Schema` for both varchar and text-backed string columns; the migration chooses `:string` or `:text` storage.
- Cast only user-editable fields. Set trusted ownership or system fields such as `user_id`, status transitions, and audit values explicitly from trusted context.
- Access changeset data with `Ecto.Changeset.get_field/2`; do not use struct-style Access syntax on changesets.
- Do not pass unsupported options such as `allow_nil` to `validate_number/3`; validations run only for present non-nil changes unless presence is separately required.
- Mirror important uniqueness and referential invariants with database constraints and translate them through changeset constraint functions.

## Schema documentation and tests

- Give every schema module an ExDoc-compatible `@moduledoc` that explains what the schema represents, why it matters to the domain, and its principal invariants and relationships. Do not use `@moduledoc false` for domain schemas.
- Define and document `@type t :: %__MODULE__{...}` for every schema. Include the schema's real persisted and construction states, including `nil` where the database or lifecycle permits it.
- Use documented domain types for schema fields whose domain meaning, nullability, or lifecycle state matters, such as statuses, identifiers, money values, timestamps, and external references. Reference those field types from `t()`; avoid aliases that merely rename a primitive without adding useful meaning.
- Give every public changeset function an ExDoc `@doc` that states its purpose. When the project includes `:ex_doc`, or the user explicitly requests executable documentation, add `iex>` examples and `doctest SchemaModule` to the schema's test module.
- Give every public changeset function a precise spec such as `@spec changeset(t(), map()) :: Ecto.Changeset.t()`. Context functions that accept or return schemas must reference `Schema.t()` in their specs.
- Database-backed doctests run from a test module using the project's `DataCase` and SQL Sandbox. Keep examples self-contained and generate deterministic unique values so they remain isolated.
- Create a dedicated `*_test.exs` module for every schema. Cover the valid changeset and every distinct observable behavior: each required field, validation and exact boundary, normalization, database constraint, declared association, default, protected/non-cast field, and public changeset variant. Internal branches with identical public results do not require duplicate cases.
- Test every declared database constraint both as a translated changeset error and by proving the database rejects an invalid direct operation. Keep exhaustive schema tests even when context tests cover the same happy path.

## Context and ownership

- Keep persistence and business validation in context functions rather than templates or controllers.
- For user-scoped resources, accept `current_scope` first and apply it to list, get, create, update, and delete operations.
- Query ownership before returning the record. Avoid fetching globally by ID and checking ownership afterward when that reveals existence or risks a missed check.
- Derive foreign ownership fields from the trusted scope, never submitted params.
- Give system/admin bypasses separate explicit APIs with tests; do not silently disable scope filters.

## Queries and associations

- Preload associations before templates or serializers access them; avoid hidden per-row queries.
- Select only the fields and preloads needed for the caller when result volume matters.
- Use composable query functions for filters and authorization boundaries.
- Import `Ecto.Query` and required helpers explicitly in seeds or standalone data scripts.

## Migrations

- Add foreign keys, nullability, indexes, and database constraints that match the domain invariants.
- Add unique indexes for uniqueness guarantees; use composite indexes when uniqueness is scoped by an owner or tenant.
- Choose `on_delete` behavior deliberately rather than relying on an accidental default.
- Keep migrations reversible when practical. For irreversible data transformations, document the recovery path and verify a backup or rollback strategy before execution.
- Review the target environment and database before migrate, rollback, reset, or drop operations.

## Verification

When ExDoc is present, run schema doctests. Run dedicated schema tests for valid changes, validation errors, database constraints, association behavior, and query shape. For scoped resources, include own-resource, other-user/tenant, missing-resource, and explicit admin/system cases. Verify rejected operations do not mutate data.
