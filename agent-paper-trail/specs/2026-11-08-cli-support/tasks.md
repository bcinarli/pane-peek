# CLI and native path opening tasks

The native scope and CLI command contract in the [spec](spec.md) and [plan](plan.md) are accepted. Units 1 and 2, including their supplied manual checklists, are accepted. App-menu install/uninstall and explicit reversible zsh PATH integration are accepted for Unit 3; native validation, manual acceptance and publication retain their gates. The [shared workflow](../001-mvp/plan.md#task-workflow-and-exit-gates) applies. Readiness does not grant coding or publication approval.

| Task | Status | Verdict | Review / next gate | Publication | Evidence |
| --- | --- | --- | --- | --- | --- |
| Native contract and Unit 1 plan | Completed | Passed | Native contract accepted; wider checks remain in validation | Local `f98db39` | [Native opening](evidence/native-path-opening.md) |
| [native-path-opening](plan.md#unit-1-native-incoming-paths) | Completed | Passed | Unit 1 manual checklist accepted 2026-11-08; broader criterion limits remain in validation | Local `f98db39` | [Native opening](evidence/native-path-opening.md) |
| [cli-launcher](plan.md#unit-2-bundled-launcher-and-reveal-handoff) | Completed | Passed | Unit 2 manual checklist accepted 2026-11-10; broader distribution/platform limits remain in validation | Local `be0a2e2` | [Bundled launcher](evidence/cli-launcher.md) |
| [cli-setup-documentation](plan.md#unit-3-explicit-setup-removal-and-usage) | Completed | Passed | Unit 3 manual review accepted 2026-11-11. Broader checks remain in validation | Local commit | [Setup and usage](evidence/cli-setup-documentation.md) |
| [cli-profile-entry-in-panel](plan.md#unit-3-explicit-setup-removal-and-usage) | Active | Pending | Signed panel manual review | Local `0a6209f` | [Shell profile entry](evidence/cli-profile-entry-in-panel.md) |
| [cli-launcher-only-install](plan.md#unit-3-explicit-setup-removal-and-usage) | Completed | Passed | Signed manual checklist accepted 2026-11-11 | Local commit | [Launcher-only installation](evidence/cli-launcher-only-install.md) |
