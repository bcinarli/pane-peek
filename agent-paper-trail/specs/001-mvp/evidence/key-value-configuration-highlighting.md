---
task: key-value-configuration-highlighting
verdict: Passed
closed: "2026-10-30"
---

# Key/value configuration highlighting

The reviewed [Git, EditorConfig, npm and Yarn Classic inventory](../spec.md#keyvalue-configuration-highlighting), included in [PR #145](https://github.com/bcinarli/pane-peek/pull/145) and built on catalogue commit `61bd665`, is accepted with passing regression and BOM/CRLF preservation checks plus signed sandbox Dark-mode previews of all four exact dotfiles and Git editing/Undo/Save smoke checks. Warm small-config colouring/presentation stays below 3 ms, the 900 KB Git and long npm fixtures finish in about 322/271 ms, and the review bundle grows by about 77 KB (0.63%) without a new dependency; existing near-limit insertion costs remain. Light appearance, full VoiceOver, enlarged text/contrast and macOS 26 checks remain unverified; [further coverage](https://github.com/bcinarli/pane-peek/issues/144) and the [scanner-helper refactor](https://github.com/bcinarli/pane-peek/issues/143) retain separate scope.
