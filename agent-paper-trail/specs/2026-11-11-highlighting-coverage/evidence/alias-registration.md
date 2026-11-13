---
task: alias-registration
verdict: Pending
closed: ""
---

# Alias registration

Python stubs (`.pyi`) and windowed Python scripts (`.pyw`), `.markdown` with `.mdown`, `.mkd` and `.mkdn` as compatibility aliases, `.gitmodules` and ripgrep/fd ignore basenames use their existing tokenizers, and Korn shell scripts and `.bash_aliases` get basic shell highlighting. Preview and Edit share one filename decision: Preview renders Markdown aliases as Markdown, and Edit shows their source with Markdown highlighting. Supported Markdown extensions outrank build-file prefixes, so Preview renders `Makefile.notes.md` and `Dockerfile.notes.MD` as Markdown and Edit highlights them as Markdown source, while `Makefile.json` and `Dockerfile.swift` stay build files in both modes. Exact basenames stay case-sensitive and lookalikes stay plain. Merged in [PR #195](https://github.com/bcinarli/pane-peek/pull/195) (`b51bf75`). Manual review passed Preview/Edit, draft retention, Undo, BOM/CRLF Save, VoiceOver and keyboard focus for the new names: [completed checklist](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6807139452).

Markdown aliases now take the same rendered-Preview preparation as `.md`. An ad hoc-signed, sandboxed Release comparison of `300b9c0` and `8b15f57` on one arm64 Mac measured bundle size (+144 B), settled idle RSS (~103.6 MB on both) and idle CPU (below sampler resolution on both). For the tested ordinary and near-limit `.md`, `.py` and `.sh` fixtures, core Preview and highlighting times matched, and the new names cost the same as their existing formats. [Figures](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6847466294). No new token kinds or colours.

Limits: H1 has passed; H9 remains Pending. In-app time to usable Preview, typing and switching need the matched signed Release comparison, and near-limit Markdown Preview responsiveness is tracked in [#203](https://github.com/bcinarli/pane-peek/issues/203).
