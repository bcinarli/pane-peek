---
task: developer-id-signing
verdict: Passed
closed: "2026-10-19"
---

# Developer ID signing and Hardened Runtime

The [plan](../plan.md#developer-id-signing-and-hardened-runtime) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns review and publication state.

## Executed checks

- 2026-10-19: signing fingerprint and unavailable-identity regressions fail on the existing CLI's missing signing support, then all eleven affected signing/numbering tests pass. Invalid inputs preserve metadata and produce no build or release assets.

- 2026-10-19, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: all 62 tooling tests pass. The full release suite with the bundler's Xcode selection passes all 577 tests (112 app, 465 core), with ten expected known issues and three existing test-only unused-expression warnings.
- 2026-10-19: actual Developer ID signing passes with an Apple-chain requirement pinned to the selected certificate, strict/deep resource verification, `runtime` flag, secure timestamp and no entitlements. The ZIP checksum passes; extraction preserves all eleven bundle file contents/modes, arm64 executable, 0.1.0 (4), minimum macOS 26.0, compiled assets and all notices.
- 2026-10-19: disposable signed copies reject the wrong certificate fingerprint, modified NOTICE, missing runtime, missing secure timestamp and unexpected debugger/library-validation entitlements. Each failure is observed through the production verifier. Signing and verification occur before archive creation and workflow-output publication.
- 2026-10-19: default development and unsigned release builds pass. Unsigned release packaging retains all five workflow outputs and a matching checksum, leaves the development executable unchanged and preserves byte-identical version metadata.
- 2026-10-19: a separate review copy is signed with the same Developer ID/runtime policy after assigning an isolated preferences domain. It launches with disposable Markdown/text folders; the running process is confirmed. The original extracted package remains unchanged and verifies independently. Individual native/About/preview/edit/Quick Look/accessibility outcomes remain unreported.

## Manual review

Use the isolated signed review app with disposable documents to check About version/build, browse, preview, edit/save a sample text file and exercise Quick Look. The task tracker owns overall review acceptance. Individual keyboard/VoiceOver and other native accessibility outcomes remain unreported; app-wide validation remains T18.

## Review passes

Tighten keeps the existing bundler/archive path and one focused signing helper, without an entitlement file or new metadata source. Probe exercises certificate pinning, sealed-resource tampering, runtime/timestamp removal and unsafe entitlements against real signed copies, then checks development/unsigned compatibility and archive round trip.

## Limits

Notarisation/stapling, hosted credential setup, real browser quarantine/Gatekeeper acceptance and publication are outside this unit. No app UI behaviour is changed by the signing implementation.
