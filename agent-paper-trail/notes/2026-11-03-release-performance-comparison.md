# Release performance comparison

Status: Active

Matched arm64 Release rebuilds compare [v1.2.0 at `3dfa4fb`](https://github.com/bcinarli/pane-peek/commit/3dfa4fbb6181a1dfaae0ad4744df2c4e42fbf134) with [main at `3e067cf`](https://github.com/bcinarli/pane-peek/commit/3e067cff9e1c52b45023b5e34a3f92cc0f7d97fe). Measurements on 3 November 2026 use an Apple M5 with 32 GB RAM, macOS 27.0.1 and Xcode 27.1 / Swift 6.4; the comparison includes all post-release features and refactoring.

| Measurement | 1.2.0 | Current main | Change |
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

Startup uses five alternating Apple App Launch trials from system-interface initialisation to completion of the initial frame, excluding boot-cold and first-install behaviour. Settled app samples show approximately 0–0.1% of one CPU core; three preview-selection workloads include a fresh reverse-order check, which also shows higher current CPU time. The preview workload includes accessibility observation and excludes helper processes.

Follow-up Time Profiler samples attribute the increase to contextual Find: total sampled app CPU is 5.984 → 7.760 seconds, with 1.939 seconds in current Find context capture and slightly lower accessibility-reading cost. The two [recursive Find lookups](../../sources/panepeek/FindResponder.swift) repeatedly evaluate successful branches through `lazy.compactMap(...).first`; an isolated unchanged-production-code diagnostic confirms exponential work with nesting, compared with early-return traversal visiting each branch once and returning the same results. This code originates in [PR #142](https://github.com/bcinarli/pane-peek/pull/142) and is unchanged through the measured head.

The accepted [#170 correction](../specs/001-mvp/evidence/bounded-native-find-traversal.md) removes repeated branch evaluation: sampled Find context CPU falls from 1.939 to 0.037 seconds, with lower total CPU in both matched app passes and unchanged bundle size. Automated checks and scoped native keyboard smoke pass; [PR #171](https://github.com/bcinarli/pane-peek/pull/171) targets `main`.

Core and native editor timings are separate focused process measurements, with three alternating trials per version; they do not measure complete browser-screen latency. The synthetic 100,000-entry browser process uses more peak RSS, 80.5 → 89.5 MiB, while native typing process peak RSS falls from 104.8 → 100.2 MiB. Results describe one Mac and the measured workloads, without changing existing acceptance verdicts or attributing an outcome to an individual cluster.
