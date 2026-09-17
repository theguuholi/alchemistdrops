# Blog Editorial Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing Markdown blog into a controlled editorial system with draft/published states, taxonomy, optional course conversion, complete SEO/discovery, a guided reading layout, and blueprint-style Mermaid diagrams.

**Architecture:** Keep `Alchemistdrops.Posts` as the persistence boundary, adding Category and Tag schemas plus explicit public/admin queries. Add a small article-presentation module that derives rendered HTML, a table of contents, and reading time without putting presentation logic in LiveViews. Public LiveViews consume only published/preloaded records; XML discovery is served through controllers; Mermaid remains a LiveView hook with an isolated JavaScript test suite.

**Tech Stack:** Elixir 1.18, Phoenix 1.8, LiveView 1.1, Ecto/PostgreSQL, MDEx, Tailwind CSS 4, Mermaid 11, Vitest + jsdom.

**Spec:** `docs/superpowers/specs/2026-09-17-blog-editorial-experience-design.md`

## Global Constraints

- Preserve existing slug generation, canonical slug routes, and legacy UUID redirects.
- Keep third-party distribution integrations outside this branch.
- Public blog LiveViews stay in the existing `live_session :current_user`; admin blog LiveViews stay in `live_session :required_admin_user`.
- Existing posts must remain public after migration by backfilling `status = 'published'` and `published_at = inserted_at`.
- The first release supports only `draft` and `published`; no scheduling.
- Newsletter capture/delivery, media uploads, revisions, autosave, full-text search, and analytics are out of scope.
- A published article requires title, slug, body, summary, language, and category; a draft may omit publication-only fields.
- One category per published article and at most five reusable tags per article.
- Course CTA is optional and appears only for a related published course.
- Follow TDD: add a failing focused test, observe the expected failure, implement the minimum behavior, and rerun the focused test before broader suites.
- Do not modify `mix.exs` coverage thresholds or coverage-ignore configuration.
- Do not include unrelated dirty files in commits.
- The known baseline contains two stale About-page assertion failures. Every focused blog test introduced here must pass; final reporting must distinguish these preexisting failures.

---

## File Structure

### New files

- `priv/repo/migrations/20260917090000_create_post_taxonomy.exs` — categories, tags, and the post/tag join table.
- `priv/repo/migrations/20260917090100_add_editorial_fields_to_posts.exs` — compatible post backfill and editorial foreign keys.
- `lib/alchemistdrops/posts/category.ex` — category schema and validation.
- `lib/alchemistdrops/posts/tag.ex` — tag schema and validation.
- `lib/alchemistdrops/posts/article.ex` — derived article HTML, TOC, reading time, and duplicate-title removal.
- `lib/alchemistdrops_web/controllers/blog_discovery_controller.ex` — sitemap and Atom endpoints.
- `test/alchemistdrops/posts/article_test.exs` — article presentation unit tests.
- `test/alchemistdrops_web/controllers/blog_discovery_controller_test.exs` — XML discovery tests.
- `test/alchemistdrops_web/live/admin/post_editorial_live_test.exs` — isolated editorial admin workflow tests.
- `assets/js/hooks/Mermaid/index.test.js` — Mermaid hook behavior tests.

### Existing files modified

- `lib/alchemistdrops/posts/post.ex` — editorial fields and associations.
- `lib/alchemistdrops/posts.ex` — publication workflow, taxonomy persistence, filters, related posts, and atomic views.
- `test/support/fixtures/posts_fixtures.ex` — explicit published/draft/category/tag fixtures.
- `test/alchemistdrops/posts_test.exs` — context and schema behavior.
- `lib/alchemistdrops_web/live/admin/post_live/form.ex` — editorial form and publish/unpublish actions.
- `lib/alchemistdrops_web/live/admin/post_live/index.ex` and `.html.heex` — status-aware admin listing.
- `lib/alchemistdrops_web/live/post_live/index.ex` and `.html.heex` — published filters, pagination, and redesigned cards.
- `lib/alchemistdrops_web/live/post_live/show.ex` and `.html.heex` — guided article experience and metadata.
- `test/alchemistdrops_web/live/post_live_test.exs` — public visibility, layout, CTA, related-post, and metadata tests.
- `lib/alchemistdrops_web/live/home_live/index.ex` and `.html.heex` — three recent published posts.
- `test/alchemistdrops_web/live/home_live_test.exs` — homepage article tests.
- `lib/alchemistdrops_web/components/layouts/root.html.heex` — article-aware SEO fields, language, JSON-LD, and brand title suffix.
- `lib/alchemistdrops_web/router.ex` — public XML pipeline/routes.
- `lib/alchemistdrops/markdown.ex` — safe shared helpers used by Article.
- `assets/js/hooks/Mermaid/index.js` — blueprint renderer, controls, theme rerender, and errors.
- `assets/css/app.css` — guided article and Mermaid blueprint styling.
- `assets/package.json` and `assets/package-lock.json` — JavaScript test runner.

---

### Task 1: Add editorial and taxonomy persistence

**Files:**
- Create: `priv/repo/migrations/20260917090000_create_post_taxonomy.exs`
- Create: `priv/repo/migrations/20260917090100_add_editorial_fields_to_posts.exs`
- Create: `lib/alchemistdrops/posts/category.ex`
- Create: `lib/alchemistdrops/posts/tag.ex`
- Modify: `lib/alchemistdrops/posts/post.ex`
- Modify: `test/support/fixtures/posts_fixtures.ex`
- Test: `test/alchemistdrops/posts_test.exs`

**Interfaces:**
- Produces: `%Post{status, published_at, summary, seo_title, seo_description, cover_image_url, cover_image_alt, language, category, tags, related_course}`.
- Produces: `Post.draft_changeset/2` and `Post.publish_changeset/2`.
- Produces: `Category.changeset/2`, `Tag.changeset/2`, and normalized slugs.
- Consumes: existing post slugs and `Courses.Course` IDs.

- [ ] **Step 1: Add failing schema and validation tests**

Add focused tests asserting defaults, associations, cover-alt validation, publication-only required fields, category/tag uniqueness, and a five-tag limit at the post boundary. Use explicit examples such as:

```elixir
test "publish_changeset requires summary, language, body, and category" do
  post = %Post{status: :draft, views: 0}
  changeset = Post.publish_changeset(post, %{title: "Draft", body: "", summary: ""})

  refute changeset.valid?
  assert %{body: ["can't be blank"], summary: ["can't be blank"], category: ["can't be blank"]} =
           errors_on(changeset)
end

test "draft_changeset accepts publication fields being absent" do
  changeset = Post.draft_changeset(%Post{}, %{title: "Work in progress"})
  assert changeset.valid?
  assert Ecto.Changeset.get_field(changeset, :status) == :draft
end
```

- [ ] **Step 2: Run the focused tests and observe failure**

Run: `mix test test/alchemistdrops/posts_test.exs`

Expected: FAIL because editorial fields, Category, Tag, and the two changeset functions do not exist.

- [ ] **Step 3: Implement migrations with compatibility backfill**

The taxonomy migration creates `post_categories`, `post_tags`, and `posts_tags`. The editorial migration adds scalar fields and the two nullable foreign keys. Backfill existing posts before setting the status default used for new rows:

```elixir
execute("UPDATE posts SET status = 'published', published_at = inserted_at")

create index(:posts, [:status, :published_at])
create index(:posts, [:category_id])
create index(:posts, [:related_course_id])
create unique_index(:posts_tags, [:post_id, :tag_id])
create unique_index(:post_categories, ["lower(name)"], name: :post_categories_lower_name_index)
create unique_index(:post_tags, ["lower(name)"], name: :post_tags_lower_name_index)
```

Explain in migration moduledocs/comments that the first migration preserves publication state while the second owns reusable taxonomy.

- [ ] **Step 4: Implement Category, Tag, and Post schema changes**

Use `Ecto.Enum` for status and explicit association deletion behavior. Keep slug generation intact. Draft validation requires only title/slug/status/views; publishing adds the publication contract:

```elixir
field :status, Ecto.Enum, values: [:draft, :published], default: :draft
field :published_at, :utc_datetime
field :summary, :string
field :seo_title, :string
field :seo_description, :string
field :cover_image_url, :string
field :cover_image_alt, :string
field :language, Ecto.Enum, values: [en: "en", pt_br: "pt-BR"], default: :en

belongs_to :category, Alchemistdrops.Posts.Category
belongs_to :related_course, Alchemistdrops.Courses.Course
many_to_many :tags, Alchemistdrops.Posts.Tag, join_through: "posts_tags", on_replace: :delete
```

Implement `validate_cover_alt/1` and `validate_length` limits exactly as specified. Do not cast `published_at`; the context owns it.

- [ ] **Step 5: Update fixtures to make publication intent explicit**

Keep legacy public tests stable by making `post_fixture/1` create a published post with a unique category and valid summary unless the caller overrides status. Add `draft_post_fixture/1`, `category_fixture/1`, and `tag_fixture/1`.

- [ ] **Step 6: Run migration and schema tests**

Run: `mix ecto.migrate && mix test test/alchemistdrops/posts_test.exs`

Expected: schema/migration tests PASS; context tests that still assume old `create_post/1` behavior may remain failing until Task 2.

- [ ] **Step 7: Commit only persistence files**

```bash
git add priv/repo/migrations/20260917090000_create_post_taxonomy.exs \
  priv/repo/migrations/20260917090100_add_editorial_fields_to_posts.exs \
  lib/alchemistdrops/posts/post.ex lib/alchemistdrops/posts/category.ex \
  lib/alchemistdrops/posts/tag.ex test/support/fixtures/posts_fixtures.ex \
  test/alchemistdrops/posts_test.exs
git commit -m "feat(blog): add editorial taxonomy model"
```

### Task 2: Implement publication workflow and public query boundary

**Files:**
- Modify: `lib/alchemistdrops/posts.ex`
- Modify: `test/alchemistdrops/posts_test.exs`

**Interfaces:**
- Consumes: `Post.draft_changeset/2`, `Post.publish_changeset/2`, Category, Tag.
- Produces: `create_post/1`, `update_post/2`, `publish_post/1`, `unpublish_post/1`.
- Produces: `list_admin_posts/0`, `list_published_posts/1`, `get_published_post_by_slug!/1`, `list_recent_published_posts/1`, `list_related_posts/2`, `list_categories_with_published_counts/0`.
- Produces: `increment_views/1` using atomic `Repo.update_all`.

- [ ] **Step 1: Write failing context tests**

Cover all visibility and transitions:

```elixir
test "public queries never expose drafts" do
  published = post_fixture(%{title: "Public"})
  draft = draft_post_fixture(%{title: "Private"})

  assert Enum.map(Posts.list_published_posts(), & &1.id) == [published.id]
  assert_raise Ecto.NoResultsError, fn -> Posts.get_published_post_by_slug!(draft.slug) end
end

test "publish_post stamps first publication and keeps it on later updates" do
  draft = draft_post_fixture(%{title: "Ready", body: "Body", summary: "Summary", category: category_fixture()})
  assert {:ok, published} = Posts.publish_post(draft)
  assert published.status == :published
  assert published.published_at

  first_published_at = published.published_at
  assert {:ok, updated} = Posts.update_post(published, %{title: "Ready again"})
  assert updated.published_at == first_published_at
end
```

Also test category/tag filter combinations, five-tag enforcement, case-insensitive taxonomy reuse, related-post ordering, course preloads, and concurrent atomic view increments.

- [ ] **Step 2: Run context tests and observe failure**

Run: `mix test test/alchemistdrops/posts_test.exs`

Expected: FAIL on missing public/admin functions and old non-atomic behavior.

- [ ] **Step 3: Add explicit public/admin query helpers**

Use a shared published scope:

```elixir
defp published_query do
  from p in Post,
    where: p.status == :published and not is_nil(p.published_at),
    order_by: [desc: p.published_at, desc: p.id],
    preload: [:category, :tags, :related_course]
end
```

`list_published_posts/1` accepts `:category`, `:tag`, `:page`, and `:page_size`, with bounded page size. Keep `list_posts/0` as a deprecated-compatible admin alias during this release, then update callers to explicit functions.

- [ ] **Step 4: Implement transactional taxonomy persistence**

Normalize form inputs through private helpers:

```elixir
defp normalize_tag_names(value) do
  value
  |> to_string()
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.uniq_by(&String.downcase/1)
end
```

Within `Ecto.Multi`, resolve or insert the category by case-insensitive name, resolve/upsert tags, preload associations for updates, and `put_assoc/3` before inserting/updating the post. Return changeset errors rather than raising for validation or uniqueness conflicts.

- [ ] **Step 5: Implement publish/unpublish and atomic views**

`publish_post/1` reloads associations, validates with `publish_changeset/2`, and sets `published_at` only when it is nil. `unpublish_post/1` sets status to draft but retains `published_at` so republishing does not rewrite the original date.

Replace the read-modify-write view increment with:

```elixir
from(p in Post, where: p.id == ^post.id)
|> Repo.update_all(inc: [views: 1])
```

- [ ] **Step 6: Run context tests**

Run: `mix test test/alchemistdrops/posts_test.exs`

Expected: PASS.

- [ ] **Step 7: Commit context behavior**

```bash
git add lib/alchemistdrops/posts.ex test/alchemistdrops/posts_test.exs
git commit -m "feat(blog): add publication workflow"
```

### Task 3: Build the article presentation model

**Files:**
- Create: `lib/alchemistdrops/posts/article.ex`
- Create: `test/alchemistdrops/posts/article_test.exs`
- Modify: `lib/alchemistdrops/markdown.ex`
- Modify: `test/alchemistdrops/markdown_test.exs`

**Interfaces:**
- Consumes: Markdown source and post title.
- Produces: `Article.build(post) :: %{html: String.t(), toc: list(), reading_minutes: pos_integer(), description: String.t()}`.
- Produces: TOC entries `%{level: 2 | 3, id: String.t(), label: String.t()}` matching rendered heading IDs.

- [ ] **Step 1: Write failing presentation tests**

Test a duplicate leading title, intentional later `h1`, h2/h3 extraction, inline markup in heading labels, minimum one-minute reading time, Portuguese/English text, nil body, and description fallback:

```elixir
test "removes only a leading h1 that duplicates the post title" do
  post = %Post{title: "A Practical Guide", body: "# A Practical Guide\n\nIntro\n\n## First section"}
  article = Article.build(post)

  refute article.html =~ "<h1"
  assert article.html =~ "<h2 id=\"first-section\""
  assert article.toc == [%{level: 2, id: "first-section", label: "First section"}]
end
```

- [ ] **Step 2: Run tests and observe failure**

Run: `mix test test/alchemistdrops/posts/article_test.exs test/alchemistdrops/markdown_test.exs`

Expected: FAIL because `Article` does not exist.

- [ ] **Step 3: Implement deterministic article derivation**

Strip only the first Markdown line when it is an `h1` whose normalized textual content equals the normalized post title. Render through `Markdown.to_html/1`. Extract h2/h3 IDs and labels from the generated HTML, stripping inline tags and decoding entities for labels. Calculate reading time with 220 words/minute and a minimum of one minute.

Keep `Markdown` focused on Markdown-to-HTML conversion; put article-specific behavior in `Article`.

- [ ] **Step 4: Run presentation tests**

Run: `mix test test/alchemistdrops/posts/article_test.exs test/alchemistdrops/markdown_test.exs`

Expected: PASS.

- [ ] **Step 5: Commit the presentation model**

```bash
git add lib/alchemistdrops/posts/article.ex lib/alchemistdrops/markdown.ex \
  test/alchemistdrops/posts/article_test.exs test/alchemistdrops/markdown_test.exs
git commit -m "feat(blog): derive article reading metadata"
```

### Task 4: Add the editorial admin workflow

**Files:**
- Modify: `lib/alchemistdrops_web/live/admin/post_live/form.ex`
- Modify: `lib/alchemistdrops_web/live/admin/post_live/index.ex`
- Modify: `lib/alchemistdrops_web/live/admin/post_live/index.html.heex`
- Create: `test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

**Interfaces:**
- Consumes: Posts publication/taxonomy APIs and `Courses.list_all_courses/0`.
- Produces: `save`, `publish`, and `unpublish` LiveView events.
- Produces: form parameters `category_name` and comma-separated `tag_names`, normalized by the Posts context.

- [ ] **Step 1: Add failing LiveView tests for draft and publication UX**

Test:

- new posts save as drafts;
- incomplete drafts save successfully;
- publish shows required-field errors;
- valid publish changes status and exposes the public URL;
- unpublish removes public visibility;
- category can be reused or created inline;
- tag input rejects more than five unique tags;
- course selection is optional;
- admin index displays Draft/Published status and publication date.

Use stable DOM IDs: `#save-draft`, `#publish-post`, `#unpublish-post`, `#post-category`, `#post-tags`, `#post-related-course`, and `#seo-preview`.

- [ ] **Step 2: Run focused admin tests and observe failure**

Run: `mix test test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

Expected: new editorial tests FAIL.

- [ ] **Step 3: Restructure the form into focused sections**

Keep `Layouts.app` in the existing authenticated admin LiveView. Use `<.input>` for all supported inputs. Add content, organization, conversion, SEO preview, and distribution sections. The Markdown preview continues using the same Mermaid hook as the public article.

Do not create a separate category-management route in this release. Use a category input with a datalist of existing category names and a comma-separated tag input with validation help.

- [ ] **Step 4: Implement explicit save/publish/unpublish events**

`save` uses draft validation for drafts and normal published updates for already published posts. `publish` saves current form values, then calls `Posts.publish_post/1`. `unpublish` calls `Posts.unpublish_post/1` after confirmation.

The post route remains in `live_session :required_admin_user` because all three actions are administrative.

- [ ] **Step 5: Verify draft visibility boundaries**

Ensure draft posts remain available to administrators but absent from public queries and routes.

- [ ] **Step 6: Run focused admin tests**

Run only the new editorial tests by line/name until they pass, then run:

`mix test test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

Expected: new editorial tests PASS; report any surviving preexisting fake-module failures without changing unrelated dirty test support.

- [ ] **Step 7: Commit admin workflow files only**

```bash
git add lib/alchemistdrops_web/live/admin/post_live/form.ex \
  lib/alchemistdrops_web/live/admin/post_live/index.ex \
  lib/alchemistdrops_web/live/admin/post_live/index.html.heex \
  test/alchemistdrops_web/live/admin/post_editorial_live_test.exs
git commit -m "feat(blog): add editorial publishing controls"
```

### Task 5: Redesign public blog index, article, and homepage

**Files:**
- Modify: `lib/alchemistdrops_web/live/post_live/index.ex`
- Modify: `lib/alchemistdrops_web/live/post_live/index.html.heex`
- Modify: `lib/alchemistdrops_web/live/post_live/show.ex`
- Modify: `lib/alchemistdrops_web/live/post_live/show.html.heex`
- Modify: `lib/alchemistdrops_web/live/home_live/index.ex`
- Modify: `lib/alchemistdrops_web/live/home_live/index.html.heex`
- Modify: `assets/css/app.css`
- Modify: `test/alchemistdrops_web/live/post_live_test.exs`
- Modify: `test/alchemistdrops_web/live/home_live_test.exs`

**Interfaces:**
- Consumes: published Posts APIs and `Article.build/1`.
- Produces: category/tag query parameters and pagination.
- Produces: article assigns `article`, `related_posts`, `related_course`, localized copy, and SEO fields consumed by root layout.

- [ ] **Step 1: Add failing public visibility and layout tests**

Test that:

- drafts are absent from index and return not found by slug and legacy UUID;
- category/tag filters update the URL and results;
- published pagination has deterministic previous/next links;
- cards display summary, category, reading time, and publication date;
- the article has exactly one `h1`;
- desktop TOC links target rendered headings and mobile `<details>` exists;
- course CTA appears only for a published related course;
- related articles exclude the current article and drafts;
- localized labels follow article language;
- homepage displays exactly the three most recent published posts.

- [ ] **Step 2: Run focused public tests and observe failure**

Run: `mix test test/alchemistdrops_web/live/post_live_test.exs test/alchemistdrops_web/live/home_live_test.exs`

Expected: new tests FAIL on old queries/layout.

- [ ] **Step 3: Implement the index query-param flow**

Use `handle_params/3` to parse only known values. Never convert user values to atoms. Assign posts, categories/counts, selected category/tag, current page, and pagination state. Use verified routes for filter links.

- [ ] **Step 4: Implement approved index visuals**

Replace hard-coded `gray-*` colors with theme tokens. Render a compact header, category navigation, a featured first result, and remaining cards. Keep cards as real links for keyboard and browser behavior rather than click-only articles.

- [ ] **Step 5: Implement the guided article layout**

Use a single template `h1` and `Article.build/1` output. Add compact metadata, tags, a sticky desktop TOC, a mobile TOC `<details>`, optional cover image, optional published-course CTA, author block, related articles, and back navigation.

Set `phx-hook="Mermaid"` and `phx-update="ignore"` only on the body region managed by the hook. Every key section receives a stable DOM ID for tests.

- [ ] **Step 6: Add the homepage recent-post section**

Assign `Posts.list_recent_published_posts(3)` in `HomeLive.Index.mount/3` and render the section before pricing. Preserve the existing public browser pipeline/current-scope behavior.

- [ ] **Step 7: Add responsive article/index CSS**

Use readable line length, theme variables, sticky TOC with a viewport-safe top offset, visible focus states, and mobile stacking. Keep existing code/table/image prose behavior intact.

- [ ] **Step 8: Run public LiveView tests**

Run: `mix test test/alchemistdrops_web/live/post_live_test.exs test/alchemistdrops_web/live/home_live_test.exs`

Expected: PASS.

- [ ] **Step 9: Commit public experience**

```bash
git add lib/alchemistdrops_web/live/post_live lib/alchemistdrops_web/live/home_live \
  assets/css/app.css test/alchemistdrops_web/live/post_live_test.exs \
  test/alchemistdrops_web/live/home_live_test.exs
git commit -m "feat(blog): redesign article reading experience"
```

### Task 6: Complete article SEO, sitemap, and Atom discovery

**Files:**
- Create: `lib/alchemistdrops_web/controllers/blog_discovery_controller.ex`
- Create: `test/alchemistdrops_web/controllers/blog_discovery_controller_test.exs`
- Modify: `lib/alchemistdrops_web/components/layouts/root.html.heex`
- Modify: `lib/alchemistdrops_web/live/post_live/show.ex`
- Modify: `lib/alchemistdrops_web/router.ex`
- Modify: `test/alchemistdrops_web/live/post_live_test.exs`

**Interfaces:**
- Consumes: published Posts APIs and article SEO assigns.
- Produces: `GET /sitemap.xml` and `GET /blog/feed.xml` with `application/xml`.
- Produces root-layout assigns: `page_language`, `meta_type`, `meta_image`, `article_published_at`, `article_modified_at`, `json_ld`.

- [ ] **Step 1: Add failing metadata and discovery tests**

Assert exact canonical slug URLs, `og:type=article`, default/explicit images, locale, publication/modification timestamps, JSON-LD decoded through Jason, and absence of drafts from both XML endpoints.

Controller tests should parse essential XML strings and assert content type:

```elixir
conn = get(conn, ~p"/sitemap.xml")
assert get_resp_header(conn, "content-type") |> hd() =~ "application/xml"
assert response(conn, 200) =~ "/blog/#{published.slug}"
refute response(conn, 200) =~ draft.slug
```

- [ ] **Step 2: Run SEO/discovery tests and observe failure**

Run: `mix test test/alchemistdrops_web/controllers/blog_discovery_controller_test.exs test/alchemistdrops_web/live/post_live_test.exs`

Expected: discovery module/routes missing and new metadata assertions failing.

- [ ] **Step 3: Generalize root-layout metadata**

Resolve `lang` from assigns with an `en` default. Change the title suffix to ` · Alchemistdrops`. Default `meta_type` to `website`; show article timestamps only for article pages. Encode JSON-LD with `Jason.encode!(escape: :html_safe)` and place it in `<script type="application/ld+json">` through a safe raw value. HTML-safe JSON encoding is required because titles and summaries originate in editorial input.

- [ ] **Step 4: Implement XML controller without a new XML dependency**

Build the small XML documents from server-owned values and escape text through a private `xml_escape/1`. Set `content_type(conn, "application/xml")` and `send_resp/3`. Add a dedicated `:xml` pipeline using `plug :accepts, ["xml"]`, then public controller routes outside authenticated scopes.

- [ ] **Step 5: Run SEO/discovery tests**

Run: `mix test test/alchemistdrops_web/controllers/blog_discovery_controller_test.exs test/alchemistdrops_web/live/post_live_test.exs`

Expected: PASS.

- [ ] **Step 6: Commit discovery files**

```bash
git add lib/alchemistdrops_web/controllers/blog_discovery_controller.ex \
  lib/alchemistdrops_web/components/layouts/root.html.heex \
  lib/alchemistdrops_web/live/post_live/show.ex lib/alchemistdrops_web/router.ex \
  test/alchemistdrops_web/controllers/blog_discovery_controller_test.exs \
  test/alchemistdrops_web/live/post_live_test.exs
git commit -m "feat(blog): add article SEO and discovery feeds"
```

### Task 7: Implement the blueprint Mermaid viewer

**Files:**
- Modify: `assets/package.json`
- Modify: `assets/package-lock.json`
- Modify: `assets/js/hooks/Mermaid/index.js`
- Create: `assets/js/hooks/Mermaid/index.test.js`
- Modify: `assets/css/app.css`
- Modify: `test/alchemistdrops_web/live/post_live_test.exs`
- Modify: `test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

**Interfaces:**
- Consumes: server-rendered `pre.mermaid` nodes.
- Produces: `Mermaid` hook lifecycle with `mounted`, `updated`, and `destroyed` cleanup.
- Produces: per-diagram controls carrying `data-action="zoom-out|reset|zoom-in|expand"`.
- Produces: accessible dialog and `.mermaid-error[role="alert"]` fallback.

- [ ] **Step 1: Install the JavaScript test harness**

Add scripts and dev dependencies:

```json
{
  "scripts": {"test": "vitest run"},
  "dependencies": {"mermaid": "^11.0.0"},
  "devDependencies": {"jsdom": "^26.0.0", "vitest": "^3.0.0"}
}
```

Run: `npm install --prefix assets`

- [ ] **Step 2: Write failing Mermaid hook tests**

Mock `mermaid.initialize` and `mermaid.render`. Cover:

- original source retention;
- base theme plus light/dark blueprint variables;
- toolbar creation once per diagram;
- zoom bounds and reset;
- expanded dialog open/close, Escape, and focus restoration;
- theme-change rerender from original source;
- parse error fallback;
- cleanup of listeners/observers in `destroyed`.

- [ ] **Step 3: Run JavaScript tests and observe failure**

Run: `npm run test --prefix assets -- Mermaid`

Expected: FAIL because the current hook only calls `mermaid.run`.

- [ ] **Step 4: Implement an isolated renderer per diagram**

Use `mermaid.render(uniqueId, source)` so errors are caught per diagram. Derive theme colors from `getComputedStyle(document.documentElement)` after resolving the active site theme. Wrap each SVG in `.mermaid-blueprint`, add controls, and transform an inner canvas for zoom rather than scaling the article container.

Observe `data-theme` with `MutationObserver` and `prefers-color-scheme` with `matchMedia`; rerender only when the effective theme changes. Store references for cleanup.

- [ ] **Step 5: Implement accessible expanded viewing**

Use a native `<dialog>` appended within the hook root. Include a visible close button, close on Escape through native dialog behavior, and restore focus to the triggering Expand button.

- [ ] **Step 6: Add blueprint styling and server structure assertions**

Style the subtle grid, node/SVG containment, toolbar, dialog, error state, and mobile overflow using Alchemistdrops theme variables. Extend LiveView tests to assert the hook exists in both public and admin preview, while JavaScript tests own interaction behavior.

- [ ] **Step 7: Run JS, LiveView, and asset builds**

Run:

```bash
npm run test --prefix assets
mix test test/alchemistdrops_web/live/post_live_test.exs
mix assets.build
```

Expected: Mermaid tests PASS, focused LiveView tests PASS, asset build exits 0.

- [ ] **Step 8: Commit Mermaid behavior**

```bash
git add assets/package.json assets/package-lock.json assets/js/hooks/Mermaid/index.js \
  assets/js/hooks/Mermaid/index.test.js assets/css/app.css \
  test/alchemistdrops_web/live/post_live_test.exs \
  test/alchemistdrops_web/live/admin/post_editorial_live_test.exs
git commit -m "feat(blog): add blueprint Mermaid viewer"
```

### Task 8: Cross-feature verification and scope stop

**Files:**
- Modify only files required to fix failures introduced by Tasks 1–7.
- Do not fix the preexisting About-page failures unless the user separately authorizes that scope.

**Interfaces:**
- Consumes: all deliverables from Tasks 1–7.
- Produces: verification evidence and a clean blog-focused diff.

- [ ] **Step 1: Format only task-owned files and inspect the result**

Run `mix format` with the explicit task-owned file list gathered from commits after `a3b009b` plus uncommitted task-owned files. Never run a repository-wide write-format command while unrelated dirty files exist.

Inspect: `git status --short` and `git diff --check`.

Do not stage unrelated existing changes.

- [ ] **Step 2: Run the complete blog-focused Elixir suite**

Run:

```bash
mix test test/alchemistdrops/posts_test.exs \
  test/alchemistdrops/posts/article_test.exs \
  test/alchemistdrops/markdown_test.exs \
  test/alchemistdrops_web/live/post_live_test.exs \
  test/alchemistdrops_web/live/home_live_test.exs \
  test/alchemistdrops_web/controllers/blog_discovery_controller_test.exs
```

Expected: PASS.

- [ ] **Step 3: Run admin tests while separating baseline failures**

Run: `mix test test/alchemistdrops_web/live/admin/post_editorial_live_test.exs`

Expected: every new editorial test PASS. If preexisting fake-module failures remain, capture their exact count and names.

- [ ] **Step 4: Run JavaScript and production asset verification**

Run:

```bash
npm run test --prefix assets
mix assets.deploy
```

Expected: PASS.

- [ ] **Step 5: Run precommit and compare with recorded baseline**

Run: `mix precommit`

Expected target: all gates pass. If it still fails exclusively for the recorded unrelated baseline, report those exact failures and do not claim the repository-wide suite passes.

- [ ] **Step 6: Review the final diff for scope and migration safety**

Run:

```bash
git diff --stat origin/master...HEAD
git diff --check origin/master...HEAD
git status --short
```

Confirm no newsletter, scheduler, media library, revisions, search, or analytics work entered the implementation.

- [ ] **Step 7: Commit any final task-owned corrections**

```bash
git add <only task-owned corrected files>
git commit -m "fix(blog): complete editorial experience verification"
```

- [ ] **Step 8: Stop and report**

Report implemented behavior, migrations, focused test counts, JS/asset results, repository-wide precommit status, and any unchanged preexisting failures. Do not expand into the excluded features.
