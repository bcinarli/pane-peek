---
task: docker-ignore
verdict: Pending
closed: ""
---

# Docker ignore

`.dockerignore` and Dockerfile-specific `<name>.dockerignore` files use a Docker dialect of the ignore tokenizer: only a column-one hash starts a comment, patterns are trimmed, an exception marker may be followed by spaces and backslashes keep no Git trailing-space meaning. A role suffix outranks the `Dockerfile.` prefix; Git-ignore names keep their rules. Not published.

No new token kinds or colours. Limits: signed-app Preview/Edit, draft and BOM/CRLF Save checks remain for manual review.
