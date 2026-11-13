---
task: cli-profile-line-boundary
verdict: Passed
closed: 2026-11-12
---

# Profile line boundaries on uninstall

Signed manual review verified that uninstall removes the launcher and preserves separate settings when later text follows an original profile with no final newline. Automated checks cover later settings with and without a leading newline. [PR #192](https://github.com/bcinarli/pane-peek/pull/192)

Optimized cleanup medians over 20,000 removals were 59.2/58.9 ms elapsed and 58.4/58.2 ms CPU before/after the fix, with overlapping ranges and 5.94 MiB peak RSS for both. The unpacked Release bundle grew by 13,056 bytes (+0.15%).
