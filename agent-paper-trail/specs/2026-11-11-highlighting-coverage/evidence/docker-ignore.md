---
task: docker-ignore
verdict: Pending
closed: ""
---

# Docker ignore

`.dockerignore` and Dockerfile-specific `<name>.dockerignore` files use a Docker dialect of the ignore tokenizer: lines end at LF or CRLF, only a column-one hash starts a comment, Unicode whitespace is trimmed around patterns and exception markers, and backslashes keep no Git trailing-space meaning. A role suffix outranks the `Dockerfile.` prefix; Git-ignore names keep their rules. [PR #196](https://github.com/bcinarli/pane-peek/pull/196).

No new token kinds or colours. Limits: signed-app Preview/Edit, draft and BOM/CRLF Save checks and a matched Release comparison remain for manual review; acceptance also waits on Unit 1's H9.
