# GitHub release updates implementation plan

Status: Active

The [spec](spec.md) owns behaviour and limits; [tasks](tasks.md) owns execution/manual-review state; [validation](validation.md) owns acceptance. Each coding unit requires explicit approval, meaningful red/green evidence, a signed running-app review and manual acceptance before the next unit. Apply tighten followed by probe. Commit, push, merge and distribution retain separate gates under the [shared checklist](../../validation/checklist.md).

## Integration approach

Keep update-specific app code in a small lowercase directory under `sources/panepeek/`, with matching tests under `tests/panepeek/`. Preserve the existing Swift package and synchronised Xcode source groups. Use one provider interface exposing checking, the offered action, cancellable progress and outcomes. Keep presentation state independent of GitHub types and DMG URLs; no generic plugin registry or DMG-only contract for future adapters.

Construct the concrete provider once in the app composition root. An app-wide owner coordinates its operation and local preferences; browser windows and commands receive provider-independent state/actions. Keep download storage separate from browsing grants and avoid recreating browser/editor state when presenting the banner.

| Existing surface | Intended integration |
| --- | --- |
| `PanePeekApp`, `BrowserLifecycle` | Provider selection, shared ownership and active-window lifecycle. |
| `BrowserWindow`, app commands | Manual checking and the accepted nonmodal banner. |
| New update component | GitHub release selection, transport, validation and system handoff behind the replaceable interface. |
| GitHub bundler and Store archive configuration | Positive channel selection, disabled when missing/unknown, with Store exclusion. |
| Packaged and website privacy documents | Actual check/download-host disclosures before shipping. |

## Unit 1: Manual check, download and installer handoff

**Scope:** Deliver the complete manual path, including the provider boundary, explicit GitHub channel, installed-version metadata, native menu/banner, requested download and validated system handoff. Automatic scheduling is excluded.

Require published stable metadata and one unambiguous matching arm64 DMG. Compare numeric version/build values locally, rejecting older or inconsistent candidates. Show build numbers when equal version strings would otherwise look identical. Missing/unknown channel remains disabled; do not infer distribution from bundle identity, sandbox status or receipt absence.

Stream the captured candidate to app-owned staging with explicit metadata/download size, disk-use, timeout and redirect limits. Observe fixed request headers and controlled HTTPS check/download origins, including expected asset redirects. Validate the expected artifact and production publisher before opening, retaining quarantine and platform trust controls. Show Installer opened only after successful handoff; retry an opening failure without downloading again. Cancellation/stale results cannot open an artifact, and cleanup is confined to app-owned files.

**Validation:** Use meaningful red/green coverage for release ordering/eligibility, channel exclusion, state ownership, bounded/cancellable transport, validation and handoff outcomes. Substitute a fake provider at the same composition point to demonstrate replaceability. Observe actual requests, including redirects; configuration alone does not prove privacy. Run the maintained targeted/full checks and verify actual GitHub-review and Store packaging with the unchanged sandbox capabilities.

Review the signed sandbox app with controlled newer-release fixtures and the real download/trust/handoff seam, without offering a real downgrade or changing release metadata. Exercise the accepted banner, help, progress, cancel/retry, window changes and dirty documents, including affected native accessibility checks. Stop for manual acceptance with concise evidence and explicit remaining limits.

## Unit 2: Opt-in automatic reminders

**Dependency:** Unit 1 accepted; separate coding approval.

**Scope:** Add an app-level automatic-check preference, off by default, using the same owner/provider. Persist last-attempt timing and reminder choices locally. Schedule at most daily while running; coalesce activation/wake and concurrent requests, bound failed-check retries and prevent obsolete results after opt-out. Show an available-release banner only when active; quiet no-update/error outcomes and retain Later, Skip this version and explicit manual checking. Never download automatically.

**Validation:** Exercise injected time, preference persistence, activation/wake, opt-out, stale callbacks, one-operation ownership and snooze/skip/manual-check distinctions. Repeat affected signed native privacy, focus and accessibility checks. Stop for manual acceptance; automated green does not close the unit.

## Feasibility and release gates

Resolve runtime artifact validation and the app-owned DMG's sandbox handoff early in Unit 1. If the expected publisher cannot be validated or existing capabilities cannot support the handoff, stop with evidence and review the smallest viable fallback before changing the contract. Do not silently add permissions or weaken validation.

Keep existing required CI checks, release metadata owners, signing/notarisation and candidate acceptance intact. This plan does not authorise credentials changes, hosted publication, release allocation or App Store submission. [Task evidence](evidence/github-release-updates.md) retains native/privacy/platform limits; simulated design checks do not establish runtime acceptance.
