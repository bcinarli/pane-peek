# PanePeek MVP tasks

Status: Active

One row per task. The linked evidence file’s `task` slug identifies its row. Status: `Ready`, `Active`, `Blocked`, `Completed`, `Abandoned`. Verdict: `Pending`, `Passed`, `Failed`, `Waived`. Completed means the task’s implementation and manual review are accepted; publication is recorded separately. A Ready task still needs explicit approval for its coding unit. While manual review is pending, keep the task Active and its verdict Pending.

[Plan](plan.md) owns scope, dependencies and unit gates; [validation](validation.md) owns full-criterion verdicts. Link checks from each task’s evidence file. Verify required dependency commits on `main` before starting another task under [decision 0002](../../decisions/0002-feature-branches-and-prs.md).

| Task | Milestone | Status | Verdict | Manual review | Publication / readiness | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| [T01 Launchable application shell](plan.md#t01-launchable-application-shell) | M1 | Completed | Passed | Passed | Implementation on `main` | [launchable-shell](evidence/launchable-shell.md) |
| [T02 Directory browsing and breadcrumbs](plan.md#t02-directory-browsing-and-breadcrumbs) | M1 | Completed | Passed | Passed | Merged [PR #4](https://github.com/bcinarli/pane-peek/pull/4) | [directory-browsing](evidence/directory-browsing.md) |
| [T03 Sorting and hidden visibility](plan.md#t03-sorting-and-hidden-visibility) | M1 | Completed | Passed | Passed | Merged [PR #5](https://github.com/bcinarli/pane-peek/pull/5) | [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md) |
| [T04 Multiple selection and primary item](plan.md#t04-multiple-selection-and-primary-item) | M1 | Completed | Passed | Passed | Merged [PR #6](https://github.com/bcinarli/pane-peek/pull/6) | [multiple-selection-primary-item](evidence/multiple-selection-primary-item.md) |
| [T14 Context actions and copied paths](plan.md#t14-context-actions-and-copied-paths) | M1 | Completed | Passed | Passed | Merged [PR #7](https://github.com/bcinarli/pane-peek/pull/7) | [context-actions-copied-paths](evidence/context-actions-copied-paths.md) |
| [T15 Persistent favourites](plan.md#t15-persistent-favourites) | M1 | Completed | Passed | Passed | Merged [PR #8](https://github.com/bcinarli/pane-peek/pull/8) | [persistent-favourites](evidence/persistent-favourites.md) |
| [T05 Details metadata sidebar](plan.md#t05-details-metadata-sidebar) | M2 | Completed | Passed | Passed | Merged [PR #12](https://github.com/bcinarli/pane-peek/pull/12) | [details-metadata-sidebar](evidence/details-metadata-sidebar.md) |
| [T06 Read-only preview and highlighting](plan.md#t06-read-only-preview-and-highlighting) | M2 | Completed | Passed | Passed | Merged [PR #13](https://github.com/bcinarli/pane-peek/pull/13) | [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md) |
| [T07 Preview editor toggle and safe saving](plan.md#t07-preview-editor-toggle-and-safe-saving) | M2 | Completed | Passed | Passed | Merged [PR #15](https://github.com/bcinarli/pane-peek/pull/15) as `468afc1`, including R1/R2 | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md) |
| [T19 Browser layout modes and expandable Details](plan.md#t19-browser-layout-modes-and-expandable-details) | M2 | Completed | Passed | Passed | Bilal accepted both units and approved commit/PR publication on 2026-10-11; 255 tests and final build/package/launch passed. Publication in progress on `bcinarli/t19-browser-layout-details`; merge remains separately gated. | [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md) |
| [T08 New text file and folder](plan.md#t08-new-text-file-and-folder) | M3 | Blocked | Pending | Pending | Awaiting T19 publication to `main` | None yet |
| [T09 Rename and affected document handling](plan.md#t09-rename-and-affected-document-handling) | M3 | Blocked | Pending | Pending | Awaiting T08 | None yet |
| [T10 Copy selected items to the other pane](plan.md#t10-copy-selected-items-to-the-other-pane) | M3 | Blocked | Pending | Pending | Awaiting T09 | None yet |
| [T11 Move selected items to the other pane](plan.md#t11-move-selected-items-to-the-other-pane) | M3 | Blocked | Pending | Pending | Awaiting T10 | None yet |
| [T12 Delete to Trash](plan.md#t12-delete-to-trash) | M3 | Blocked | Pending | Pending | Awaiting T11 | None yet |
| [T13 Drag and drop with Finder](plan.md#t13-drag-and-drop-with-finder) | M3 | Blocked | Pending | Pending | Awaiting T12 | None yet |
| [T16 Independent windows and shared operation coordination](plan.md#t16-independent-windows-and-shared-operation-coordination) | M4 | Blocked | Pending | Pending | Awaiting T13 and T15 | None yet |
| [T17 Restore the remembered directory pair](plan.md#t17-restore-the-remembered-directory-pair) | M4 | Blocked | Pending | Pending | Awaiting T16 | None yet |
| [T18 MVP acceptance and build documentation](plan.md#t18-mvp-acceptance-and-build-documentation) | M5 | Blocked | Pending | Pending | Awaiting T17 and milestone reviews | None yet |

## Post-M1 UI revisions

| Task / slug | Status | Verdict | Manual review | Evidence |
| --- | --- | --- | --- | --- |
| `toolbar-backgrounds` | Completed | Passed | Passed | [Checks](evidence/toolbar-backgrounds.md) |
| `toolbar-dividers` | Completed | Passed | Passed | [Checks](evidence/toolbar-dividers.md) |
| `panel-headers` | Completed | Passed | Passed | [Checks](evidence/panel-headers.md) |
| `icons-accent` | Completed | Passed | Passed | [Checks](evidence/icons-accent.md) |
| `surfaces-details-type` | Completed | Passed | Passed | [Checks](evidence/surfaces-details-type.md) |

## Quality remediation

| Task / slug | Status | Verdict | Manual review | Evidence |
| --- | --- | --- | --- | --- |
| `m1-sorting-ownership` | Completed | Passed | Passed | [Checks](evidence/m1-sorting-ownership.md) |
| `m1-selection-interaction` | Completed | Passed | Passed | [Checks](evidence/m1-selection-interaction.md) |
| `m1-test-gate-diagnostics` | Completed | Passed | Passed | [Checks](evidence/m1-test-gate-diagnostics.md) |
| `m2-discard-continuation` | Completed | Passed | Passed | [Checks](evidence/m2-discard-continuation.md); merged with T07/PR #15. |

### M1 quality remediation

All three M1 rows above are accepted for their recorded scope. Their historical records retain individual approval/publication checkpoints.

### M2 quality remediation

The Discard coverage row above closes the bounded T07 checkpoint. On 2026-10-11, Bilal confirmed that the quality review completed after T07 satisfies this checkpoint and requested T19 publication with no additional implementation unit. Both T19 units are accepted; M2 implementation/manual-review gates are complete. No additional quality analysis or remediation is claimed. T19 publication and merge remain separately recorded above.
