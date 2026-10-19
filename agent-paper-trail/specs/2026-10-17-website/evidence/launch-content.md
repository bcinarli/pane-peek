---
task: launch-content
verdict: Passed
closed: "2026-10-19"
---

# Launch content

2026-10-19: Download links use GitHub Releases until App Store approval. Support adds GitHub Issues and best-effort response wording. Privacy identifies Cloudflare hosting, iCloud Mail and deletion of support emails/attachments three months after receipt; GitHub Issues is outside that email-retention policy. Provider/retention facts are publisher-reported; mailbox deletion enforcement is outside this website unit. Cloudflare request-data wording follows its [Privacy Policy](https://www.cloudflare.com/privacypolicy/).

2026-10-19, agent-observed: An anonymous HTTPS request to the selected GitHub Releases destination returns 404. The authenticated repository page shows no releases. Public repository/release availability remains unresolved; website changes do not change repository visibility or publish an app release.

2026-10-19, agent-observed: Three pages pass 57 local-reference/fragment checks, image alternatives, unique IDs and external target/opener checks; all four download links use the selected destination. Both unchanged scripts pass syntax checks; whitespace and the repository’s path/privacy rules pass on all 12 changed/new files. Gitleaks 8.30.1 reports no leaks in website text.

2026-10-19, agent-observed in the browser: Home, Support and Privacy have no horizontal overflow at 1280 and 320 px in Light and Dark. New Privacy paragraphs reflow at 320 px; desktop Support copy is readable. The GitHub Issues link is keyboard-reachable with a visible 3 px Mauve outline, followed by the email link. No warning/error logs were captured. Tighten retained shared styles and native links; probe checked retention scope, optional support, public-link availability and provider wording.

2026-10-19: Presented content unit accepted overall. [Support preview](launch-support-preview.png) records the revised contact section. Existing W4 limits remain: VoiceOver, actual browser zoom and real OS-theme switching are unexecuted/unreported. The inactive lightbox’s empty image has no src until opened; it is excluded from loaded-image failure checks. Public GitHub availability and live hosting remain separate publication checks.

Source published in [PR #54](https://github.com/bcinarli/pane-peek/pull/54), targeting main. Merge and website deployment remain separate.
