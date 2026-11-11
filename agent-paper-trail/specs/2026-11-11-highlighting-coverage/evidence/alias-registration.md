---
task: alias-registration
verdict: Pending
closed: ""
---

# Alias registration

Python stub and windowed-script extensions, `.markdown` with `.mdown`, `.mkd` and `.mkdn` as compatibility aliases, `.gitmodules` and ripgrep/fd ignore basenames use their existing tokenizers, and Korn shell scripts and `.bash_aliases` get basic shell highlighting. Rendered Markdown Preview and source highlighting share one filename decision; supported Markdown extensions outrank build-file prefixes, so `Makefile.notes.md` and `Dockerfile.notes.MD` render as Markdown in Preview and Edit while `Makefile.json` and `Dockerfile.swift` stay build files. Exact basenames stay case-sensitive and lookalikes stay plain. [PR #195](https://github.com/bcinarli/pane-peek/pull/195).

Markdown aliases now take the same rendered-Preview preparation as `.md`; review measured comparable core processing for dense `.md` and `.markdown` fixtures in a debug build. Sandbox-review bundle and executable sizes match `main` when built from the same checkout. No new token kinds or colours.

Limits: H1 and H9 remain Pending. A signed-app baseline comparison under the same build configuration remains for time to usable Preview, typing and switching on ordinary and near-limit files and resource use, with existing formats as controls. Manual review remains for affected accessibility, draft, Undo and BOM/CRLF Save paths.
