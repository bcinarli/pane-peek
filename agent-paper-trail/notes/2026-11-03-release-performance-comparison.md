# Release performance comparison

Status: Active

Matched arm64 Release rebuilds compare [v1.2.0 at `3dfa4fb`](https://github.com/bcinarli/pane-peek/commit/3dfa4fbb6181a1dfaae0ad4744df2c4e42fbf134) with [main at `3e067cf`](https://github.com/bcinarli/pane-peek/commit/3e067cff9e1c52b45023b5e34a3f92cc0f7d97fe). Measurements on 3 November 2026 use an Apple M5 with 32 GB RAM, macOS 27.0.1 and Xcode 27.1 / Swift 6.4; the comparison includes all post-release features and refactoring.

| Measurement | 1.2.0 | `3e067cf` | Change |
| --- | ---: | ---: | ---: |
| App bundle | 7.61 MiB | 7.76 MiB | +1.9% |
| Warm launch lifecycle to first frame | 267.2 ms | 272.7 ms | Overlapping ranges |
| Idle app RSS | 110.8 MiB | 110.8 MiB | Similar |
| Text / Markdown app RSS | 128.5 / 143.3 MiB | 129.6 / 144.5 MiB | About +0.9% |
| 24 preview selections, app CPU time | 5.86 s | 7.89 s | +34.6% |
| Preview workload sampled peak app RSS | 252.8 MiB | 254.3 MiB | +0.6% |
| Read 10,000 files through the core | 446.16 ms | 446.67 ms | Similar |
| Core pane-switch cycle with 10,000 files | 3.13 ms | 1.61 ms | −48.6% |
| Near-limit native editor, 60 insertions | 8.82 s | 5.81 s | −34.1% |

Warm startup covers system-interface initialisation to the first frame, excluding boot-cold and first-install behaviour. App CPU and RSS exclude helper processes; preview measurements include accessibility observation. Core and editor timings describe separate component workloads, rather than complete browser-screen latency.

The preview CPU increase comes from contextual Find introduced in [PR #142](https://github.com/bcinarli/pane-peek/pull/142): recursive native-view searches repeatedly evaluate successful branches. The accepted [#170 correction](../specs/001-mvp/evidence/bounded-native-find-traversal.md) in [PR #171](https://github.com/bcinarli/pane-peek/pull/171) bounds that work while preserving Find behaviour.

Results describe one Mac and these workloads. Synthetic browser peak RSS at 100,000 entries rises from 80.5 to 89.5 MiB; native typing peak RSS falls from 104.8 to 100.2 MiB. The comparison covers all post-release changes and does not attribute improvements to individual clusters.
