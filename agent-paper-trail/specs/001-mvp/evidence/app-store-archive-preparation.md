---
task: app-store-archive-preparation
verdict: Passed
closed: 2026-10-20
---

# App Store archive preparation

Native archives and local Store exports based on [`bc43ede`](https://github.com/bcinarli/pane-peek/commit/bc43ede239ddf6c809768d6c33302080b1c35ab7) retain the merged previews, production identity and assigned metadata, with verified signatures, sandbox capabilities, resources and matching profile.

Root navigation can fail with remembered access ([#79](https://github.com/bcinarli/pane-peek/issues/79)); explicit folder selection recovers, and the cause remains unresolved. Clean-profile and Store-delivered installation, native macOS 26 and broader accessibility remain unverified; upload, server validation and submission retain separate gates.
