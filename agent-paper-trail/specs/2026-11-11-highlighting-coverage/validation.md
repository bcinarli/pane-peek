# Highlighting coverage validation

The [spec](spec.md#acceptance-criteria) owns H1–H9. H1 has passed; the other criteria remain Pending. Existing release waivers do not cover this workstream.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| H1 Supported-format aliases | Passed | Detection, fallback and one Markdown decision for Preview and source: [alias registration](evidence/alias-registration.md). Signed-app Preview/Edit, draft, Undo, BOM/CRLF Save, VoiceOver and keyboard focus: [completed checklist](https://github.com/bcinarli/pane-peek/pull/195#issuecomment-6807139452). |
| H2 Docker ignore | Pending | Column-one comments, exception markers, trimmed patterns and absent Git escape handling. |
| H3 Version files | Pending | Deferred until a concrete editing need. |
| H4 Dotenv | Pending | Keys, `export`, quoting, multiline values, comments and extension precedence for scoped names. |
| H5 Kotlin | Pending | Keywords, literals, raw strings, templates, numbers, annotations and nested comments. |
| H6 Ruby | Pending | Keywords, symbols, interpolation, percent literals, heredocs, regular expressions, variables, comments and conventional filenames. |
| H7 Objective-C | Pending | Blocked on the `.m` decision; then `@` directives and literals, `#import`, `.mm` C++ keywords and unchanged `.h`. |
| H8 Vimscript and tmux | Pending | Deferred until a concrete editing need. |
| H9 Shared contract and resources | Pending | Ordered UTF-16 ranges, drafts, Unicode, Preview/Edit consistency, cancellation, BOM/CRLF Save, inert source and a matched signed Release comparison per unit under the [performance checks](../../engineering-and-review.md#performance-checks-for-feature-development). Unit 1: an ad hoc Release comparison measured bundle size, idle CPU/RSS and core Preview and highlighting for the tested fixtures ([alias registration](evidence/alias-registration.md)). In-app time to usable Preview, typing and switching need the matched signed Release comparison, and [#203](https://github.com/bcinarli/pane-peek/issues/203) responsiveness remains. |

Each [task](tasks.md) links its concise evidence when implementation starts. Partial checks keep the full criterion Pending.
