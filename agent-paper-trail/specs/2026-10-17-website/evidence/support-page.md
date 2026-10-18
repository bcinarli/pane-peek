---
task: support-page
verdict: Passed
closed: "2026-10-18"
---

# Support page evidence

## Implementation and content

2026-10-18: Added static `website/support/index.html` with getting-started guidance, eight shortcuts, five native FAQ disclosures and a labelled `support@example.com` mailto placeholder. Homepage header/footer and Support return links share the existing CSS themes. Product wording was checked against the root README and native toolbar/menu implementations; folder-opening instructions use Directory actions and Command-L. No Swift app code changed.

## Targeted checks

2026-10-18, agent-observed: Both HTML documents pass nesting, unique-ID, heading, image-alternative and table-header checks. All 37 href/src references and local fragments resolve, including three explicitly allowed App Store placeholders and one email placeholder. No JavaScript, inline event handlers or pre-launch copy; CSS brace/variable checks pass. No artificial behaviour tests added for native HTML and layout.

2026-10-18, agent-observed in the browser: Latte and Macchiato Support layouts checked at 1280 and 320 px; live system-dark page also checked at 836 px. All five FAQs open with Enter and close with Space in both themes. With all five expanded at 320 px, neither theme overflows or clips answer text; shortcut tables fit within 280 px. Homepage navigation reflow checked at 640 px in Latte and 320 px in Macchiato. Header/footer Home–Support round trips, all four section links and the skip link pass; skip activation focuses main. Mailto target and associated placeholder description inspected without launching a mail client or sending email.

2026-10-18: Theme review copies retain the production CSS, changing only its dark-query condition and resolving fixture URLs for local assets/anchors. This checks each rendered theme without changing system appearance. Observed colour values give minimum text/accent contrast of 4.79:1 in Latte and 6.62:1 in Macchiato; keyboard text exceeds 6.5:1. Visible 3 px focus outlines contrast at 4.79:1 and 8.74:1 respectively. Tighten retained shared styles and native HTML; probe corrected the folder-opening menu reference and checked expanded answers and cross-page navigation.

2026-10-18: Repository privacy/path rules pass on all 18 changed files; Gitleaks 8.30.1 directory scan reports no leaks. All 115 local Markdown link target paths resolve and whitespace checks pass. The live preview reports no browser errors or warnings.

## Closure and remaining scope

2026-10-18: Presented local Support scope accepted overall by Bilal. No commit or PR exists for this unpublished unit. VoiceOver, actual browser zoom and actual system-theme switching remain unexecuted/unreported under W4. The placeholder email and App Store destinations require replacement before publication. Privacy and hosting remain separate work; no commit, push or deployment performed.

## Confirmed contact revision

2026-10-18: Bilal confirmed support@panepeek.app is working. The placeholder has been replaced in the current [interaction/contact revision](page-interactions.md), whose targeted checks pass and manual review remains pending. This supersedes the contact-placeholder prerequisite above; email-provider/hosting disclosures and the real App Store destination remain separate launch work.
