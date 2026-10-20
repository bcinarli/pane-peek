---
task: privacy-secrets-checker
verdict: Passed
closed: "2026-10-17"
---

# Shared privacy and secrets checker

The privacy checker applies exact reviewed exceptions, rejects sensitive files and credentials, and redacts scanner failures. PR CI and opt-in local hooks share the checker; hooks preserve existing custom tooling.
