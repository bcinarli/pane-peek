---
task: dotenv
verdict: Passed
closed: "2026-11-16"
---

# Dotenv

`.env` and `.env.<name>` files follow [Node's dotenv reader](https://github.com/nodejs/node/blob/f378cfcfbfcb673d942ec60d6fb75fbb2a125796/src/node_dotenv.cc): any trimmed text before `=` is the key, an `export ` prefix is a keyword, unquoted values end at a hash, and single-, double- and backtick-quoted values keep hashes, may span lines and keep the rest of the line when no closing quote follows. Only LF ends a line; `${NAME}` stays value text, and scoped names apply only when the suffix is not a known extension. [PR #198](https://github.com/bcinarli/pane-peek/pull/198).

No new token kinds or colours. Node's carry-over of the next line into a value after trailing blanks, and of a value after an empty key, is not modelled. Signed-app functional review passed, including draft retention, Undo/Redo and byte-preserving Save. VoiceOver and other affected accessibility checks passed in manual review. Scope and manual review, including the measured performance cost below, were accepted on 2026-11-16.

Matched signed arm64 Release trials against accepted main `41573f9` on Apple M5 / macOS 27.0.1 / Xcode 27.1 found no material shared-path regression; three measured trials after warm-up gave median bundle size 8.609 → 8.625 MiB and idle RSS 99.5 → 100.0 MiB, with median idle CPU below the sampler's 0.33%-of-one-core resolution. The ten-case native workload changed from 2.67 to 2.96 s elapsed, 1.47 to 1.74 s CPU and 127.0 to 136.5 MiB sampled peak RSS; the new 960 KB language case opened in 117 ms (116–118), completed three recoloured insertions in 279 ms (274–281) and three Preview/Edit cycles in 13 ms, versus 36/91/11 ms for baseline plain text. Opening, editing and switching are native component timings using in-memory fixtures, excluding filesystem reads and browser selection overhead; CPU/RSS cover the app process only.
