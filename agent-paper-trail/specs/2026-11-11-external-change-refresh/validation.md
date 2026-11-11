# External change refresh validation

The [spec](spec.md#acceptance-criteria) owns E1–E8. All implementation and native acceptance remains Pending. Planning approval does not establish runtime feasibility. Existing release waivers do not cover this workstream.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| E1 External listing changes | Pending | Creation, removal, rename and metadata changes from another process, in both panes and across windows. |
| E2 Retained browser state | Pending | Sort, hidden visibility, column widths, scroll, surviving selection, focus, history and inline rename. |
| E3 Clean document reload | Pending | Preview and Edit across supported preview types, removal and type change. |
| E4 Draft protection | Pending | Draft, dirty state and Undo retention, changed-on-disk notice, Discard loading the disk version and unchanged Save conflict handling. |
| E5 Own operations and coalescing | Pending | Signal coalescing, cancellation and stale-signal rejection: [Change-source feasibility](evidence/change-source-feasibility.md). Remaining: no duplicate reload or notice for PanePeek operations; bounded, cancellable, stale-safe bursts without flicker or interrupted typing. |
| E6 Watcher lifecycle | Pending | Registration release on cancellation and teardown: [Change-source feasibility](evidence/change-source-feasibility.md). Remaining: release for hidden browsers, closed windows and departed directories; foreground reconciliation; honest fallback on unsupported volumes. |
| E7 Sandbox and volumes | Pending | Source selection and atomic-replace reporting: [Change-source feasibility](evidence/change-source-feasibility.md). Remaining: signed sandbox build with existing grants and no new entitlement, atomic-replace saves and cloud-backed folders. |
| E8 Accessibility and resources | Pending | Keyboard, VoiceOver and focus behaviour; idle and burst resource use compared with the previous build. |

Each [task](tasks.md) links its concise evidence when implementation starts. Partial checks keep the full criterion Pending.
