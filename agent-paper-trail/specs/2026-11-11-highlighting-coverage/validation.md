# Highlighting coverage validation

The [spec](spec.md#acceptance-criteria) owns H1–H9. All implementation and native acceptance remains Pending. Existing release waivers do not cover this workstream.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| H1 Supported-format aliases | Pending | Detection, fallback and one Markdown decision for Preview and source: [alias registration](evidence/alias-registration.md). Remaining: signed-app Preview/Edit and Save checks. |
| H2 Docker ignore | Pending | Column-one comments, exception markers, trimmed patterns and absent Git escape handling. |
| H3 Version files | Pending | Deferred until a concrete editing need. |
| H4 Dotenv | Pending | Keys, `export`, quoting, multiline values, comments and extension precedence for scoped names. |
| H5 Kotlin | Pending | Keywords, literals, raw strings, templates, numbers, annotations and nested comments. |
| H6 Ruby | Pending | Scanner behaviour and detection: [Ruby](evidence/ruby.md). Remaining: signed-app Preview/Edit and Save checks. |
| H7 Objective-C | Pending | Blocked on the `.m` decision; then `@` directives and literals, `#import`, `.mm` C++ keywords and unchanged `.h`. |
| H8 Vimscript and tmux | Pending | Deferred until a concrete editing need. |
| H9 Shared contract and resources | Pending | Ordered UTF-16 ranges, drafts, Unicode, Preview/Edit consistency, cancellation, BOM/CRLF Save, inert source and a matched signed Release comparison per unit under the [performance checks](../../engineering-and-review.md#performance-checks-for-feature-development). Unit 1: [alias registration](evidence/alias-registration.md) still needs that comparison. |

Each [task](tasks.md) links its concise evidence when implementation starts. Partial checks keep the full criterion Pending.
