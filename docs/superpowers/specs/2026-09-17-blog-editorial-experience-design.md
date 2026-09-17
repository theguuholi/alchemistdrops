# Blog Editorial Experience — Design

**Date:** 2026-09-17
**Status:** Approved for implementation planning

## Objective

Transform the existing blog from a basic post CRUD into a controlled editorial and acquisition surface while preserving the current Markdown, slug, Mermaid, and LinkedIn functionality.

The release must deliver:

- an explicit draft/published workflow;
- one primary category and reusable tags per article;
- an optional related-course call to action;
- complete article SEO and discovery feeds;
- the approved guided-reading article layout;
- the approved blueprint Mermaid treatment.

## Existing Capabilities to Preserve

- Existing canonical slug URLs at `/blog/:slug`.
- Legacy UUID URLs redirecting to the canonical slug URL.
- Markdown rendering with tables, heading IDs, task lists, and Mermaid blocks.
- Admin-side live Markdown preview.
- LinkedIn preview generation and publishing.
- Public routes inside the existing `live_session :current_user`, because the blog works for authenticated and anonymous visitors.
- Admin routes inside the existing `live_session :required_admin_user`, because editorial actions require an admin.

## Scope Decisions

### Included

- Draft and published states only.
- Categories and tags.
- Optional course CTA configured per post.
- SEO metadata, social preview metadata, JSON-LD, sitemap, and Atom feed.
- Public filtering by category and tag.
- Related articles.
- Latest articles on the homepage.
- Guided reading layout with desktop table of contents.
- Mermaid blueprint surface with zoom and expanded viewing.
- Reading time and cleaned article summary.

### Excluded

- Scheduled publication.
- Newsletter capture or delivery.
- Image upload/media library; cover images use a URL in this release.
- Revisions, autosave, and editorial collaboration.
- Full-text search.
- Behavioral analytics and conversion attribution.

## Data Model

### Post

Extend `Alchemistdrops.Posts.Post` with:

- `status`: `Ecto.Enum` with `:draft` and `:published`, defaulting to `:draft`.
- `published_at`: nullable UTC datetime; set on the first transition to published.
- `summary`: explicit card and social summary, maximum 240 characters.
- `seo_title`: optional override, maximum 60 characters.
- `seo_description`: optional override, maximum 160 characters.
- `cover_image_url`: optional absolute HTTPS URL.
- `cover_image_alt`: required when `cover_image_url` is present.
- `language`: `en` or `pt-BR`, defaulting to `en` for compatibility with current content.
- `category_id`: optional for drafts and required before publication.
- `related_course_id`: optional foreign key to a course, using `on_delete: :nilify_all`.

The current `slug`, `title`, `body`, `background`, and `views` fields remain. Slug behavior already exists and is not redesigned here.

Publication validation requires a title, slug, body, summary, language, and category. Drafts may remain incomplete so authors can save work incrementally.

When migrating existing rows, mark every existing post as published and copy `inserted_at` to `published_at`. This preserves all currently public URLs and avoids silently removing existing content.

### Category

Create `Alchemistdrops.Posts.Category` with:

- `name`: required and unique.
- `slug`: required and unique; generated from the name and editable.
- `description`: optional, maximum 240 characters.

Each post belongs to zero or one category while a draft and exactly one category when published. The first release manages categories inline from the post form: admins may select an existing category or create a new one without leaving the article.

### Tag

Create `Alchemistdrops.Posts.Tag` with:

- `name`: required and unique using case-insensitive comparison.
- `slug`: required and unique; generated from the name.

Use a `posts_tags` join table with a unique composite index. An article can have zero to five tags. Selecting an existing tag is preferred; creating a new tag is allowed from the post form. Tags do not gate publication.

## Context Boundaries and Public Queries

`Alchemistdrops.Posts` remains the owner of post, category, and tag persistence.

Public functions return published posts only:

- `list_published_posts/1` accepts optional category/tag filters and pagination options.
- `get_published_post_by_slug!/1` never exposes drafts.
- `list_related_posts/2` returns up to three published posts, preferring shared tags and then the same category.
- `list_recent_published_posts/1` powers the homepage.
- `list_categories_with_published_counts/0` excludes empty categories.

Admin functions remain explicit and may return drafts:

- `list_admin_posts/0`.
- `get_post!/1`.
- `publish_post/1`.
- `unpublish_post/1`.

View increments use an atomic database update rather than writing `post.views + 1`, preventing lost increments under concurrent traffic.

## Editorial Workflow

The admin form is divided into focused sections:

1. **Content:** title, slug, summary, body, cover image URL/alt.
2. **Organization:** language, category, and up to five tags.
3. **Conversion:** optional related course.
4. **SEO preview:** resolved title, description, canonical URL, and social card preview.
5. **Distribution:** existing LinkedIn controls.

The primary actions are:

- **Save draft:** persists without publication-only fields being complete.
- **Publish:** validates all publication requirements, sets `published_at` on first publication, and exposes the public URL.
- **Update published article:** saves changes while retaining the original `published_at`.
- **Move to draft:** removes the post from public queries without deleting it.

LinkedIn generation and publication are available only for a published article. Existing published LinkedIn metadata remains immutable under the current social workflow.

## Public Blog Index

The index uses the Alchemistdrops theme tokens instead of separate hard-coded gray palettes. It includes:

- a compact editorial header;
- category navigation with published counts;
- optional active tag filtering;
- a featured first article followed by a responsive article grid;
- cover image, category, title, summary, publication date, and reading time;
- canonical slug navigation;
- pagination when the result set exceeds the page limit.

The homepage shows the three most recent published articles with a link to the full blog. Drafts never appear.

## Article Reading Experience

Use the approved **guided reading** direction:

- compact breadcrumb and category label;
- a single page-level `h1` sourced from `post.title`;
- summary, author, publication date, updated date, reading time, and tags;
- constrained reading measure of approximately 68–72 characters;
- sticky table of contents on desktop using rendered `h2` and `h3` headings;
- no sidebar on small screens; provide a collapsible “Neste artigo / In this article” block instead;
- optional cover image below the metadata;
- related-course CTA after the article only when configured;
- up to three related articles after the CTA;
- author block and back-to-blog navigation.

The renderer removes a leading Markdown `h1` when it duplicates the post title. This prevents the double-title problem shown in the supplied screenshot while retaining intentional lower-level headings.

Copy follows `post.language`: English articles use English interface labels and `pt-BR` articles use Portuguese labels. The document `lang` value follows the post language on article pages.

## Mermaid Blueprint Experience

Use the approved **blueprint technical** direction:

- Mermaid uses the `base` theme with Alchemistdrops purple/cyan variables.
- Each diagram is placed in a bordered, rounded surface with a subtle grid background.
- Node fills, text, lines, labels, and cluster backgrounds have separate light and dark theme values.
- Diagrams fit the available width without shrinking labels below a readable size.
- Overflow remains contained on mobile.
- Controls provide zoom out, reset/percentage, zoom in, and expanded viewing.
- Expanded viewing uses an accessible dialog, supports Escape, and preserves keyboard focus.
- A textual error state replaces a diagram when Mermaid parsing fails; the rest of the article continues rendering.
- The admin preview uses the same renderer and controls as the public article.

The hook stores the original Mermaid source before rendering. When the site theme changes, it safely re-renders from that source with the matching theme variables rather than recoloring an already generated SVG.

## SEO and Discovery

Resolve metadata in this order:

- Title: `seo_title`, then `title`.
- Description: `seo_description`, then `summary`.
- Social image: `cover_image_url`, then a site-wide default image.
- Canonical URL: existing slug URL.

Article pages emit:

- standard description and canonical tags;
- `og:type=article`;
- Open Graph title, description, URL, image, locale, published time, and modified time;
- Twitter large-image metadata;
- `BlogPosting` JSON-LD containing headline, description, image, author, dates, language, and canonical URL.

The root layout keeps `og:type=website` for non-article pages and removes the generic “Phoenix Framework” title suffix in favor of Alchemistdrops branding.

Create:

- `/sitemap.xml`, containing canonical URLs for published posts plus core public pages;
- `/blog/feed.xml`, an Atom feed containing the latest published posts.

Both endpoints are public controller routes using a dedicated XML pipeline. They must set the appropriate content type and never include drafts.

## Optional Course CTA

When `related_course_id` references a published course, render a compact CTA after the article:

- course title and short description;
- thumbnail when available;
- a localized action linking to `/courses/:id`.

When the association is absent or the course is unpublished, render no CTA. The article remains visually complete without it.

## Error and Compatibility Behavior

- A public request for a draft or unknown slug raises the existing not-found behavior.
- Legacy UUID routes continue redirecting only when the corresponding post is published; drafts are not revealed by redirect behavior.
- Existing slugs remain unchanged during this work.
- Removing a category is rejected while posts reference it; content must be reassigned first.
- Removing a tag only removes its join rows and does not affect article publication.
- Removing a related course nulls the post association.
- Invalid cover URLs or incomplete publication fields produce form errors without discarding draft content.

## Testing Strategy

Follow TDD for every behavior. Coverage includes:

- migration compatibility and backfill behavior;
- draft/published validation and transitions;
- public queries excluding drafts;
- categories, tag limits, tag uniqueness, filtering, and related-post ranking;
- optional course CTA behavior;
- article metadata resolution and JSON-LD;
- sitemap and Atom output excluding drafts;
- duplicate leading `h1` removal, table-of-contents extraction, and reading-time calculation;
- article and index rendering in both supported languages;
- Mermaid hook registration, controls, error markup, and theme-change behavior;
- legacy UUID redirect compatibility;
- LinkedIn actions restricted to published articles;
- homepage recent-article section.

Browser-level JavaScript tests cover Mermaid rendering, zoom, expanded dialog behavior, theme re-rendering, and parse failures. LiveView tests cover the server-rendered structure and accessibility hooks.

## Acceptance Criteria

1. An admin can save an incomplete draft without exposing it publicly.
2. Publishing requires category, summary, language, title, slug, and body.
3. Published posts appear in the blog, sitemap, Atom feed, homepage, filters, and related-post results; drafts appear in none of them.
4. Every published article has one category and no more than five tags.
5. Article URLs continue using existing slugs and legacy UUID redirects remain compatible.
6. The article renders one main title, a guided desktop table of contents, localized metadata, readable prose, and an optional course CTA.
7. Mermaid diagrams use the blueprint treatment and support light/dark themes, zoom, reset, expanded viewing, mobile overflow, and graceful errors.
8. Article pages emit canonical, Open Graph, Twitter, and `BlogPosting` metadata.
9. The homepage displays the three newest published articles.
10. New blog-focused tests pass; the previously recorded unrelated baseline failures remain separately identified until their owning work is corrected.
