# CLI and native path opening tasks

Pull request tracking is on [#132](https://github.com/bcinarli/pane-peek/issues/132). Release publication is pending. [Validation](validation.md) tracks criterion coverage.

| Task | Status | Verdict | Manual review / next gate | Implementation | Evidence |
| --- | --- | --- | --- | --- | --- |
| [native-path-opening](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Manual checklist passed 2026-11-08 | `f98db39` | [Native opening](evidence/native-path-opening.md) |
| [cli-busy-incoming-open](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Manual checklist passed 2026-11-11 | `6eaf8f0` | [Busy-window incoming opens](evidence/cli-busy-incoming-open.md) |
| [cli-typed-window-restoration](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Manual checklist passed 2026-11-11 | `cf3f21d` | [Typed window restoration](evidence/cli-typed-window-restoration.md) |
| [cli-open-rename-save-safety](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Manual checklist passed 2026-11-11 | [PR #192](https://github.com/bcinarli/pane-peek/pull/192) | [Incoming opens during Rename and Save](evidence/cli-open-rename-save-safety.md) |
| [cli-open-publication-identity](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Manual checklist passed 2026-11-11 | [PR #192](https://github.com/bcinarli/pane-peek/pull/192) | [Incoming destination identity](evidence/cli-open-publication-identity.md) |
| [cli-open-save-retries](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Manual checklist passed 2026-11-11 | [PR #192](https://github.com/bcinarli/pane-peek/pull/192) | [Save during incoming opens](evidence/cli-open-save-retries.md) |
| [cli-launcher](plan.md#unit-2-bundled-launcher-and-reveal-handoff) | Completed | Passed | Manual checklist passed 2026-11-10 | `be0a2e2` | [Bundled launcher](evidence/cli-launcher.md) |
| [cli-setup-documentation](plan.md#unit-3-explicit-setup-removal-and-usage) | Completed | Passed | Manual checklist passed 2026-11-11 | `35ebe66` | [Setup and usage](evidence/cli-setup-documentation.md) |
| [cli-profile-entry-in-panel](plan.md#unit-3-explicit-setup-removal-and-usage) | Active | Pending | Signed manual panel review, keyboard copying and VoiceOver | `0a6209f` | [Shell profile entry](evidence/cli-profile-entry-in-panel.md) |
| [cli-launcher-only-install](plan.md#unit-3-explicit-setup-removal-and-usage) | Completed | Passed | Manual checklist passed 2026-11-11 | `bd9bd72` | [Launcher-only installation](evidence/cli-launcher-only-install.md) |
| [cli-profile-cleanup](plan.md#unit-3-explicit-setup-removal-and-usage) | Completed | Passed | Manual checklist passed 2026-11-11 | `0c892cf` | [Profile cleanup](evidence/cli-profile-cleanup.md) |
| [cli-stale-link-recovery](plan.md#unit-3-explicit-setup-removal-and-usage) | Completed | Passed | Manual checklist passed 2026-11-11 | `4cc1c4d` | [Stale-link recovery](evidence/cli-stale-link-recovery.md) |
