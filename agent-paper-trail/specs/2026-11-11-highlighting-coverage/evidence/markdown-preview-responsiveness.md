---
task: markdown-preview-responsiveness
verdict: Passed
closed: "2026-11-15"
---

# Markdown Preview responsiveness

[#203](https://github.com/bcinarli/pane-peek/issues/203) prepares attributed Markdown on a worker and installs only the current result in the native text view. In matched Developer ID-signed arm64 Release runs of the native preview host (0c15c54 baseline, candidate from the same revision, Xcode 27.1 and macOS 27.0.1), the median longest main-thread callback gap on the 960 KB fixtures fell from 234 to 46 ms for `.md` and from 226 to 45 ms for `.markdown`; time to usable Preview rose from 1,095 to 1,158 ms and from 1,109 to 1,152 ms respectively. Near-limit workload CPU was similar (1.17–1.26 s baseline, 1.19–1.27 s candidate), median peak RSS was 182/186 to 182/195 MiB, and the unpacked app grew 16,880 bytes.

Follow-up traces measured a 38–42 ms later parse start while the new render task waited to run on the main actor. Parsing, formatting and layout took similar amounts of time, and the traced run reached usable Preview 25–29 ms later.

Automated checks and signed-app interactive validation passed for [PR #205](https://github.com/bcinarli/pane-peek/pull/205) at `b662de5`. The signed performance comparison exercised the offscreen preview host.
