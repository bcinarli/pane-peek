# Highlighting coverage validation

The [spec](spec.md#acceptance-criteria) owns H1–H9. H1 and H2 have passed. H9 has passed for Units 1 and 2. H3–H8 remain Pending. Existing release waivers do not cover this workstream.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| H1 Supported-format aliases | Passed | Detection, fallback and one Markdown decision for Preview and source: [alias registration](evidence/alias-registration.md). Signed-app Preview/Edit, draft, Undo, BOM/CRLF Save, VoiceOver and keyboard focus: [completed checklist](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6807139452). |
| H2 Docker ignore | Passed | Docker dialect, name precedence and signed-app functional checks in [Docker ignore](evidence/docker-ignore.md). |
| H3 Version files | Pending | Deferred until a concrete editing need. |
| H4 Dotenv | Pending | Keys, `export`, quoting, multiline values, comments and extension precedence for scoped names. |
| H5 Kotlin | Pending | Keywords, literals, raw strings, templates, numbers, annotations and nested comments. |
| H6 Ruby | Pending | Keywords, symbols, interpolation, percent literals, heredocs, regular expressions, variables, comments and conventional filenames. |
| H7 Objective-C | Pending | Blocked on the `.m` decision. Dialect behaviour and detection: [Objective-C](evidence/objective-c.md). Remaining: the `.m` decision, then signed-app Preview/Edit, draft and BOM/CRLF Save checks and matched signed Release comparison for H9. |
| H8 Vimscript and tmux | Pending | Deferred until a concrete editing need. |
| H9 Shared contract and resources (Units 1 and 2) | Passed | Ordered UTF-16 ranges, drafts, Unicode, Preview/Edit consistency, cancellation, BOM/CRLF Save, inert source and a matched signed Release comparison per unit under the [performance checks](../../engineering-and-review.md#performance-checks-for-feature-development). Units 1 and 2 passed with matched native signed Release comparisons for [alias registration](evidence/alias-registration.md) and [Docker ignore](evidence/docker-ignore.md). Evaluate H9 for each later unit. [#203 Markdown Preview responsiveness](evidence/markdown-preview-responsiveness.md) passed signed-app interactive validation. |

Each [task](tasks.md) links its concise evidence when implementation starts. Partial checks keep the full criterion Pending.
