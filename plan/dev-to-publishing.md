# DEV.to Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an administrator publish a locally published AlchemistDrops article to DEV.to once, then update that same DEV.to article without creating duplicates.

**Architecture:** A focused `Alchemistdrops.Posts.DevToPublisher` subcontext builds the DEV.to payload and delegates HTTP to a configured Req-backed client. The parent `Posts` context coordinates the external sync and persists the returned DEV.to identity on the post, while the existing admin post LiveView exposes the action and feedback.

**Tech Stack:** Elixir 1.18, Phoenix 1.8, LiveView 1.1, Ecto/PostgreSQL, Req, ExUnit, Phoenix.LiveViewTest.

**Spec:** Bounded design approved in conversation on 2026-09-22.

## Global Constraints

- Create and update DEV.to articles through the official `POST /api/articles` and `PUT /api/articles/:id` endpoints.
- Send both `canonical_url` and a visible Markdown footer pointing to the AlchemistDrops original.
- Never create a second DEV.to article after a local post has a stored DEV.to article ID.
- Use the existing Req dependency; add no HTTP dependency.
- Keep DEV.to credentials in runtime configuration, never in the database or source.
- Show the action only for locally published posts inside the existing admin-only LiveView.
- Follow strict red-green-refactor TDD and run `mix precommit` before completion.

---

### Task 1: Persist DEV.to publication identity

**Files:**
- Create: `priv/repo/migrations/20260922000000_add_dev_to_fields_to_posts.exs`
- Modify: `lib/alchemistdrops/posts/post.ex`
- Test: `test/alchemistdrops/posts/post_test.exs`

**Interfaces:**
- Produces: `Post.dev_to_article_id`, `Post.dev_to_url`, and `Post.dev_to_synced_at` as system-owned nullable fields.
- Consumes: Existing `Post.t()` and editorial changesets.

- [ ] **Step 1: Write the failing schema test**

  Add a test proving ordinary draft changesets do not cast submitted DEV.to identity fields while the schema exposes nullable defaults.

- [ ] **Step 2: Run the schema test and verify RED**

  Run: `mix test test/alchemistdrops/posts/post_test.exs`

  Expected: failure because the DEV.to fields do not exist on `Post`.

- [ ] **Step 3: Add the reversible migration and schema fields**

  Add nullable `:bigint`, `:string`, and `:utc_datetime` columns. Add matching documented field types and entries in `Post.t()`, but do not add these system-owned fields to `cast/3`.

- [ ] **Step 4: Run the schema test and verify GREEN**

  Run: `mix test test/alchemistdrops/posts/post_test.exs`

  Expected: all post schema tests pass.

### Task 2: Add the DEV.to API boundary

**Files:**
- Create: `lib/alchemistdrops/posts/dev_to_publisher.ex`
- Create: `lib/alchemistdrops/posts/dev_to_publisher/req_client.ex`
- Create: `test/alchemistdrops/posts/dev_to_publisher_test.exs`
- Create: `test/alchemistdrops/posts/dev_to_publisher/req_client_test.exs`
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`
- Modify: `config/test.exs`

**Interfaces:**
- Consumes: `DevToPublisher.sync_article(Post.t(), canonical_url, keyword())` with a preloaded published post.
- Produces: `{:ok, %{article_id: pos_integer(), url: String.t()}}` or `{:error, reason}`.
- Uses: configured `:api_key`, `:base_url`, and `:http_client`; production client signature `request(keyword())`.

- [ ] **Step 1: Write failing create-payload tests**

  Prove the first sync uses `POST /api/articles`, sets `published: true`, copies title/summary/cover image, limits normalized tags to four, sets the canonical URL, and appends a language-aware visible original-article footer to `body_markdown`.

- [ ] **Step 2: Run the integration tests and verify RED**

  Run: `mix test test/alchemistdrops/posts/dev_to_publisher_test.exs`

  Expected: compilation failure because `Alchemistdrops.Posts.DevToPublisher` does not exist.

- [ ] **Step 3: Implement the minimum create flow**

  Build the JSON payload from the post and call the configured HTTP client with the required DEV.to API key and Accept/Content-Type headers. Normalize a 201 response containing numeric `id` and absolute `url` into the documented success tuple.

- [ ] **Step 4: Run the create tests and verify GREEN**

  Run: `mix test test/alchemistdrops/posts/dev_to_publisher_test.exs`

  Expected: create tests pass.

- [ ] **Step 5: Write failing update and error tests**

  Prove a post with `dev_to_article_id` uses `PUT /api/articles/:id`; missing credentials, transport failures, non-2xx responses, and malformed success bodies return safe errors without secrets.

- [ ] **Step 6: Run the integration tests and verify RED**

  Run: `mix test test/alchemistdrops/posts/dev_to_publisher_test.exs`

  Expected: update/error cases fail because only create success is implemented.

- [ ] **Step 7: Implement update and error normalization**

  Select the endpoint and success status from the stored article ID, preserve the response URL, and return stable error tuples for the LiveView.

- [ ] **Step 8: Test the Req wrapper**

  Test normalized successful and transport-error responses through a local Plug-based test endpoint or an injected Req adapter, then implement `Alchemistdrops.Posts.DevToPublisher.ReqClient.request/1` using `Req.request/1`.

- [ ] **Step 9: Configure runtime credentials**

  Add `DEV_TO_API_KEY` under `config :alchemistdrops, :dev_to`; retain `https://dev.to` as the default base URL and configure a deterministic fake client/key in tests.

- [ ] **Step 10: Run both API-boundary test files and verify GREEN**

  Run: `mix test test/alchemistdrops/posts/dev_to_publisher_test.exs test/alchemistdrops/posts/dev_to_publisher/req_client_test.exs`

  Expected: all DEV.to boundary tests pass.

### Task 3: Coordinate synchronization in the Posts context

**Files:**
- Modify: `lib/alchemistdrops/posts.ex`
- Test: `test/alchemistdrops/posts_test.exs`

**Interfaces:**
- Consumes: `Posts.publish_to_dev(Post.t(), canonical_url, keyword())`.
- Produces: `{:ok, Post.t()}` with DEV.to identity and a fresh `dev_to_synced_at`, or the integration error unchanged.
- Depends on: `DevToPublisher.sync_article/3` from Task 2.

- [ ] **Step 1: Write the failing persistence test**

  Prove a successful create response records the numeric article ID, remote URL, and sync timestamp on the local post.

- [ ] **Step 2: Run the focused context test and verify RED**

  Run: `mix test test/alchemistdrops/posts_test.exs --only dev_to`

  Expected: failure because `Posts.publish_to_dev/3` does not exist.

- [ ] **Step 3: Implement minimal context coordination**

  Preload taxonomy, call `DevToPublisher.sync_article/3`, and persist only trusted response fields with `Ecto.Changeset.change/2`.

- [ ] **Step 4: Write and verify failure/no-mutation tests**

  Prove an API failure leaves all local DEV.to fields unchanged, then run the tagged context tests.

- [ ] **Step 5: Run all Posts tests and verify GREEN**

  Run: `mix test test/alchemistdrops/posts_test.exs`

  Expected: all Posts context tests pass.

### Task 4: Add the admin Publish/Update DEV.to action

**Files:**
- Modify: `lib/alchemistdrops_web/live/admin/post_live/form.ex`
- Modify: `lib/alchemistdrops_web/live/admin/post_live/form.html.heex`
- Test: `test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

**Interfaces:**
- Consumes: existing published post assign and `Posts.publish_to_dev/3`.
- Produces: `publish-dev-to` event, publish/update button labels, a remote article link after success, and safe flash feedback.

- [ ] **Step 1: Write failing visibility tests**

  Prove drafts omit `#publish-dev-to`, published unsynced posts show “Publish on DEV.to,” and synced posts show “Update on DEV.to” plus `#dev-to-article-link`.

- [ ] **Step 2: Run the LiveView tests and verify RED**

  Run: `mix test test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

  Expected: selectors are absent.

- [ ] **Step 3: Implement the controls**

  Render stable IDs in the existing footer only when `@post.status == :published`, with `phx-disable-with` and the established button/link components.

- [ ] **Step 4: Write failing event success tests**

  Configure the deterministic fake client, click the button, and prove the post persists DEV.to identity, the label changes to update, the remote link appears, and the success flash is visible.

- [ ] **Step 5: Implement the event success path**

  Build the absolute canonical URL from the verified public blog route, delegate to `Posts.publish_to_dev/3`, refresh the post assign, and show create/update-specific feedback.

- [ ] **Step 6: Write failing event error tests**

  Prove API/configuration failure keeps the current post state and displays a non-secret error flash.

- [ ] **Step 7: Implement the event error path and verify GREEN**

  Run: `mix test test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

  Expected: all editorial LiveView tests pass.

### Task 5: Final migration and quality verification

**Files:**
- Modify only files required by failures found in this task.

**Interfaces:**
- Consumes: all deliverables from Tasks 1-4.
- Produces: a formatted, migrated, fully verified feature on branch `dev-to`.

- [ ] **Step 1: Verify migration reversibility in test**

  Run the normal test database migration path used by `mix test`; inspect migration status and ensure both `up/0` and `down/0` are defined without destructive data transformations.

- [ ] **Step 2: Run focused feature tests**

  Run: `mix test test/alchemistdrops/posts/dev_to_publisher_test.exs test/alchemistdrops/posts/dev_to_publisher/req_client_test.exs test/alchemistdrops/posts/post_test.exs test/alchemistdrops/posts_test.exs test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

  Expected: zero failures.

- [ ] **Step 3: Run the repository completion gate**

  Run: `mix precommit`

  Expected: formatter, compilation, tests, coverage, and static checks complete with exit status 0.

- [ ] **Step 4: Review the final diff**

  Confirm credentials are absent, the API key cannot appear in error output, only published posts expose the control, subsequent syncs use PUT, and unrelated files remain untouched.
