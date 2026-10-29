---
name: elixir
description: >-
  Base Elixir conventions. Use when writing or reviewing Elixir, Ecto, Phoenix, LiveView, or Mix
  projects.
---

# Elixir conventions

- Follow these guidelines unless project-specific instructions or conventions say otherwise.
- Read `AGENTS.md`, `mise.toml`, `.mise.toml`, `.tool-versions`, `mix.exs`, and nearby code
  before editing; use `mise current elixir erlang` to confirm the active versions.
- Use changesets and database constraints for validation and invariants.
- Keep Ecto queries portable across the project's database adapters; use aggregate queries instead
  of preloading associations only to count them.
- Define composed Ecto queries separately, then pass them to `Repo` functions. Use direct calls
  for simple operations such as `Repo.get/2` and `Repo.get_by/2`:

  ```elixir
  query =
    from project in Project,
      where: project.organization_id == ^organization_id,
      order_by: [asc: project.name]

  Repo.all(query)
  ```

- Return explicit `{:ok, value}` and `{:error, reason}` results for expected failures.
- Prefer direct calls over pipelines when only one transformation is made.
- Keep background jobs idempotent. When the job system supports transactional enqueueing, persist
  related state and enqueue the job in the same transaction.
- Avoid new dependencies when the standard library or an existing dependency is sufficient.
- Before adding a dependency, check Hex or its official source for the latest available stable
  release and use it unless project-specific compatibility constraints require another version.

## Phoenix

- Prefer project generators and existing context, schema, component, and test patterns.
- Generate migrations with the project's Ecto generator first, then modify the generated migration
  instead of creating migration files manually.
- Respect the project's domain and data-access boundaries; keep controllers focused on HTTP
  concerns rather than embedding business logic or complex queries.

## LiveView

- Keep LiveViews focused on presentation and event orchestration.
- Mutate streams only after successful operations.

## Validation

- Write focused tests for success, failure, constraints, boundaries, and race-prone transitions.
- After edits, run `mix format --check-formatted`, focused tests, and the project's validation alias
  such as `mix precommit`. If no comprehensive alias exists, also run
  `mix compile --warnings-as-errors`.
