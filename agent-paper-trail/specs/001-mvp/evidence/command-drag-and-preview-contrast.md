---
task: command-drag-and-preview-contrast
verdict: Pending
closed: ""
---

# Command-drag and Preview contrast

## Reported failures (2026-10-18)

Bilal's manual pane-to-pane check confirms default Copy works but Command-move fails. During the Command-move attempt, the Preview label turns white. These are remaining correctness/contrast gaps; the specific modifier, drag or disabled-state cause is not yet established.

Native automation also failed selected and unselected Finder control drags, so it cannot supply a trustworthy end-to-end drag verdict in this environment. Meaningful local regressions and a manual native check are required for the correction.

No implementation change is made in this follow-up. Retain working copy, captured identities, source permissions, dirty-draft guards, operation cleanup and readable Dark Mauve labels without changing disabled accessibility semantics.
