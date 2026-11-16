---
task: kotlin
verdict: Pending
closed: ""
---

# Kotlin

`.kt` and `.kts` files use a focused Kotlin scanner: hard keywords, soft and modifier keywords outside member and declaration positions, `true`/`false`/`null`, character literals, single-line and raw strings with `$name` and `${…}` templates as references, validated number forms, annotations and labels as references, nested block comments and a script shebang. Template and string nesting uses an explicit stack, so deep nesting cannot exhaust the call stack. [PR #199](https://github.com/bcinarli/pane-peek/pull/199).

No new token kinds or colours. Limits: multi-dollar raw strings, `$` before backticked names and some contextual soft-keyword uses stay approximate. Signed-app functional review passed, including draft retention, Undo/Redo and byte-preserving Save. VoiceOver and other affected accessibility checks passed in manual review. Manual acceptance, including the measured performance cost below, remains pending.

Matched signed arm64 Release trials against accepted main `41573f9` on Apple M5 / macOS 27.0.1 / Xcode 27.1 found no material shared-path regression; three measured trials after warm-up gave median bundle size 8.609 → 8.639 MiB and idle RSS 99.5 → 99.9 MiB, with median idle CPU below the sampler's 0.33%-of-one-core resolution. The ten-case native workload changed from 2.67 to 3.02 s elapsed, 1.47 to 1.84 s CPU and 127.0 to 137.9 MiB sampled peak RSS; the new 960 KB language case opened in 150 ms (145–152), completed three recoloured insertions in 347 ms (345–351) and three Preview/Edit cycles in 13 ms, versus 37/91/10 ms for baseline plain text. Opening, editing and switching are native component timings using in-memory fixtures, excluding filesystem reads and browser selection overhead; CPU/RSS cover the app process only.
