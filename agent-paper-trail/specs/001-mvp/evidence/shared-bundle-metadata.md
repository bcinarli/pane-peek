---
task: shared-bundle-metadata
verdict: Passed
closed: "2026-11-03"
---

# Shared bundle metadata

[PR #169](https://github.com/bcinarli/pane-peek/pull/169) maintains common static values in the Xcode plist, with drift checks on produced scripted bundles, native archives and Store exports. Actual development/review/release packaging, local Store archiving and native launch/About checks pass; matched Release measurements show a 16-byte bundle increase, unchanged executable/Store app sizes and no established runtime gain. Fresh consent prompts, actual Store export and broader platform/accessibility checks remain unverified.
