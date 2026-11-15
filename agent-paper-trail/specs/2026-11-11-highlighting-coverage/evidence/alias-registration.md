---
task: alias-registration
verdict: Passed
closed: "2026-11-15"
---

# Alias registration

Python stubs (`.pyi`) and windowed Python scripts (`.pyw`), `.markdown` with `.mdown`, `.mkd` and `.mkdn` as compatibility aliases, `.gitmodules` and ripgrep/fd ignore basenames use their existing tokenizers, and Korn shell scripts and `.bash_aliases` get basic shell highlighting. Preview and Edit share one filename decision: Preview renders Markdown aliases as Markdown, and Edit shows their source with Markdown highlighting. Supported Markdown extensions outrank build-file prefixes, so Preview renders `Makefile.notes.md` and `Dockerfile.notes.MD` as Markdown and Edit highlights them as Markdown source, while `Makefile.json` and `Dockerfile.swift` stay build files in both modes. Exact basenames stay case-sensitive and lookalikes stay plain. Merged in [PR #195](https://github.com/bcinarli/pane-peek/pull/195) (`b51bf75`). Manual review passed Preview/Edit, draft retention, Undo, BOM/CRLF Save, VoiceOver and keyboard focus for the new names: [completed checklist](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6807139452).

Markdown aliases now take the same rendered-Preview preparation as `.md`. An ad hoc-signed, sandboxed Release comparison of `300b9c0` and `8b15f57` on one arm64 Mac measured bundle size (+144 B), settled idle RSS (~103.6 MB on both) and idle CPU (below sampler resolution on both). For the tested ordinary and near-limit `.md`, `.py` and `.sh` fixtures, core Preview and highlighting times matched, and the new names cost the same as their existing formats. [Figures](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6847466294). No new token kinds or colours.

Matched Developer ID-signed Release builds (`b496253` → `4e8ba6b`) measured native Preview/Edit, typing, recolouring and switching. At about 960 KB, rendered `.markdown` opens in 1.26 s, close to `.md` at 1.25 s. The existing `.md` control took 59 ms longer to open with [#203](https://github.com/bcinarli/pane-peek/issues/203) and its longest main-thread gap fell from 218 to 48 ms. The newly highlighted non-Markdown names took 73–125 ms at the same size.

Median PanePeek CPU time across measured workload phases rose from 5.95 to 10.92 s. Settled idle CPU was 0.016% before and 0.019% after, as a share of one core. Idle RSS stayed near 76 MiB, the sampled peak rose from 328 to 390 MiB in the mixed workload, and the signed bundle grew by 15,552 bytes.

Newly rendered Markdown accounted for 3.98 s (about 80%) of the 4.98 s CPU increase. The near-limit `.markdown` case added 3.30 s, including 2.56 s for opening and switching back and 0.69 s during draft recolouring. It used 3.40 s on the candidate, close to the same-content `.md` control at 3.38 s (3.34 s on the baseline). Newly highlighted Python, shell, Git configuration and ignore aliases added 0.91 s.

After an immediate Preview-to-Edit switch, near-limit draft recolouring took 713 ms for `.markdown` and 711 ms for `.md`. A signed diagnostic isolated most of the delay to deferred AppKit layout in the rendered view. The measurements were accepted with this limitation.
