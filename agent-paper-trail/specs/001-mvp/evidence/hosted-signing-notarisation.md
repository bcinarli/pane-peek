---
task: hosted-signing-notarisation
verdict: Passed
closed: "2026-10-19"
---

# Hosted signing and notarisation

Hosted signing and notarisation use an isolated temporary Keychain and remove credentials before publishing review artifacts. Downloaded app integrity, signature, ticket and local Gatekeeper assessment are verified; browser installation and Store readiness retain separate acceptance.

Reference: [PR #55](https://github.com/bcinarli/pane-peek/pull/55), [PR #57](https://github.com/bcinarli/pane-peek/pull/57).
