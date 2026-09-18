---
name: elixir-development
description: Use when writing or reviewing Elixir modules, OTP processes, concurrent enumeration, or Mix-based development workflows.
---

# Elixir Development

Write idiomatic Elixir that preserves immutability, avoids unsafe runtime behavior, and uses focused Mix commands for feedback.

## Language rules

- Access lists with pattern matching, `Enum.at/2`, or `List`; `list[index]` is invalid.
- Bind the result of `if`, `case`, and `cond` when it will be used later. Rebinding only inside the branch does not update the outer binding.
- Prefer one public production module per file; generated code and small test-only helpers may be reasonable exceptions.
- Access struct fields directly. For changesets, use `Ecto.Changeset.get_field/2` rather than Access syntax.
- Never call `String.to_atom/1` on user-controlled input.
- Name predicates with a trailing `?`; reserve `is_` names for guards.
- Prefer the standard `Date`, `Time`, `DateTime`, and `Calendar` APIs before adding a date dependency.

## OTP and concurrency

- Give `Registry`, `DynamicSupervisor`, and other named OTP children explicit names in their child specs.
- Place long-lived processes under a supervision tree. Use `Task` for bounded caller-owned work, `Task.Supervisor` when task lifecycle must be supervised independently, and a GenServer only when state or serialized coordination is required.
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure. Choose explicit concurrency and timeout behavior; use `timeout: :infinity` only when the caller can legitimately wait without a deadline.
- In tests, prefer supervised processes and unique names so cases remain isolated.

## Mix workflow

- Run `mix help <task>` before using an unfamiliar task or option.
- Start with the narrowest relevant test file or `mix test --failed`, then run the project's completion check.
- Set `MIX_ENV` deliberately when a task can affect persistent data.
- Treat `mix ecto.drop`, `mix ecto.reset`, rollbacks, and broad dependency cleanup as destructive operations requiring explicit authorization.
- Avoid `mix deps.clean --all` unless dependency artifacts are proven to be the cause.

## Review checklist

- User input cannot create atoms.
- Block results are bound outside the block.
- Long-lived processes are supervised and test-isolated.
- Concurrent work has deliberate timeout and back-pressure behavior.
- Verification uses the project's documented Mix task.
