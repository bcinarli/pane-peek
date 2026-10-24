---
status: Accepted
date: 2026-10-24
supersedes:
  - 2026-10-20-webkit-sandbox-capability.md
superseded_by: ""
---

# GitHub release updates

## Decision and rationale

GitHub-distributed builds may check public PanePeek release metadata and download a DMG on request, then open it for manual installation. [update spec](../specs/2026-10-24-github-release-updates/spec.md) owns the behaviour. Mac App Store builds do not expose or run this mechanism. Downloads never replace the application or quit it automatically.

Use the existing public GitHub Releases endpoint without authentication. Compare release and installed versions locally. Automatic availability checks require opt-in; downloading always requires the Download action. This keeps notification and manual installation within a small native component without adding an installer framework or a separately published feed.

Expose provider-independent update state and actions through one small replaceable interface, selected at app startup. Keep GitHub metadata, transport and DMG handling inside its adapter. Replacing an implemented adapter changes the app's wiring rather than browser views. A future framework still requires its own dependency, packaging, signing and privacy validation; no runtime plugin loader is required.

## Privacy and sandbox boundary

Update requests send no file contents, paths, installed version, identifiers, device/hardware/system profile, locale, credentials or cookies. Use fixed request metadata without app/OS version information. Keep update preferences and dismissal state locally; add no tracking, advertising, personalisation or analytics. Validate the actual request behaviour, including download redirects, before acceptance.

Hosts necessarily receive IP addresses and connection metadata under their privacy terms. [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) covers request processing; zero third-party processing cannot be promised. macOS installation and assessment services retain their own system behaviour. Runtime privacy disclosures must cover the actual check and download hosts before this feature ships.

Carry forward the [WebKit capability decision's](2026-10-20-webkit-sandbox-capability.md) offline preview policies and the [production distribution decision's](2026-10-20-production-sandbox-distribution.md) identity, file-access, persistence and release gates. Required entitlements remain exactly App Sandbox, user-selected read/write access, app-scoped bookmarks and network-client access. The additional network purpose is confined to GitHub update checking and requested downloads; Store previews retain their existing capability without enabling the updater. No incoming-network, filesystem, installer-helper or Hardened Runtime exception is added.

## Alternatives and limits

[Sparkle](https://sparkle-project.org/documentation/publishing/#downloading-from-a-web-site) supports informational updates as well as installation. It remains an alternative if installation requirements expand, but its framework and feed are unnecessary for the selected manual-install flow. A static website manifest adds publication coordination and another host without removing connection metadata.

Checks run only while PanePeek is running. Existing installations need a manual upgrade to acquire the feature. Automatic replacement, relaunch, background agents, delta updates and Store updating are outside scope. API availability and rate limits can delay discovery; failed checks must not claim that the app is current.

## [Changed] Shared Updates window

Manual checks and automatic available-update reminders use one app-owned native Updates window. Reusing the existing controls keeps presentation and cancellation consistent. A separate browser banner would avoid obscuring content but adds a second update surface. Automatic presentation waits for an active app and does not make the window key or take editor focus; quiet outcomes remain hidden. The update spec owns reminder choices and scheduling.
