---
task: cli-profile-cleanup
verdict: Passed
closed: 2026-11-11
---

# Profile cleanup on uninstall

The C1.2 changes based on `bd9bd72` remove the verified launcher first and report `~/.zprofile` when its PanePeek entry needs attention. The signed manual checklist is accepted, and local checks verify clean removal, profile preservation and safe retries. Broader chooser, accessibility and release checks remain pending.
