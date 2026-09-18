# AlchemistDrops agent instructions

AlchemistDrops is an Elixir 1.18 application built with Phoenix 1.8, LiveView 1.1, Ecto, Tailwind CSS 4, and PostgreSQL.

## Project facts

- Use the existing `Req` dependency for HTTP requests. Do not add HTTPoison, Tesla, or direct `:httpc` usage.
- Preserve the existing router pipelines and `live_session` blocks. The application has optional-user, authenticated-user, and admin sessions; inspect `lib/alchemistdrops_web/router.ex` before placing routes.
- Derive the signed-in user from `current_scope`; the project does not assign `current_user` separately.
- Register shared JavaScript hooks through `assets/js/hooks.js`; `assets/js/app.js` merges them with colocated hooks.
- Run `mix precommit` before reporting Elixir/Phoenix work complete.
- When assets JavaScript changes, also run `npm run test --prefix assets`; `mix precommit` does not execute the Vitest suite.

## Skill routing

Read every applicable skill before changing code. Tasks often require more than one skill.

- Use `$elixir-development` for Elixir modules, OTP, concurrency, Mix commands, and general Elixir code review.
- Use `$phoenix-development` for Phoenix routes, function components, HEEx, layouts, inputs, icons, Tailwind, and frontend assets.
- Use `$phoenix-authentication` for authentication, authorization, protected routes, `live_session`, `current_scope`, and scoped context APIs.
- Use `$phoenix-liveview` for LiveViews, navigation, socket state, streams, events, LiveComponents, and forms.
- Use `$phoenix-js-hooks` whenever adding or changing `phx-hook`, colocated hooks, `assets/js` hook code, client-owned DOM, or client/server events.
- Use `$phoenix-liveview-testing` for LiveView tests, HEEx selectors, form interactions, navigation, stream assertions, and hook markup integration.
- Use `$ecto-development` for schemas, migrations, queries, changesets, associations, ownership fields, seeds, and data-integrity tests.

## Working agreement

- Follow the user's requested scope and preserve unrelated changes.
- Prefer existing project patterns and dependencies.
- Add stable DOM IDs to interactive elements and test targets.
- Run the narrowest relevant checks while iterating, then the project completion checks above.
