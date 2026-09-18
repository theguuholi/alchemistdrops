---
name: phoenix-authentication
description: Use when adding or changing Phoenix authentication, authorization, protected routes, live_session placement, current_scope handling, or scoped context operations.
---

# Phoenix Authentication

Enforce authentication and authorization at routing and context boundaries. Treat `current_scope` as the caller's identity and access boundary, not as a display convenience.

## Classify the route first

Inspect the existing router and authentication module before editing. Reuse existing pipelines and `live_session` blocks; never duplicate a `live_session` name.

- Public browser-facing controller routes use the browser pipeline; API routes follow the application's API authentication policy.
- LiveViews that may use an optional signed-in user belong in the existing session that mounts the current scope, when the application defines one.
- Browser controller routes requiring login use the existing browser plus authentication pipeline/scope.
- LiveViews requiring login additionally belong in the existing authenticated `live_session` with its authentication `on_mount` callback.
- Admin or role-protected routes belong in the application's existing role-specific pipeline/session. Authentication alone does not grant authorization.
- Redirect signed-in users away from login or registration through the existing router plug rather than ad-hoc LiveView redirects.

When adding a route, state which pipeline, scope, and `live_session` it uses and why.

## Use `current_scope`

- Phoenix auth generators assign `current_scope`; they do not create a separate `current_user` assign.
- Inspect the generated scope struct and derive its actor from that field. In the standard user-auth setup, use `@current_scope.user` in LiveViews and templates.
- Pass `current_scope` as the first argument to scoped context functions.
- Scope list, get, create, update, and delete operations. Fetching by a bare resource ID before checking ownership can leak data.
- Set ownership fields such as `user_id` from the trusted scope, never from submitted params.
- Pass the scope to the root layout when it expects it.

For jobs or system operations without a socket scope, define an explicit trusted system/admin API rather than fabricating a user scope or silently bypassing authorization.

## Diagnose scope failures

If `current_scope` is missing or the wrong user appears:

1. Confirm the route is inside the intended pipeline and existing `live_session`.
2. Confirm the session uses the correct `on_mount` callback.
3. Confirm the LiveView passes `current_scope` to the layout and context.
4. Confirm the query filters ownership or applies the intended role policy.

## Verification

Test the authorized case plus anonymous, wrong-user, and wrong-role cases that apply. Assert redirects or not-found/forbidden outcomes and verify that failed requests do not mutate data.
