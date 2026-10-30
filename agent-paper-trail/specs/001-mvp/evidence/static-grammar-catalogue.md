---
task: static-grammar-catalogue
verdict: Passed
closed: "2026-10-30"
---

# Static grammar catalogue

The reviewed catalogue is accepted, building on commit `bf6fbcd`, replacing language dispatch with registered tokenizers and extracting the Swift/strict-JSON scanner unchanged from orchestration. Completeness and regression checks plus signed sandbox Dark-mode Swift/JSON/TSX/configuration editing checks pass; warm native timings and measured resource use remain comparable, with about 18 KB (0.15%) added to the review bundle. Broader Light appearance, VoiceOver, enlarged text/contrast and macOS 26 checks remain unverified; existing near-limit editing costs and remaining #133 format-family scope are retained.
