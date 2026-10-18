---
task: privacy-page
verdict: Passed
closed: "2026-10-18"
---

# Privacy page evidence

## Implementation and factual basis

2026-10-18: Added static `website/privacy/index.html`, shared Latte/Macchiato appearance and Home/Support footer links. Publisher is Bilal Cinarli; contact links to the existing labelled Support placeholder. No native app source or design asset changed. Release captures remain pending final native UI work, including full Macchiato dark appearance.

2026-10-18, source inspection: `Package.swift` has no external dependencies. App source has no network client, advertising/analytics SDK or developer reporting endpoint. `TextPreview`, image/video previews and filesystem operations use local file URLs; Markdown uses native text rendering without loading remote images. `Favourites` stores folder paths in UserDefaults; `WindowRestoration` stores directory pair, layout and frame. Wording preserves the [MVP local-only boundary](../../001-mvp/spec.md#scope-boundaries) for cloud-managed folders and mounted volumes. This is a source review, not a runtime network capture or an audit of Apple's internal services.

2026-10-18: Apple/platform wording checked against [App privacy details](https://developer.apple.com/app-store/app-privacy-details/), [Mac analytics sharing](https://support.apple.com/guide/mac-help/mh27990/mac) and [Apple's Privacy Policy](https://www.apple.com/legal/privacy/en-ww/). The policy distinguishes app telemetry from optional Apple diagnostics and App Store handling. Support purpose/retention text is proposed policy for publisher review, not an observed mailbox configuration.

## Targeted checks

2026-10-18, agent-observed: Three HTML documents pass nesting, unique IDs, heading order and image-alternative checks; all 57 href/src references and local fragments resolve. Six external links consist of four requested App Store placeholders and two official Apple references. No JavaScript, inline event handlers or pre-launch copy; CSS braces and variables pass.

2026-10-18, agent-observed in the browser: Privacy reviewed in Latte and Macchiato at 1280 and 320 px, plus the live system-dark page at 836 px. No horizontal overflow or clipped policy paragraphs at 320 px. Home Latte and Support Macchiato footers reflow at 320 px. Home/Support footer routes to Privacy and the policy contact route to Support pass. Skip activation focuses main; keyboard links have visible 3 px focus. Publisher, policy date, placeholder notice and current-page indication are present. Browser error/warning log is empty.

2026-10-18: Forced-theme review copies retain production CSS with only the dark-query condition changed and fixture URLs resolved. Actual system appearance was not changed. Existing palette contrast values apply to the inherited colours: text/accent minimum 4.79:1 Latte and 6.62:1 Macchiato; focus 4.79:1 and 8.74:1. Tighten retained a single reading column and shared static styles; probe checked platform exceptions, unconfirmed operational claims, mobile footers and contact navigation.

2026-10-18: HTTP 200 for Home, Support, Privacy and shared CSS. Privacy/path rules pass on all 20 changed files; Gitleaks 8.30.1 directory scan reports no leaks. All 121 local Markdown target paths resolve; whitespace checks pass.

## Closure and remaining publication scope

2026-10-18: Bilal accepted the presented local page and policy wording overall. No commit or PR exists for this unpublished unit. VoiceOver, actual browser zoom and actual system-theme switching remain unexecuted/unreported under W4. Configure the active email provider and support retention before publication; add website hosting/request-data disclosures when the host is selected. Replace the contact/App Store placeholders and finalise native release screenshots. No commit, push, deployment or app UI integration performed.

## Confirmed contact revision

2026-10-18: Bilal confirmed support@panepeek.app is working. The placeholder has been replaced in the current [interaction/contact revision](page-interactions.md), whose targeted checks pass and manual review remains pending. This supersedes the contact-placeholder prerequisite above; email-provider/hosting disclosures and the real App Store destination remain separate launch work.
