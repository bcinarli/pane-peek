---
task: objective-c
verdict: Pending
closed: ""
---

# Objective-C

`.m` and `.mm` files use an Objective-C option of the C-family scanner: `@` directives as keywords, `@"…"` strings, `@` markers for collection, boxed-expression and boxed-number literals, `YES`/`NO`/`nil`/`Nil` and boxed `@YES`/`@NO` literals, Objective-C type and ownership keywords, and C++ keywords for Objective-C++. Plain C and C++ output is unchanged and `.h` stays C-family. Draft [PR #201](https://github.com/bcinarli/pane-peek/pull/201).

No new token kinds or colours. Limits: the shared `.m` extension needs a decision before acceptance. `@-1`, boxed character literals and contextual property attributes stay plain. Signed-app Preview/Edit, draft and BOM/CRLF Save checks remain for manual review.
