---
task: trash-folder-access-recovery
verdict: Passed
closed: "2026-10-20"
---

# Trash folder-access recovery

Local implementation adds a native exact-parent chooser after a permission-denied Trash call and one revalidated retry of captured pending items. Cancellation, partial outcomes, source replacement and retained access use the existing mutation/document guards; Desktop Trash and relaunch are accepted for the presented scope; publication is pending.

Full app tests and the development bundle pass on macOS 27.0.1 with Swift 6.4. The initial recovery regression failed before implementation; focused checks protect partial-batch retry, cancellation, replacement rejection, access lifetime, denial classification and window ownership. Run `node scripts/test.mjs` and `node scripts/build-app.mjs` with the documented Xcode selection.

An isolated non-shipping denial simulation exercised the unchanged native chooser and actual system Trash using disposable files: Escape preserves the source, repeated denial returns without another prompt, the wrong folder is rejected, and allowing the matching folder retries successfully. Native accessibility exposes the chooser message and named Cancel/Allow Access controls. Tighten/probe retained captured identities and access through refresh; wrong-folder validation uses its own error rather than misleading filesystem-permission guidance. Desktop deletion and relaunch pass in the new candidate. Light appearance, VoiceOver, text enlargement, contrast and accessibility settings remain unverified.
