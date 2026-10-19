---
task: github-release-preparation
verdict: Passed
closed: "2026-10-19"
---

# GitHub release preparation

The [plan](../plan.md#github-release-preparation) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns review and publication state.

## Executed checks

- 2026-10-18: all eight initial source/CI and changelog regressions fail against a no-op scaffold, then pass with implementation. A separate older-main selection regression fails before the source-selection correction. All nine final release-review regressions and all 59 tooling tests pass. Source eligibility was also exercised against actual successful main [build/test](https://github.com/bcinarli/pane-peek/actions/runs/39164693768) and [privacy](https://github.com/bcinarli/pane-peek/actions/runs/39164693796) runs for merged commit `8a7c980` using a clean disposable checkout.
- 2026-10-18, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: the workflow's release-test command passes all 573 tests (111 app, 462 core) with nine expected known issues. Three existing test-only unused-expression warnings remain. Development and optimised release bundling pass; all five workflow outputs resolve to the actual package and metadata. Development bundling leaves those outputs unchanged; both modes retain byte-identical version 0.1.0, build 4.
- 2026-10-18: the checksum passes; extraction preserves all ten bundle file contents and modes, including notices and the executable. Notes match metadata and Unreleased content; existing notes, mismatched checksums and mismatched app metadata are refused. An isolated extracted-app review copy launches with a separate preferences domain and disposable directories; its running process is confirmed. Native interaction and accessibility outcomes remain unreported.
- 2026-10-18: workflow YAML and all shell steps parse. Manual-only dispatch, the main guard, pinned actions, unpersisted checkout credentials, read-only permissions and exactly three upload paths are inspected. Source checking runs from trusted main code before source selection; the selected commit and clean tree are checked again after building. Existing required workflows and merge rules are unchanged. Proposed 12-file privacy and whitespace checks pass with zero findings; all 456 changed-document local links/anchors pass.
- 2026-10-19: the app-only note-content regression fails on procedural signing text, then all nine release-review tests pass. The regenerated draft contains all eleven app-change entries and excludes website, development-only and release-process content. Version/platform/source metadata is retained; app ZIP and checksum bytes are unchanged.

## Hosted execution and download verification

- 2026-10-19: implementation is merged in [PR #47](https://github.com/bcinarli/pane-peek/pull/47). Both main [build/test](https://github.com/bcinarli/pane-peek/actions/runs/39211080536) and [privacy](https://github.com/bcinarli/pane-peek/actions/runs/39211080558) runs pass on merged source `9be70422226bfea7461087d5ccf2dfe4e5712fd4`. The manually dispatched [preparation run](https://github.com/bcinarli/pane-peek/actions/runs/39211255193) passes source eligibility, release tests, bundling, archive checks, draft notes and upload using that exact source.
- 2026-10-19: the downloaded [review artifact](https://github.com/bcinarli/pane-peek/actions/runs/39211255193/artifacts/12167133636) matches GitHub's SHA-256 digest and contains exactly the app ZIP, adjacent checksum and draft notes. The app ZIP checksum passes; extraction preserves all ten file contents/modes, the arm64 executable, compiled assets and all notices. App metadata is 0.1.0 (4), minimum macOS 26.0. Notes identify the exact merged source and retain all eleven app-change entries without website or release-process text.
- 2026-10-19: an isolated copy of the downloaded app launches with separate preferences and disposable documents; its executable matches the downloaded archive and its running process is confirmed. This API artifact download does not exercise browser quarantine or Gatekeeper acceptance. Individual About/preview/accessibility interactions remain unreported.

## Review

Inspect the ZIP, adjacent checksum and draft notes from the documented local preparation path. Open the extracted app with disposable documents; check About shows 0.1.0 (4) and the sample Markdown previews. Overall acceptance and hosted validation are recorded in the task tracker.

Tighten reuses the existing bundler and metadata validator with one focused release-review helper. Probe covers source/CI rejection, trusted source selection, post-build source preservation, invalid package rejection and archive round trip.

## Limits

Hosted dispatch and authenticated artifact download pass for the linked run. The repository is private, so public release access needs a separately selected destination or visibility change. Signing/notarisation, tags, GitHub Release creation and public distribution remain separate gates. App sources are unchanged; app-wide accessibility remains under T18.
