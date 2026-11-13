---
task: alias-registration
verdict: Pending
closed: ""
---

# Alias registration

Python stubs (`.pyi`) and windowed Python scripts (`.pyw`), `.markdown` with `.mdown`, `.mkd` and `.mkdn` as compatibility aliases, `.gitmodules` and ripgrep/fd ignore basenames use their existing tokenizers, and Korn shell scripts and `.bash_aliases` get basic shell highlighting. Preview and Edit share one filename decision: Preview renders Markdown aliases as Markdown, and Edit shows their source with Markdown highlighting. Supported Markdown extensions outrank build-file prefixes, so Preview renders `Makefile.notes.md` and `Dockerfile.notes.MD` as Markdown and Edit highlights them as Markdown source, while `Makefile.json` and `Dockerfile.swift` stay build files in both modes. Exact basenames stay case-sensitive and lookalikes stay plain. Merged in [PR #195](https://github.com/bcinarli/pane-peek/pull/195) (`b51bf75`); its functional manual checks passed in review.

Markdown aliases now take the same rendered-Preview preparation as `.md`. An ad hoc-signed, sandboxed Release comparison against `300b9c0` on one arm64 Mac found no regression: unpacked app +144 B, settled idle RSS ~103.6 MB and idle CPU below sampler resolution on both builds. Core Preview and highlighting times for ordinary and near-limit `.md`, `.py` and `.sh` controls matched, and the new names cost the same as their existing formats. Filename detection costs about 0.3 µs more per selection. [Figures](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6847466294). No new token kinds or colours.

Limits: H1 and H9 remain Pending. H9 still needs the signed Release comparison and in-app time to usable Preview, typing and switching, which were measured only at core level. Near-limit Markdown Preview responsiveness is tracked in [#203](https://github.com/bcinarli/pane-peek/issues/203). Accessibility, draft, Undo and BOM/CRLF Save paths need explicit confirmation for H1.
