---
task: alias-registration
verdict: Pending
closed: ""
---

# Alias registration

Python stubs (`.pyi`) and windowed Python scripts (`.pyw`), `.markdown` with `.mdown`, `.mkd` and `.mkdn` as compatibility aliases, `.gitmodules` and ripgrep/fd ignore basenames use their existing tokenizers, and Korn shell scripts and `.bash_aliases` get basic shell highlighting. Preview and Edit share one filename decision: Preview renders Markdown aliases as Markdown, and Edit shows their source with Markdown highlighting. Supported Markdown extensions outrank build-file prefixes, so Preview renders `Makefile.notes.md` and `Dockerfile.notes.MD` as Markdown and Edit highlights them as Markdown source, while `Makefile.json` and `Dockerfile.swift` stay build files in both modes. Exact basenames stay case-sensitive and lookalikes stay plain. [PR #195](https://github.com/bcinarli/pane-peek/pull/195).

Markdown aliases now take the same rendered-Preview preparation as `.md`; review measured comparable core processing for dense `.md` and `.markdown` fixtures in a debug build. Debug sandbox-review bundle and executable sizes match `main` when built from the same checkout; this is not the Release comparison H9 requires. No new token kinds or colours.

Limits: H1 and H9 remain Pending. H9 needs a matched signed Release comparison against `main` under the [performance checks](../../../engineering-and-review.md#performance-checks-for-feature-development): elapsed time, CPU and RSS for time to usable Preview, typing and switching on ordinary and near-limit files, with existing formats as controls, plus idle CPU/RSS and unpacked app size. Manual review remains for affected accessibility, draft, Undo and BOM/CRLF Save paths.
