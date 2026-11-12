---
task: cli-launcher
verdict: Passed
closed: 2026-11-10
---

# Bundled launcher

Local signed checks at `be0a2e2` verified physical paths, literal reveal, GUI-free help and version, exit statuses and exact-copy handoff on cold, running and no-window opens, with target-list focus also confirmed manually. The certificate-signed scripted build and profile-signed Store archive and export preserved the executable launcher and existing capabilities. Store-configuration runtime checks used Developer ID signing, and Apple-distributed runtime remains pending because the local distribution-profile export requires Apple distribution to run. [Distribution-profile restriction](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)

## Release performance

Restoration time ranges overlap. The unpacked bundle grew from 7.96 to 8.56 MiB (+7.6%, 632,436 bytes). The executable accounts for 630,048 bytes of the increase.

Compared main `300b9c0` with CLI candidate `6306bfd` in arm64 Release on Apple M5, macOS 27.0.1, Xcode 27.1 and Swift 6.4. Both diagnostic copies used the same local Developer ID identity, sandbox entitlements and isolated one-pane state. Bundle sizes come from the original Release bundles. Results are medians (ranges) from six alternating trials after warm-up.

| Restored 32-file folder | Main | CLI candidate |
| --- | ---: | ---: |
| Launch to window ordered (ms) | 381 (312–387) | 352 (313–391) |
| Launch to listing ready (ms) | 477 (412–484) | 449 (409–490) |
| App CPU to listing ready (ms) | 350 (340–370) | 355 (340–360) |
| Sampled peak app RSS (MiB) | 114.2 (112.4–114.9) | 116.3 (113.9–118.4) |
| Idle app RSS (MiB) | 119.8 (118.3–120.5) | 119.0 (118.9–119.2) |
| Idle app CPU (% of one core) | 0.51 (0.50–1.01) | 0.51 (0.50–1.00) |

Both diagnostic copies explicitly requested the restored scene. A 20 ms observer confirmed the expected listing or selected file. The process sampler ran every 25 ms with 10 ms CPU resolution, about 0.5 percentage points over the two-second idle sample. Windows stayed occluded, so foreground launch timing remains pending. Cold routes started a fresh app process with uncontrolled OS caches.

| Candidate route | Request to ready (ms) | App CPU (ms) | Sampled peak app RSS (MiB) |
| --- | ---: | ---: | ---: |
| Native folder, cold | 559 (542–564) | 455 (440–460) | 123.0 (120.3–123.8) |
| CLI folder, cold | 592 (585–600) | 475 (460–490) | 128.2 (125.7–131.8) |
| Native file, app running | 279 (276–284) | 210 (200–220) | 149.1 (148.0–152.5) |
| CLI file, app running | 301 (294–305) | 210 (200–220) | 149.5 (148.7–151.3) |

The CLI process is measured separately. Cold handoff took 127 ms (124–129), with 11.3 ms CPU (11.2–11.6) and 17.30 MiB peak RSS (17.30–17.31). With PanePeek running, handoff took 74 ms (73–78), with 11.3 ms CPU (11.2–11.5) and 17.28 MiB peak RSS (17.28–17.31).
