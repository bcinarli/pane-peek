# Highlighting coverage validation

The [spec](spec.md#acceptance-criteria) owns H1–H9. All implementation and native acceptance remains Pending. Existing release waivers do not cover this workstream.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| H1 Supported-format aliases | Pending | Detection, fallback and rendered Markdown routing: [alias registration](evidence/alias-registration.md). Remaining: signed-app Preview/Edit and Save checks. |
| H2 Docker ignore | Pending | Dialect rules and name precedence: [Docker ignore](evidence/docker-ignore.md). Remaining: signed-app Preview/Edit and Save checks. |
| H3 Version files | Pending | Reader-specific records: [version files](evidence/version-files.md). Remaining: signed-app Preview/Edit and Save checks. |
| H4 Dotenv | Pending | Keys, `export`, quoting, multiline values, comments and extension precedence for scoped names. |
| H5 Kotlin | Pending | Keywords, literals, raw strings, templates, numbers, annotations and nested comments. |
| H6 Ruby | Pending | Keywords, symbols, interpolation, percent literals, heredocs, regular expressions, variables, comments and conventional filenames. |
| H7 Objective-C | Pending | `@` directives and literals, `#import`, `.mm` C++ keywords and unchanged `.h`. |
| H8 Vimscript and tmux | Pending | Commands, options, strings, references, comments, continuations and `vim9script`. |
| H9 Shared contract and resources | Pending | Ordered UTF-16 ranges, drafts, Unicode, Preview/Edit consistency, cancellation, BOM/CRLF Save, inert source and measured impact per unit. |

Each [task](tasks.md) links its concise evidence when implementation starts. Partial checks keep the full criterion Pending.
