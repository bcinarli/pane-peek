---
task: prerelease-hosted-preparation
verdict: Passed
closed: "2026-11-04"
---

# Hosted prerelease preparation

Candidate inputs reach validation before release tests/signing and note generation; review-artifact names include prerelease kind/sequence while stable naming and existing credential/asset restrictions are preserved ([d6d8f4b](https://github.com/bcinarli/pane-peek/commit/d6d8f4b58f3cc1c1ffaee1ce5e35af97a0b53eeb)). Real main preparation from [09d8c0e](https://github.com/bcinarli/pane-peek/commit/09d8c0e6ec98c069787134421c5138a00adb51d3) completed source/CI verification, release tests, signing/notarisation, credential cleanup and allowlisted artifact upload; accepted [downloaded packages and notes](beta-1-3-0.md) pass verification. Browser-quarantined installation and stable upgrade eligibility remain outside the verified scope.
