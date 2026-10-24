---
status: Active
date: 2026-10-24
supersedes: []
superseded_by: ""
---

# GitHub release updates specification

## Scope

Explicitly enabled GitHub-distributed builds provide manual release checks, requested DMG downloads and system handoff for manual installation. Mac App Store builds and unconfigured development builds do not expose or run this mechanism. Automatic availability checking defaults off. No automatic download, application replacement, quit/relaunch, background agent, delta update or runtime plugin loader is included.

The [accepted decision](../../decisions/2026-10-24-github-release-updates.md) owns provider choice and the narrow network exception. Preserve the [native app baseline](../001-mvp/spec.md#accessibility-baseline), existing browser/editor state and Save / Discard / Cancel safeguards.

## Release checks and reminders

Check the fixed public PanePeek GitHub Releases endpoint without authentication. The explicit Check for Updates command opens one app-owned native Updates window, showing checking progress followed by an available release, a current installation or an honest failure. It can receive keyboard focus because it is explicitly invoked, retains browser/editor state and works without an open browser window. Repeating the command raises the existing window without starting a duplicate operation. Reopening within one minute reuses the last successful result; later checks refresh it. Failed checks remain failures, and server-requested rate limits retain their retry deadline. Only published stable releases with a valid matching DMG are eligible. Compare numeric version/build values against installed bundle metadata locally; never offer an older candidate or use repository main metadata as an available release. Include build numbers in the update presentation when equal version strings need disambiguation.

The app-menu Automatically Check for Updates preference defaults off. Opt-in automatic availability checks run no more frequently than every 24 hours while the app is running and do not download updates. Persist attempt timing before a request, including manual attempts, so relaunches and failures do not trigger extra automatic requests. Manual checks override this schedule. No-update and failed automatic checks stay quiet. Present an available update in the same app-owned Updates window while PanePeek is active, waiting for activation if necessary. Automatic presentation must not make the window key, take editor keyboard focus or change browser/draft state. Keep the offered result until a choice is made. Later, closing and Escape defer its reminder until the next day; Skip this version suppresses its automatic reminders while explicit manual checking remains available. Automatic presentation offers Skip this version, Later and Download. Explicit manual invocation raises the same window and may take focus, reusing an already presented result or operation.

The app-owned Updates window follows the system appearance using Catppuccin Macchiato in Dark and Latte in Light, including surfaces, text and Mauve controls. This popup-specific Light palette takes precedence over the shared native Light surface rule; other app surfaces retain their existing appearance.

## Download and manual installation

The shared [Updates window](../../design/001-mvp/README.md#updates-window) shows `PanePeek <available version> is available` above `Installed version: <installed version>`. Its primary action is Download, with `Download the DMG and install it manually.` as accessible help/tooltip.

Requested download progress, cancellation, errors and completion remain in the same Updates window. Closing that window cancels a pending check or download; an installer handoff already in progress is allowed to finish before closure. Download only on request, streaming to bounded app-owned storage with progress, cancellation and retry. Validate the expected release artifact before handing it to macOS; failed or unavailable validation cannot open it. Cancellation and obsolete results cannot publish or open a completed download. Retain one app-wide operation across windows, clean up app-owned partial downloads and keep browser folder grants separate from update storage.

A successful system handoff shows Installer opened and `Quit PanePeek, then drag PanePeek to Applications.`, with Done and Open installer again. A handoff failure offers retry without claiming success or requiring another download. PanePeek never replaces itself or quits automatically; ordinary guarded quitting remains available.

## Replaceable integration

Expose provider-independent update state and actions through one small interface, selected once at app startup. Keep GitHub responses, transport and DMG handling inside the current adapter. Browser views must not depend on provider response types or require a DMG result from every future provider. Replacing an implemented adapter changes composition wiring rather than browser screens; integrating a new framework still requires its own dependency, packaging, signing and privacy work.

## Privacy and platform constraints

Send no file contents, paths, installed version, identifiers, device/hardware/system profile, locale, credentials or cookies. Use fixed request metadata without app/OS version information. Keep settings, last-check timing and reminder preferences locally. Add no tracking, advertising, personalisation or analytics. Actual check and redirected download requests must satisfy this boundary.

Hosts necessarily receive IP addresses and connection metadata under their privacy terms. Zero third-party processing cannot be promised. Runtime privacy disclosures must cover actual check/download hosts before shipping. macOS installation and trust services retain their own system behaviour.

Keep the [accepted sandbox capabilities](../../decisions/2026-10-24-github-release-updates.md#privacy-and-sandbox-boundary), offline preview policies and distribution gates. No installer helper or additional sandbox exception is authorised.

## Known limits

Completed installers retained for reopening count against a 512 MiB storage cap; further downloads are refused when it is full. Checks run only while PanePeek is running; existing installations need a manual upgrade to acquire the feature. API availability, rate limits and absent/changed release assets can delay discovery. Failed checks cannot establish that the app is current. Runtime artifact validation and sandbox-to-Finder handoff require native verification; the design preview performs neither. Automatic installation and App Store updating remain outside scope.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| U1 | Positive GitHub-channel isolation and truthful stable-release/version/build selection; no updater in Store or unconfigured builds. |
| U2 | Manual checks and automatic available-update reminders share one native Updates window. Both retain browser/editor state and expose the accepted copy/help with appropriate focus ownership. |
| U3 | Requested bounded download, cancellation, validation and retry produce an honest manual-installer handoff without app replacement or automatic quit. |
| U4 | Opt-in daily checking, local snooze/skip state and manual-check overrides work without automatic downloads or closed-app polling. |
| U5 | Observed check/download requests and shipped privacy disclosures satisfy the accepted data and host-processing boundary. |
| U6 | A replacement provider integrates through the same app boundary and one composition point without provider-specific browser changes. |
| U7 | Affected native keyboard, VoiceOver, contrast, text-enlargement and system accessibility checks satisfy the app-wide baseline. |

[Validation](validation.md) owns verdicts. The [plan](plan.md) owns unit boundaries and gates; the native MVP A40 row aggregates U1–U7 without extending the earlier release waiver.
