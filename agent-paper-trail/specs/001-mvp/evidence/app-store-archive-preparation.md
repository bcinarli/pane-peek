---
task: app-store-archive-preparation
verdict: Passed
closed: 2026-10-20
---

# App Store archive preparation

Native archives and local Store exports preserve the production identity and assigned metadata, with verified signatures, sandbox capabilities, resources and matching profile ([implementation](https://github.com/bcinarli/pane-peek/commit/a1c3cd0bf7d79ec8ef070916551fdfa1369ff5c4)).

Root navigation can fail with remembered access ([#79](https://github.com/bcinarli/pane-peek/issues/79)); explicit folder selection recovers, and the cause remains unresolved. Clean-profile and Store-delivered installation, native macOS 26 and broader accessibility remain unverified; upload, server validation and submission retain separate gates.
