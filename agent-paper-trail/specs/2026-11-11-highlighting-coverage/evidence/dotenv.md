---
task: dotenv
verdict: Pending
closed: ""
---

# Dotenv

`.env` and `.env.<name>` files follow the Node.js dotenv rules: valid keys with an optional `export` prefix, trimmed unquoted values ending at a hash comment, and single- or double-quoted values that keep hashes and may span lines, ending at the next matching quote. Invalid keys and lines without `=` stay plain, and `${NAME}` stays value text. Scoped names apply only when the suffix is not a known extension. [PR #198](https://github.com/bcinarli/pane-peek/pull/198), draft.

No new token kinds or colours. Limits: signed-app Preview/Edit, draft and BOM/CRLF Save checks remain for manual review.
