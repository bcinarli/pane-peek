---
task: shared-bundle-metadata
verdict: Passed
closed: "2026-11-03"
---

# Shared bundle metadata

Common static values now come from the maintained Xcode plist, with drift checks on produced scripted bundles, native archives and Store exports. Actual development/review/release packaging, local Store archiving and native launch/About checks pass; matched Release measurements show a 16-byte bundle increase, unchanged executable/Store app sizes and no established runtime gain. Publication is pending; fresh consent prompts, actual Store export and broader platform/accessibility checks remain unverified.
