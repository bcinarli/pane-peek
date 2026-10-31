---
task: bounded-directory-reads
verdict: Passed
closed: "2026-10-31"
---
# Bounded directory reads

Incremental reads pass cancellation, search-budget, complete-listing and access-lifetime checks, including consumed work from failed or rejected listings; matched optimised comparisons against `c1466f0` reduce bounded-search time, CPU use and peak memory, with ordinary-listing and combined pane timings within observed variation and a 7,936-byte release-bundle increase. The signed macOS 27 app verifies the traversal-limit notice, search clearing, independent panes, selection/sorting, hidden filtering and Quick Look targeting, and the unit's manual behaviour review passed. Spoken VoiceOver and native macOS 26 checks remain unverified; [PR #155](https://github.com/bcinarli/pane-peek/pull/155) carries the reviewed implementation and measurement provenance.
