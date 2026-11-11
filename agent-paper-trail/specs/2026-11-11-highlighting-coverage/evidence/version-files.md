---
task: version-files
verdict: Pending
closed: ""
---

# Version files

`.ruby-version`, `.python-version` and `.tool-versions` use one focused scanner with a format per reader: rbenv's first word of the file, pyenv's first word per line with hash-led comment lines, and asdf's tool name, multiple versions including `ref:`, `path:` and `system`, and word-led hash comments. Lookalikes and `.node-version` keep their existing treatment. Not published.

No new token kinds or colours. Limits: signed-app Preview/Edit, draft and BOM/CRLF Save checks remain for manual review.
