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

Test valid changes, validation errors, database constraints, association behavior, and query shape. For scoped resources, include own-resource, other-user/tenant, missing-resource, and explicit admin/system cases. Verify rejected operations do not mutate data.
