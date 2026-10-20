---
task: html-preview
verdict: Passed
closed: 2026-10-20
---

# Static HTML preview

Local folder CSS/images/fonts and nested stylesheet references render under A39 and the accepted [asset policy](../../../decisions/2026-10-20-html-local-assets.md); automated validation and packaged native Dark sandbox Preview/draft/Save/Undo checks pass, with scripts and remote requests blocked. The approved [WebKit capability](../../../decisions/2026-10-20-webkit-sandbox-capability.md) permits OS-level outgoing connections; implementation and sandbox preview integration accompany this record and remain unpublished. Light/enlarged text, remaining accessibility checks and macOS 26 verification remain pending.
