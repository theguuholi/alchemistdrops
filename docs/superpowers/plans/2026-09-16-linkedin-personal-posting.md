# LinkedIn Personal Posting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an admin-only workflow that generates an editable LinkedIn post in the article's language and publishes it to one connected personal profile only after confirmation.

**Architecture:** A new `Alchemistdrops.Social` context owns connection and share state. Focused OpenRouter and LinkedIn clients sit behind application-configured behaviours, while an admin OAuth controller and the existing post form LiveView provide connection, preview, editing, confirmation, and status UI. Publication remains synchronous and uses atomic database state transitions to reduce duplicate submissions.

**Tech Stack:** Elixir 1.18, Phoenix 1.8, LiveView 1.1, Ecto/PostgreSQL, Req 0.5, Plug.Crypto, ExUnit, Req.Test.

**Spec:** `docs/superpowers/specs/2026-09-16-linkedin-personal-posting-design.md`

## Global Constraints

- Target one personal LinkedIn profile; organization pages are out of scope.
- Preview and explicit confirmation are mandatory before publication.
- Generated text must use the article's predominant language and include its public URL.
- LinkedIn text must not exceed 3,000 characters.
- No automatic publication, scheduling, analytics, generated images, other networks, republication, or job queue.
- Reuse `Req`; add no dependency for HTTP, encryption, or background work.
- Existing article create/update/read flows must work when LinkedIn is unconfigured.
- Tests must not call OpenRouter or LinkedIn over the network.

---

### Task 1: Social persistence and encrypted connection tokens

**Files:**
- Create: `priv/repo/migrations/20260916130000_create_linkedin_social_tables.exs`
- Create: `lib/alchemistdrops/social/linkedin_connection.ex`
- Create: `lib/alchemistdrops/social/linkedin_post_share.ex`
- Create: `lib/alchemistdrops/social/token_cipher.ex`
- Create: `test/alchemistdrops/social/token_cipher_test.exs`
- Create: `test/alchemistdrops/social/linkedin_schemas_test.exs`
- Modify: `config/test.exs`

**Interfaces:**
- Produces: `TokenCipher.encrypt/1 :: binary() -> {:ok, binary()} | {:error, atom()}`.
- Produces: `TokenCipher.decrypt/1 :: binary() -> {:ok, binary()} | {:error, atom()}`.
- Produces: `LinkedInConnection.changeset/2` with the singleton id `"personal"`.
- Produces: `LinkedInPostShare.generation_changeset/2`, `edit_changeset/2`, and `status_changeset/2`.

- [ ] **Step 1: Write failing cipher and schema tests**

Cover encrypted round-trip, wrong-key rejection, required connection fields, valid share statuses, the 3,000-character limit, and `edited_text` validation. Configure a deterministic test key:

```elixir
config :alchemistdrops, :linkedin_token_encryption_key, "linkedin-test-encryption-key"
```

- [ ] **Step 2: Run tests and verify the missing modules fail**

Run: `mix test test/alchemistdrops/social/token_cipher_test.exs test/alchemistdrops/social/linkedin_schemas_test.exs`

Expected: compilation failure because the social schemas and cipher do not exist.

- [ ] **Step 3: Add the migration and schemas**

Create a singleton `linkedin_connections` row keyed by string id `personal`, containing `member_urn`, `access_token_ciphertext`, and `expires_at`. Create `linkedin_post_shares` with a binary id, unique `post_id` foreign key, `status`, `language`, `generated_text`, `edited_text`, `linkedin_post_urn`, `published_at`, and `error_message`. Use `Ecto.Enum` values `draft`, `publishing`, `published`, and `failed`.

- [ ] **Step 4: Implement authenticated token encryption**

Derive a 32-byte key with `:crypto.hash(:sha256, configured_key)` and use `Plug.Crypto.MessageEncryptor` with the AAD `"linkedin-access-token"`. Return `{:error, :encryption_key_not_configured}` for a missing key and `{:error, :invalid_token}` for failed decryption.

- [ ] **Step 5: Run focused tests**

Run: `mix test test/alchemistdrops/social/token_cipher_test.exs test/alchemistdrops/social/linkedin_schemas_test.exs`

Expected: all tests pass.

- [ ] **Step 6: Commit the persistence slice**

```bash
git add priv/repo/migrations/20260916130000_create_linkedin_social_tables.exs lib/alchemistdrops/social test/alchemistdrops/social config/test.exs
git commit -m "feat: add LinkedIn social persistence"
```

### Task 2: Language-preserving OpenRouter content generator

**Files:**
- Create: `lib/alchemistdrops/social/content_generator.ex`
- Create: `lib/alchemistdrops/social/open_router_content_generator.ex`
- Create: `test/alchemistdrops/social/open_router_content_generator_test.exs`
- Modify: `config/config.exs`
- Modify: `config/test.exs`

**Interfaces:**
- Produces behaviour callback `ContentGenerator.generate(post, article_url) :: {:ok, %{language: binary(), text: binary()}} | {:error, term()}`.
- Produces `OpenRouterContentGenerator.generate/2` implementing that callback.
- Consumes `%Alchemistdrops.Posts.Post{title: title, body: body}` and an absolute article URL.

- [ ] **Step 1: Write failing Req.Test-backed generator tests**

Stub OpenRouter responses and assert that the request includes title, body, URL, same-language instructions, no-invented-facts instructions, and a JSON-only response requirement. Cover valid Portuguese and English results, fenced JSON, missing URL, empty fields, malformed JSON, content above 3,000 characters, non-200 responses, and transport errors.

- [ ] **Step 2: Run the generator test and verify failure**

Run: `mix test test/alchemistdrops/social/open_router_content_generator_test.exs`

Expected: compilation failure because `OpenRouterContentGenerator` does not exist.

- [ ] **Step 3: Implement the behaviour and production generator**

Use the existing `:openrouter_api_key` setting, the current OpenRouter chat endpoint, and application-configured `:openrouter_req_options` merged into `Req.post/2`. Parse either raw JSON or a single JSON code fence into `%{language: language, text: text}`. Trim values, require the exact article URL in `text`, and enforce `String.length(text) <= 3_000`.

- [ ] **Step 4: Configure dependency injection**

Set `config :alchemistdrops, :linkedin_content_generator, Alchemistdrops.Social.OpenRouterContentGenerator` and configure `Req.Test` options only in `config/test.exs`.

- [ ] **Step 5: Run focused tests**

Run: `mix test test/alchemistdrops/social/open_router_content_generator_test.exs`

Expected: all tests pass with no network access.

- [ ] **Step 6: Commit the generator slice**

```bash
git add lib/alchemistdrops/social/content_generator.ex lib/alchemistdrops/social/open_router_content_generator.ex test/alchemistdrops/social/open_router_content_generator_test.exs config/config.exs config/test.exs
git commit -m "feat: generate LinkedIn article previews"
```

### Task 3: LinkedIn API client and OAuth callback

**Files:**
- Create: `lib/alchemistdrops/social/linkedin_client.ex`
- Create: `lib/alchemistdrops/social/req_linkedin_client.ex`
- Create: `lib/alchemistdrops_web/controllers/linkedin_auth_controller.ex`
- Create: `test/alchemistdrops/social/req_linkedin_client_test.exs`
- Create: `test/alchemistdrops_web/controllers/linkedin_auth_controller_test.exs`
- Modify: `lib/alchemistdrops_web/user_auth.ex`
- Modify: `lib/alchemistdrops_web/router.ex`
- Modify: `test/alchemistdrops_web/user_auth_test.exs`
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`
- Modify: `config/test.exs`

**Interfaces:**
- Produces behaviour functions `authorization_url/1`, `exchange_code/1`, `fetch_profile/1`, and `publish/5`.
- `exchange_code/1` returns `{:ok, %{access_token: binary(), expires_in: non_neg_integer()}}`.
- `fetch_profile/1` returns `{:ok, %{member_urn: binary()}}`.
- `publish(access_token, member_urn, text, article_url, title)` returns `{:ok, %{post_urn: binary()}} | {:error, term()}`.
- Produces admin-only `GET /admin/linkedin/connect` and `GET /admin/linkedin/callback` routes.

- [ ] **Step 1: Write failing client tests**

Use `Req.Test` to assert OAuth query parameters include `openid profile w_member_social`, code exchange uses the configured redirect URI, userinfo maps the subject `abc123` to `urn:li:person:abc123`, and Posts API sends the required author, commentary, article source/title, public visibility, `Linkedin-Version`, and `X-Restli-Protocol-Version: 2.0.0`. Cover success, non-2xx, malformed bodies, and transport errors.

- [ ] **Step 2: Implement the LinkedIn behaviour and Req client**

Read client id, client secret, redirect URI, and API version from `config :alchemistdrops, :linkedin`. Merge `:linkedin_req_options` into every request so tests stay local. Normalize external failures to tagged errors without including access tokens.

- [ ] **Step 3: Write failing authentication and controller tests**

Verify guests redirect to login, normal users redirect home, admins receive an external authorization redirect, callback rejects missing/mismatched state, successful callback stores a connection through `Alchemistdrops.Social`, and OAuth errors return to the post form with a flash message. Assert the state is removed from the session after callback.

- [ ] **Step 4: Add an admin controller plug**

Implement `UserAuth.require_admin_user/2` using `conn.assigns.current_scope.user.role == :admin`, preserving the same login/home redirects as the admin LiveView hook. Add focused plug tests.

- [ ] **Step 5: Add OAuth routes and controller**

Create an admin controller pipeline with `:browser`, `:require_authenticated_user`, and `:require_admin_user`. The connect action stores a random state plus an internally generated return path. The callback uses `Plug.Crypto.secure_compare/2` for equal-length states, deletes state from the session, exchanges the code, fetches the member identity, and stores the encrypted connection.

- [ ] **Step 6: Add runtime configuration**

Read `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`, `LINKEDIN_REDIRECT_URI`, `LINKEDIN_API_VERSION`, and `LINKEDIN_TOKEN_ENCRYPTION_KEY` in `runtime.exs`. Missing values leave the integration disabled rather than preventing application startup.

- [ ] **Step 7: Run focused tests**

Run: `mix test test/alchemistdrops/social/req_linkedin_client_test.exs test/alchemistdrops_web/controllers/linkedin_auth_controller_test.exs test/alchemistdrops_web/user_auth_test.exs`

Expected: all tests pass.

- [ ] **Step 8: Commit the API/OAuth slice**

```bash
git add lib/alchemistdrops/social/linkedin_client.ex lib/alchemistdrops/social/req_linkedin_client.ex lib/alchemistdrops_web/controllers/linkedin_auth_controller.ex lib/alchemistdrops_web/user_auth.ex lib/alchemistdrops_web/router.ex test/alchemistdrops/social/req_linkedin_client_test.exs test/alchemistdrops_web/controllers/linkedin_auth_controller_test.exs test/alchemistdrops_web/user_auth_test.exs config/config.exs config/runtime.exs config/test.exs
git commit -m "feat: connect personal LinkedIn profile"
```

### Task 4: Social context generation and publication workflow

**Files:**
- Create: `lib/alchemistdrops/social.ex`
- Create: `test/alchemistdrops/social_test.exs`
- Create: `test/support/social_fakes.ex`
- Modify: `config/test.exs`

**Interfaces:**
- Produces `Social.get_connection/0`, `connected?/0`, and `store_connection/1`.
- Produces `Social.get_share/1`, `generate_share/2`, `update_share_text/2`, and `publish_share/2`.
- `generate_share(post, article_url)` returns `{:ok, %LinkedInPostShare{status: :draft}} | {:error, term()}`.
- `publish_share(post, article_url)` returns `{:ok, %LinkedInPostShare{status: :published}} | {:error, term()}`.

- [ ] **Step 1: Add configurable fake clients**

Create deterministic fake modules controlled by process messages for generated content and publish outcomes. Configure them as `:linkedin_content_generator` and `:linkedin_client` in test.

- [ ] **Step 2: Write failing context tests**

Cover encrypted connection upsert, expiry-aware `connected?/0`, draft creation/regeneration, preservation of a valid draft after generation failure, edited text persistence, publication using edited text, successful URN/timestamp persistence, failure state/error sanitization, retry from `failed`, rejection from `publishing`/`published`, and one share per article.

- [ ] **Step 3: Run tests and verify failure**

Run: `mix test test/alchemistdrops/social_test.exs`

Expected: compilation failure because `Alchemistdrops.Social` does not exist.

- [ ] **Step 4: Implement connection and draft operations**

Upsert the singleton connection with encrypted tokens and an expiry calculated from `expires_in`. `generate_share/2` calls the configured generator and upserts the article's draft only after validation succeeds. `update_share_text/2` only accepts drafts or failed shares.

- [ ] **Step 5: Implement atomic publication state changes**

Use one `Repo.update_all` constrained to `status in [:draft, :failed]` to claim the share as `publishing`. Decrypt the current valid token, call the configured client synchronously, then write either `published` plus URN/time or `failed` plus a sanitized error. Reject additional attempts while `publishing` or after `published`.

- [ ] **Step 6: Run focused tests**

Run: `mix test test/alchemistdrops/social_test.exs`

Expected: all tests pass.

- [ ] **Step 7: Commit the context slice**

```bash
git add lib/alchemistdrops/social.ex test/alchemistdrops/social_test.exs test/support/social_fakes.ex config/test.exs
git commit -m "feat: orchestrate LinkedIn publishing"
```

### Task 5: Admin LiveView preview, edit, confirm, and status UI

**Files:**
- Modify: `lib/alchemistdrops_web/live/admin/post_live/form.ex`
- Modify: `test/alchemistdrops_web/live/admin/post_live_test.exs`

**Interfaces:**
- Consumes `Social.connected?/0`, `get_share/1`, `generate_share/2`, `update_share_text/2`, and `publish_share/2`.
- Produces LiveView events `generate_linkedin`, `edit_linkedin_share`, and `publish_linkedin`.

- [ ] **Step 1: Write failing LiveView tests**

Cover no LinkedIn section for a new unsaved article; connect action when disconnected; generate action for a saved unchanged article; Portuguese preview rendering; persisted edits; explicit `data-confirm`; disabled generation when the post form has unsaved changes; loading labels; successful published state; failure message with retained text; retry for failed state; and no publish action after success.

- [ ] **Step 2: Run focused LiveView tests and verify failure**

Run: `mix test test/alchemistdrops_web/live/admin/post_live_test.exs`

Expected: failures because the LinkedIn controls and events do not exist.

- [ ] **Step 3: Add LiveView state and events**

On edit mount, assign connection status, existing share, a share form, and `linkedin_dirty?: false`. During article validation, derive dirty state from post changes. Generate only when connected and clean, persist text edits through the context, and publish only through the confirmed button event. Build the absolute public URL with `url(~p"/blog/#{post}")`.

- [ ] **Step 4: Render the focused LinkedIn section**

Add one un-nested section below the article form with a LinkedIn icon, connection/generation controls, editable textarea, detected language, status, and restrained success/error feedback. Use existing button/input components and `phx-disable-with`; use `data-confirm="Publish this post to your LinkedIn profile?"` on the final command.

- [ ] **Step 5: Run LiveView and social regression tests**

Run: `mix test test/alchemistdrops_web/live/admin/post_live_test.exs test/alchemistdrops/social_test.exs`

Expected: all tests pass.

- [ ] **Step 6: Commit the UI slice**

```bash
git add lib/alchemistdrops_web/live/admin/post_live/form.ex test/alchemistdrops_web/live/admin/post_live_test.exs
git commit -m "feat: confirm LinkedIn posts from admin"
```

### Task 6: Full verification and scope audit

**Files:**
- Modify only files required to fix failures introduced by Tasks 1-5.

**Interfaces:**
- Consumes all preceding deliverables.
- Produces a branch whose implementation and tests match the approved spec.

- [ ] **Step 1: Format only feature files**

Run `mix format` with the exact files changed by this plan. Do not format the pre-existing unrelated `about_live` files.

- [ ] **Step 2: Run focused feature tests**

Run: `mix test test/alchemistdrops/social_test.exs test/alchemistdrops/social test/alchemistdrops_web/controllers/linkedin_auth_controller_test.exs test/alchemistdrops_web/live/admin/post_live_test.exs test/alchemistdrops_web/user_auth_test.exs`

Expected: all tests pass.

- [ ] **Step 3: Run the full test suite**

Run: `mix test`

Expected: all tests pass.

- [ ] **Step 4: Run static checks that are not blocked by baseline formatting**

Run: `mix compile --warnings-as-errors`, `mix credo --strict`, `mix sobelow --skip -i Config.CSP --config`, and `mix dialyzer`.

Expected: each command exits successfully. Also run `mix format --check-formatted`; if it reports only the two documented pre-existing `about_live` files, report that baseline limitation without modifying them.

- [ ] **Step 5: Audit the diff against the spec**

Confirm the diff contains no job dependency, scheduling, analytics, organization publishing, generated images, or unrelated refactors. Confirm no secrets or access tokens appear in source, logs, fixtures, or rendered HTML.

- [ ] **Step 6: Commit any verification-only fixes**

```bash
git add config/config.exs config/runtime.exs config/test.exs docs/superpowers lib/alchemistdrops/social.ex lib/alchemistdrops/social lib/alchemistdrops_web/controllers/linkedin_auth_controller.ex lib/alchemistdrops_web/live/admin/post_live/form.ex lib/alchemistdrops_web/router.ex lib/alchemistdrops_web/user_auth.ex priv/repo/migrations/20260916130000_create_linkedin_social_tables.exs test/alchemistdrops/social_test.exs test/alchemistdrops/social test/alchemistdrops_web/controllers/linkedin_auth_controller_test.exs test/alchemistdrops_web/live/admin/post_live_test.exs test/alchemistdrops_web/user_auth_test.exs test/support/social_fakes.ex
git commit -m "test: verify LinkedIn publishing workflow"
```
