---
task: bounded-native-find-traversal
verdict: Passed
closed: "2026-11-03"
---

# Bounded native Find traversal

The accepted [#170](https://github.com/bcinarli/pane-peek/issues/170) correction in [PR #171](https://github.com/bcinarli/pane-peek/pull/171) bounds native Find discovery while preserving target selection, document ownership and mode changes, measured against [`3e067cf`](https://github.com/bcinarli/pane-peek/commit/3e067cff9e1c52b45023b5e34a3f92cc0f7d97fe).

| Matched app measurement | `3e067cf` | Correction |
| --- | ---: | ---: |
| Preview-switching CPU, first pass | 8.40 s | 7.51 s |
| Preview-switching CPU, repeat | 8.27 s | 5.92 s |
| Find context capture, sampled CPU | 1.939 s | 0.037 s |

Bundle and executable sizes are unchanged; sampled peak RSS varies by 1–3% within the baseline's observed range, without establishing a memory reduction. The profile confirms lower Find cost; its warmed state limits total-CPU comparison, and Light appearance, full VoiceOver, enlargement/settings and macOS 26 UI coverage remain unverified.
