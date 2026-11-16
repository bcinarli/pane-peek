---
task: dotenv
verdict: Pending
closed: ""
---

# Dotenv

`.env` and `.env.<name>` files follow [Node's dotenv reader](https://github.com/nodejs/node/blob/f378cfcfbfcb673d942ec60d6fb75fbb2a125796/src/node_dotenv.cc): any trimmed text before `=` is the key, an `export ` prefix is a keyword, unquoted values end at a hash, and single-, double- and backtick-quoted values keep hashes, may span lines and keep the rest of the line when no closing quote follows. Only LF ends a line; `${NAME}` stays value text, and scoped names apply only when the suffix is not a known extension. [PR #198](https://github.com/bcinarli/pane-peek/pull/198), draft.

No new token kinds or colours. Node's carry-over of the next line into a value after trailing blanks, and of a value after an empty key, is not modelled. Limits: signed-app Preview/Edit, draft and BOM/CRLF Save checks and a matched signed Release comparison for H9 remain for manual review.
