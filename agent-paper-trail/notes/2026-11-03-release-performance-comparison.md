# Release performance comparison

Status: Active

Preview CPU is 3.5% above 1.2.0 after the [Find correction](../specs/001-mvp/evidence/bounded-native-find-traversal.md). Startup and memory remain close; pane switching and editing are faster.

Matched arm64 Release builds: [1.2.0 at `3dfa4fb`](https://github.com/bcinarli/pane-peek/commit/3dfa4fbb6181a1dfaae0ad4744df2c4e42fbf134) versus [main at `cf4a45c`](https://github.com/bcinarli/pane-peek/commit/cf4a45ce3d2d439ea3dfb5d9e83f2f8cd60ac96f). Measured 3 November 2026 on Apple M5 / 32 GB RAM, macOS 27.0.1 and Xcode 27.1 / Swift 6.4.

| Measurement | 1.2.0 | `cf4a45c` | Change |
| --- | ---: | ---: | ---: |
| App bundle | 7.61 MiB | 7.76 MiB | +1.9% |
| Warm startup to first frame | 243.8 ms | 243.6 ms | Similar; ranges overlap |
| Idle app RSS | 107.1 MiB | 107.6 MiB | +0.5% |
| Text / Markdown app RSS | 127.7 / 142.3 MiB | 128.9 / 144.0 MiB | About +1% |
| 24 preview selections, app CPU | 5.95 s | 6.16 s | +3.5% |
| Preview workload, sampled peak app RSS | 248.2 MiB | 248.9 MiB | +0.3% |
| Core read, 10,000 files | 426.05 ms | 433.60 ms | +1.8% |
| Core pane-switch cycle, 10,000 files | 3.14 ms | 1.53 ms | -51.3% |
| Near-limit native editor, 60 insertions | 8.19 s | 5.42 s | -33.8% |

Warm startup measures system-interface initialisation through the first frame; cold and first-install launch are unmeasured. CPU/RSS cover the app process, excluding helpers; preview CPU includes accessibility observation. Core/editor rows are component timings. Results apply to one Mac and these workloads.
