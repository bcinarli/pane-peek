---
task: kotlin
verdict: Pending
closed: ""
---

# Kotlin

`.kt` and `.kts` files use a focused Kotlin scanner: hard keywords, soft and modifier keywords outside member and declaration positions, `true`/`false`/`null`, character literals, single-line and raw strings with `$name` and `${…}` templates as references, validated number forms, annotations and labels as references, nested block comments and a script shebang. Template and string nesting uses an explicit stack, so deep nesting cannot exhaust the call stack. Not published.

No new token kinds or colours. Limits: multi-dollar raw strings, `$` before backticked names and some contextual soft-keyword uses stay approximate. Signed-app Preview/Edit, draft and BOM/CRLF Save checks remain for manual review.
