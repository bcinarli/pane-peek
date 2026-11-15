---
task: docker-ignore
verdict: Passed
closed: "2026-11-15"
---

# Docker ignore

`.dockerignore` and Dockerfile-specific `<name>.dockerignore` files use a Docker dialect of the ignore tokenizer: lines end at LF or CRLF, only a column-one hash starts a comment, Unicode whitespace is trimmed around patterns and exception markers, and backslashes keep no Git trailing-space meaning. A role suffix outranks the `Dockerfile.` prefix; Git-ignore names keep their rules. [PR #196](https://github.com/bcinarli/pane-peek/pull/196).

Signed-app Preview/Edit, draft recolouring, Undo/Redo, byte-preserving Save, keyboard and VoiceOver passed in [manual review](https://github.com/bcinarli/pane-peek/pull/196#issuecomment-6875384594).

The matched signed Release comparison (`4e8ba6b` → `3cbe90e`) measured native Preview/Edit, typing, recolouring and switching. At about 960 KB, usable Preview rose from 32 to 82 ms for `.dockerignore` and from 61 to 80 ms for `Dockerfile.dockerignore`, close to the 78 ms Git-ignore control. Edit stayed near 3 ms.

Median PanePeek CPU time across measured workload phases rose from 1.15 to 1.37 s. Settled idle CPU was 0.022% before and 0.024% after, as a share of one core. Idle RSS stayed near 72 MiB, sampled peak RSS rose from 161 to 173 MiB, and the signed bundle grew by 1,456 bytes.
