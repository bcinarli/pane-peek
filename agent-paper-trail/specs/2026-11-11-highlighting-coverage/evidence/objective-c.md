---
task: objective-c
verdict: Pending
closed: ""
---

# Objective-C

`.m` and `.mm` files use an Objective-C option of the C-family scanner: `@` directives as keywords, `@"…"` strings, `@` markers for collection, boxed-expression and boxed-number literals, `YES`/`NO`/`nil`/`Nil` and boxed `@YES`/`@NO` literals, Objective-C type and ownership keywords, and C++ keywords for Objective-C++. Plain C and C++ output is unchanged and `.h` stays C-family. [PR #201](https://github.com/bcinarli/pane-peek/pull/201).

No new token kinds or colours. The [filename policy](../../../decisions/2026-11-16-objective-c-filename-policy.md) assigns `.m` and `.mm` to this dialect. Limits: `@-1`, boxed character literals and contextual property attributes stay plain. Signed-app functional review passed, including draft retention, Undo/Redo and byte-preserving Save. VoiceOver and other affected accessibility checks passed in manual review. Manual acceptance, including the measured performance cost below, remains pending.

Matched signed arm64 Release trials against accepted main `41573f9` on Apple M5 / macOS 27.0.1 / Xcode 27.1 found no material shared-path regression; three measured trials after warm-up gave median bundle size 8.609 → 8.626 MiB and idle RSS 99.5 → 99.8 MiB, with median idle CPU below the sampler's 0.33%-of-one-core resolution. The ten-case native workload changed from 2.67 to 3.00 s elapsed, 1.47 to 1.82 s CPU and 127.0 to 135.1 MiB sampled peak RSS; the new 960 KB language case opened in 131 ms (128–136), completed three recoloured insertions in 333 ms (330–337) and three Preview/Edit cycles in 12 ms, versus 36/92/11 ms for baseline plain text. Opening, editing and switching are native component timings using in-memory fixtures, excluding filesystem reads and browser selection overhead; CPU/RSS cover the app process only.
