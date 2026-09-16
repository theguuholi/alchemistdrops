# Blog post slugs

## Goal

Use stable post slugs for public blog URLs while keeping existing UUID URLs redirectable to the new slug URLs.

## Scope

- Add a `slug` field to posts.
- Backfill existing posts from their titles.
- Generate unique slugs when posts are created.
- Keep slugs stable when titles change.
- Resolve public `/blog/:slug` pages by slug.
- Redirect old public `/blog/:id` UUID links to `/blog/:slug`.
- Update public blog card links and SEO canonical URL generation to use slugs.

## Data changes

The `posts.slug` column stores the public URL identifier owned by the post record. It solves the problem of UUIDs appearing in public blog links and gives each post a stable, human-readable URL.

The backfill migration derives slugs from existing titles so existing content receives a valid public URL immediately. The migration handles duplicate titles by adding numeric suffixes, preserving a unique value for every existing row.

The unique index on `posts.slug` enforces the URL contract at the database layer, preventing two posts from resolving to the same public path.

## Context changes

`Alchemistdrops.Posts` owns post lookup and creation/update behavior. It will expose slug lookup helpers and generate unique slugs during create when one is not already present. Updates will preserve the existing slug unless a slug is explicitly set.

## Routing and LiveView changes

The existing public `live_session :current_user` scope is still correct because blog pages work with or without authentication. The public show route remains in that live session and changes from UUID-oriented handling to slug-oriented handling.

Admin post routes remain UUID-based and out of scope.

## Tests

Tests cover slug generation, duplicate slug suffixes, slug stability, slug lookup, public navigation by slug, and legacy UUID redirect behavior.
