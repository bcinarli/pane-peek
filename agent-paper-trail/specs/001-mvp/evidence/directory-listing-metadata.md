---
task: directory-listing-metadata
verdict: Passed
closed: "2026-10-22"
---
# Directory listing metadata

The listing reuses entry type information and enumerated URLs while retaining package, hidden-file, link, date and size behaviour in both access modes; local comparisons show reduced listing time. Regressions pass and the signed app loads Home and a large disposable directory, including both pane layouts, on macOS 27. macOS 26 and fresh/denied-access checks remain pending; this does not establish a reduction in macOS privacy-decision waits. [PR #102](https://github.com/bcinarli/pane-peek/pull/102).
