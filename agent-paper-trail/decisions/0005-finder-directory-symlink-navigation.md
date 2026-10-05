# Finder-style directory symlink navigation

Status: Accepted

Date: 2026-10-05

## Context

During T02 review, Bilal questioned keeping a directory link's entered path. A live Finder comparison showed that both double-click and Go to Folder follow the target, and Command-Up opens the target's parent. Bilal then explicitly selected that behaviour to preserve the native macOS experience.

## Decision

Resolve directory symlinks when navigating. After a successful read, display the canonical target directory and use that location for parent navigation and breadcrumbs. Resolve/read off the UI thread; commit the directory and its entries together only for the latest successful request. Failed navigation keeps the last successful location and listing.

This supersedes the earlier A29 requirement to retain an entered directory-link path. It does not change symlink identity in a parent listing, selected-item path copying, link metadata or copy/move/Trash semantics.

## Rationale and consequences

Directory navigation and Command-Up match the observed Finder behaviour. The pane's displayed location also becomes the base for relative paths; future breadcrumbs, favourites and restoration use that location. A broken or inaccessible target still produces a visible error without redirecting the pane.

## Alternatives considered

- Retain the entered path: preserves logical ancestry, but differs from Finder. Superseded by Bilal's explicit instruction.
- Make path resolution a preference: adds configuration without a current need. Bilal selected the native default.

## Related documents

- [Current path requirement](../specs/001-mvp/spec.md#breadcrumbs-and-sorting)
- [Finder comparison and task evidence](../validation/t02-directory-browsing.md)
