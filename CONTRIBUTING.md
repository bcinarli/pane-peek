# Contributing to PanePeek

The preferred way to contribute is to open a [GitHub issue](https://github.com/bcinarli/pane-peek/issues/new). Describe the problem and how to reproduce it. An issue gives the maintainer a concrete case to investigate before work starts on a pull request.

Include:

- The steps that trigger the problem, using sample files where possible.
- What you expected and what happened.
- The PanePeek version/build from About PanePeek, plus your macOS version.
- A screenshot or small sample file when it helps explain the problem.

You can ask your AI assistant to turn your observations into an issue draft and help explain the details. Check that the draft describes what you saw and that its reproduction steps work. Share only details and screenshots you intend to make public.

For a suggested change, describe what you are trying to do and how PanePeek could help. The [usage guide](docs/usage.md) covers the current app. The development instructions below support investigating an issue or working on an agreed change.

## Requirements

- macOS 26 or later.
- Swift 6.2 or later with a macOS SDK supporting the deployment target. Full Xcode with its licence accepted is required for app bundling; Command Line Tools can build the Swift package and run behaviour tests.
- Node.js 24 or later for the repository's development and privacy tooling, plus Git. The tools use Node.js built-in modules.
- The pinned Gitleaks version for privacy checks. Follow the [scanner setup and checksum instructions](scripts/README.md); set `GITLEAKS_BIN` if it is outside `PATH`.

The app uses Apple frameworks and bundles its UI icons. The editor uses supported optional fonts installed on the Mac.

## Build and run

From the repository root, quit the running app before rebuilding:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

The script builds a debug app with its icons and light/dark colours. About reads the packaged version and build number. Its Privacy and Acknowledgements links open local text copies in the default text app. The bundle also includes the original LICENSE, NOTICE, PRIVACY.md and icon notices. `Package.swift` owns the minimum macOS version. Generated output under `.build/` is ignored by Git.

The bundler uses the same Xcode installation throughout the build. It uses `DEVELOPER_DIR` when set, otherwise the selected Xcode installation. When Command Line Tools are selected, the default is `/Applications/Xcode.app/Contents/Developer`. Set `DEVELOPER_DIR` to use another Xcode location for that build.

The local bundle is a development app that runs outside the App Sandbox. Distribution signing and notarisation are separate release steps. If a rebuilt executable is rejected because of a cached signature, follow the [generated-executable recovery](agent-paper-trail/notes/0001-build-and-bundle.md#rebuilt-executable-recovery).

## Tests

Use a consistent Xcode selection or `DEVELOPER_DIR` when comparing build and test results. The bundler's fallback applies to the build process, so set the shell's selection separately for tests.

```sh
node scripts/test.mjs
```

The runner runs `swift test`, adding the installed Testing macro search directory when available. Tests use disposable files and separate settings. Media fixtures are generated for the test run. Extra arguments are forwarded to Swift, for example:

```sh
node scripts/test.mjs --filter PathCopyTests
```

For privacy tooling changes, also run:

```sh
node --test tests/tooling/*.test.mjs
```

For new automated behaviour, write a test and observe it fail before making it pass. Check packaging with a real build and review layout in the running app. Include light/dark appearance and keyboard checks for visible changes, along with applicable VoiceOver checks. Use disposable files for file-operation tests. Present automated results alongside manual review.

## Privacy checks and local hooks

After staging a change, check the actual staged content before committing:

```sh
node scripts/check-privacy.mjs --staged
```

For a committed tree, use `node scripts/check-privacy.mjs --tree HEAD`. The [tooling guide](scripts/README.md) covers scans of new commits, exit codes and scanner limits. Review screenshots and other binary files separately. Read prose for personal details the scanner can miss.

Optional hooks run these checks before commit and push:

```sh
node scripts/privacy-hooks.mjs install
```

Read the [hook setup and removal rules](scripts/README.md#optional-local-hooks) first. Hooks are shared by linked worktrees using the default hooks directory. If hooks or a hook manager already exist, integrate the documented commands through the existing setup.

## Continuous integration

PRs targeting `main`, pushes to `main` and manual workflow requests run two required checks:

- [`macOS build and test`](.github/workflows/ci.yml) runs the full app tests and bundles the development app on macOS 26 Apple Silicon. The workflow owns its Xcode and Node.js versions.
- [`Privacy and secrets`](.github/workflows/privacy.yml) runs tooling regressions and checks the final tree and introduced commits with the pinned offline scanner.

Both checks must pass, the PR must be up to date and review conversations must be resolved before merge. See the [accepted merge policy](agent-paper-trail/decisions/2026-10-17-ci-and-merge-checks.md) and [privacy enforcement evidence](agent-paper-trail/specs/001-mvp/evidence/privacy-secrets-checker.md#hosted-ci-and-merge-enforcement-2026-10-17).

Successful build runs retain a `PanePeek-macos-arm64` development artifact for seven days. Download it from the run's **Artifacts** section, extract the outer archive, then the app zip. The inner archive preserves executable permissions. The artifact is a development build. Distribution signing and notarisation follow the release process below.

## Project layout

| Location | Purpose |
| --- | --- |
| `Package.swift` | Deployment target and explicit Swift target paths. |
| `sources/panepeek/` | SwiftUI/AppKit app, windows, previews, editor and native controls. |
| `sources/panepeek-core/` | Browsing state, filesystem operations and document behaviour. |
| `tests/panepeek/`, `tests/panepeek-core/` | App and core behaviour tests. |
| `tests/tooling/` | Privacy, hooks and release-tooling regressions. |
| `scripts/` | Build, release, test, asset and privacy tools. |
| [`assets/`](assets/README.md) | Development app icon, UI icons, colours and third-party notices. |
| [`agent-paper-trail/`](agent-paper-trail/README.md) | Requirements, decisions, task state and validation evidence. |

Use lowercase source/test directories with explicit package paths. Swift module names retain normal capitalisation; app bundles require `Contents`, `MacOS` and `Resources`. Normal builds use checked-in icons. To regenerate the development app icon from its accepted SVG geometry, run `node scripts/export-app-icon.mjs`; it uses built-in macOS tools and writes intermediate files to `.build/app-icon/`.

## Pull requests

Start with an issue and agree the scope with the maintainer before preparing a pull request. Once the change is agreed, work on a feature branch and open a focused PR targeting `main`. Explain the problem and resulting behaviour. Record the checks you ran and include screenshots for visible changes. Add a short user-facing entry under [Unreleased](CHANGELOG.md#unreleased) when behaviour changes.

Read [AGENTS.md](AGENTS.md) and the [paper trail](agent-paper-trail/README.md) before agent-assisted implementation. Keep task and validation records current. Each unit needs a review, with simplification followed by a correctness check. Private journals and raw conversations stay outside the repository. Commit, push, merge and release publication retain separate approval gates.

## Licence and attribution

Contributions use [Apache-2.0](LICENSE). Preserve the project-origin attribution in [NOTICE](NOTICE) and applicable copyright and third-party notices, including [Lucide/Feather](assets/lucide-LICENSE.txt). When sharing modified files, include prominent notices stating that they were changed. See sections 4–5 of LICENSE for redistribution and contribution terms.

## Versioning and release checklist

[`version.json`](version.json) is the single source for release version and build number. Use three dot-separated integers for the version and a positive safe integer for the build. Prepare a new build number before sharing a new candidate; ordinary rebuilds reuse it. Select the release version explicitly for a new release. The bundler validates both before invoking build tools and writes them into `Info.plist` with copyright metadata.

Reserve the next build number for a new distributable candidate:

```sh
node scripts/prepare-release.mjs
```

To select a new release version at the same time, use `node scripts/prepare-release.mjs --version 1.0.0`. Version selection is explicit; the build counter continues increasing across version changes. Each preparation changes `version.json` once. Rebuilding the same candidate reuses its assigned number. A reserved number stays consumed if a later build or signing step fails.

Preparation validates metadata and replaces it atomically, preserving its file permissions. A lock excludes simultaneous preparations against the same metadata file. If `version.json.lock` remains after an interrupted preparation, confirm that no preparation is active before removing that lock and retrying. Independent clones/worktrees still require release coordination before sharing builds. Review the metadata change with the release candidate.

CI provides development artifacts. Signing and notarisation, installation checks and publication remain separate release steps.

To build an optimised Apple Silicon package locally:

```sh
node scripts/build-app.mjs --release
```

The command explicitly builds arm64 code with Swift's release configuration. It keeps the development bundle at `.build/PanePeek.app` unchanged and writes each package into a fresh directory under `.build/packages/`. The printed directory contains `PanePeek.app`, version/build-labelled `.dmg` and `.zip` downloads and a `.sha256` checksum for each. Version, build and minimum macOS version use the same maintained sources as the development build. Rebuilding does not increment them.

In that package directory, run `shasum -a 256 -c *.sha256` to verify the archive. Extract it into an empty directory with Archive Utility or `ditto -x -k`, then check the extracted app's version, notices and launch. The archive preserves the executable's permissions and the complete app bundle. These are local packages; Developer ID signing, notarisation and installation through a real browser download remain separate release steps. Complete signing before creating the final archive and checksum.

### DMG installation package

The DMG is a compressed read-only UDZO volume with the native app on the left and an Applications shortcut on the right. Drag the app to Applications, eject the volume and open the installed copy. ZIP remains an alternative for extracting the same app.

The editable [background](assets/dmg/background.svg) uses Macchiato Base/Mantle and Mauve. The build renders standard and Retina TIFF representations and writes Finder icon positions and a native background bookmark without GUI automation. Finder owns window chrome, filename labels and keyboard/accessibility behaviour. Hidden layout files remain accessible when Finder's Show Hidden Files preference is enabled; the installer does not change system preferences.

Packaging mounts and detaches only its own image, checks the read-only format, expected contents, unchanged app, executable permissions, exact Applications link and artwork/layout before publishing output paths. Signed mode checks both signatures; notarised mode validates both stapled tickets and Gatekeeper assessments. The final DMG checksum is calculated after stapling. Keep a package directory immutable when resuming it.

For a signed/stapled app already in a review directory, package just the outer disk image:

```sh
node scripts/release-dmg.mjs PACKAGE_DIRECTORY --sign IDENTITY_SHA1 --notarize NOTARY_PROFILE
```

This preserves the existing app signature and uses the DMG's own saved submission. It requires matching current version/build metadata. It does not generate release notes or run the source/CI gate. Test the actual Finder presentation and copied app before acceptance. Browser quarantine and hosted execution require their own observed checks.

### Developer ID signing and Hardened Runtime

For a signed local release, install a valid Developer ID Application certificate with its matching private key. Use `security find-identity -v -p codesigning` to find its 40-character SHA-1 fingerprint, then run:

```sh
node scripts/build-app.mjs --release --sign IDENTITY_SHA1
```

The signing option requires release mode and an exact identity fingerprint. It refuses missing, invalid and other certificate types before building. After assembling the complete app, it signs with Hardened Runtime and Apple's secure timestamp service, then checks the resource seal, selected certificate, runtime flag and timestamp before packaging. The disk image receives its own Developer ID signature and secure timestamp. Signing needs network access for the timestamp and may prompt for Keychain access. Signing or verification failure produces no archive or successful workflow outputs for that attempt.

The current app needs no signing entitlements or Hardened Runtime exceptions. Verification rejects unexpected entitlements, including debugger access and disabled library validation. Development builds and `--release` without `--sign` retain their existing behaviour; the manual hosted workflow uses the protected [hosted signing setup](#hosted-signing-and-notarisation).

After extracting a signed ZIP, check the signature with `codesign --verify --deep --strict PanePeek.app`. The certificate is visible with `codesign --display --verbose=4 PanePeek.app`; confirm the intended Developer ID authority, `runtime` flag and secure timestamp. The complete app, including its resources, must be final before signing. Any later bundle modification requires signing and packaging again.

Follow [Apple's distribution-signing guidance](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/). Notarisation/stapling, hosted credential setup, browser/Gatekeeper acceptance and publication remain separate steps. Keep private keys, exported signing identities and passwords out of the repository.

### Notarisation and stapling

Create an app-specific password and store it with `xcrun notarytool store-credentials NOTARY_PROFILE --apple-id APPLE_ACCOUNT_EMAIL --team-id TEAM_ID`, entering the generated password only at the secure prompt. Credentials stay in Keychain. Prepare the intended version/build, then run:

```sh
node scripts/build-app.mjs --release --sign IDENTITY_SHA1 --notarize NOTARY_PROFILE
```

The command submits a temporary ZIP of the verified signed app to Apple's notary service. It waits up to twenty minutes and checks the final status and log, including the upload hash and app's arm64 ticket. Only an Accepted result with no reported issues proceeds to stapling, ticket validation and signature/code-hash verification. The stapled app is then placed in a signed read-only DMG, submitted separately and checked against its own matching container ticket. Each submission can wait up to twenty minutes. Final DMG/ZIP checksums and workflow outputs are exposed after both ticket and package checks succeed. The manual hosted workflow uses the protected [hosted signing setup](#hosted-signing-and-notarisation).

The package's `notarisation/` and `dmg-notarisation/` folders retain their respective upload, submission receipt and raw log under ignored build output. Keep these operational files out of releases and Git. If processing remains pending, or a later step fails, use the printed package directory to resume the same candidate:

```sh
node scripts/release-notarisation.mjs PACKAGE_DIRECTORY --sign IDENTITY_SHA1 --notarize NOTARY_PROFILE
```

Resume checks the saved certificate/code and upload hashes before contacting Apple, then completes stapling and final packaging. It requires the app's version/build to match the current `version.json`. It does not allocate another build or upload a receipted app or DMG again. A changed candidate requires a fresh build and submission. If an upload exists without a valid receipt, check `notarytool history` before another upload. After an interrupted process, confirm no job is running before removing the corresponding `notarisation/job.lock` or `dmg-notarisation/job.lock` file. The lock covers stapling and final packaging.

Extract the final ZIP and run `xcrun stapler validate PanePeek.app` and `codesign --verify --deep --strict PanePeek.app`. Confirm the checksum, metadata, resources and normal app operation. Follow [Apple's custom notarisation workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). Notarisation is separate from App Store review and release publication; real browser-download/Gatekeeper testing remains a further acceptance step.

### Hosted signing and notarisation

The manual preparation workflow uses the `github-release` environment. Restrict its deployment branch policy to the branch named `main`, with no tag or other branch entries. Keep these values in **Environment secrets**, outside source files, repository records, workflow inputs and chat:

| Secret | Value |
| --- | --- |
| `RELEASE_CERTIFICATE_BASE64` | Single-line Base64 of a password-protected PKCS12 (`.p12`) Developer ID Application identity export, including its matching private key. |
| `RELEASE_CERTIFICATE_PASSWORD` | Password protecting that export. |
| `RELEASE_SIGNING_IDENTITY` | The certificate's exact 40-character SHA-1 fingerprint. |
| `RELEASE_APPLE_ID` | Developer Apple account email. |
| `RELEASE_TEAM_ID` | Developer membership Team ID. |
| `RELEASE_NOTARY_PASSWORD` | A dedicated Apple app-specific password for notarisation. |

In Keychain Access, select the Developer ID Application identity under **login → My Certificates**, with its matching private key shown beneath it. Export the identity as a password-protected `.p12` file outside the repository. Encode it locally and copy directly to the clipboard, replacing the example path:

```sh
base64 -i "/path/to/your-export.p12" | tr -d '\r\n' | pbcopy
```

Paste this value into `RELEASE_CERTIFICATE_BASE64` in the environment's settings. Add the export password separately. Find the signing fingerprint with `security find-identity -v -p codesigning`; obtain the Team ID from membership details and generate the app-specific password through the Apple account. Enter values directly in GitHub. Keep local exports protected and remove temporary copies/clipboard contents after setup. Follow [GitHub's certificate setup guidance](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications) and [environment protection instructions](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

After exact-source/CI verification and release tests, the job imports the identity into an owned temporary Keychain, validates its fingerprint/type/private key and stores the notary profile there. Notary operations explicitly use that Keychain. Raw secret environment values are removed before the existing bundler runs. Raw credential-tool output is suppressed; a failing stage is reported without command arguments or secret values.

Normal success/failure cleanup removes the temporary Keychain and credential files before exposing package outputs. Deleting that Keychain removes only its search-list entry; existing entries and the default Keychain are preserved. An always-run cleanup step retries after interruption, and the workflow requires disposable GitHub-hosted Macs. Cleanup refuses directories without its ownership marker. A cleanup failure blocks review-asset upload. Credentials and raw notarisation records are excluded from artifacts and Git.

The workflow validates the extracted app's signature, stapled ticket and local Gatekeeper assessment before uploading the DMG, ZIP, their checksums and app notes. After merging the workflow, run the reviewed main commit and inspect its downloaded artifact before claiming hosted success. Local mocked checks and a configured environment alone do not establish that result. Submission receipts/logs stay in ignored runner build output and are not retained as release assets. Apple may keep processing after a timeout or runner shutdown; check notary service history before another upload. A new hosted run does not restore a prior runner's submission state. Real browser quarantine installation and public release remain separate steps. The local unsigned and signed-only build commands stay available.

### GitHub preparation artifacts

After the workflow is merged, open **Actions → Prepare GitHub release → Run workflow**. Select the `main` branch and supply the full 40-character SHA of the intended source commit. That commit must be on `main`, contain the preparation tooling and have successful latest main push runs for both existing CI workflows. Prepare and merge version/build changes beforehand; this workflow reuses them.

The source gate runs from the trusted `main` workflow checkout before selecting the requested commit. The workflow then runs the release test suite, builds the optimised arm64 package and checks its extraction and executable permissions. Its seven-day review artifact contains exactly the DMG, app ZIP, their SHA-256 checksums and `release-notes.md`. Notes identify the source commit and platform and describe app changes from the matching changelog entry, or explicitly label Unreleased content as draft. Release-process instructions belong in this guide. The workflow creates no tag or GitHub Release and uses read-only repository permissions. Signing secrets are confined to its protected release job.

Download the review artifact from the completed run, extract its outer ZIP and verify both downloads with their adjacent checksums. Review the notes, then extract and launch the app on disposable documents. These preparation packages pass hosted signing/notarisation checks; a successful run still requires downloaded-app review and real browser installation acceptance. Repository read access is required to obtain workflow artifacts. Confirm the public download destination separately before publishing a release.

For local package review, run `node scripts/release-review.mjs notes PACKAGE_DIRECTORY` on the fresh directory printed by the release bundler. It verifies the app's version/build and both download checksums before creating notes; an existing notes file is preserved. This notes command alone does not perform the workflow's source/CI eligibility check.

### Release publication checklist

1. Choose the release version and reserve the next build with `node scripts/prepare-release.mjs`, adding `--version X.Y.Z` when changing the version. For an approved release, move the agreed Unreleased notes under a version heading with the publication date. Leave a fresh Unreleased section. Keep the entry under Unreleased until publication is agreed.
2. Review and merge the release preparation through a PR with both required checks green. Build and test the exact reviewed commit intended for the release; inspect its complete tree and outgoing history with the privacy tooling.
3. Compare the packaged `CFBundleShortVersionString` and `CFBundleVersion` with `version.json`. Check copyright, executable, icons and deployment target in the actual bundle. Review the app's version display and affected workflows on disposable documents.
4. Before distributing an app, verify that its resources include readable LICENSE, NOTICE and PRIVACY.md alongside the existing Lucide/Feather notices. Keep third-party terms intact. Continue release preparation once all required files are present.
5. Complete the intended distribution signing, notarisation and installation checks under a separately reviewed distribution plan.
6. With explicit maintainer approval, create a matching `vX.Y.Z` tag at that reviewed commit and publish the GitHub Release using the corresponding changelog entry. Attach only the reviewed package and verify its download, version and notices. Tagging and publication are manual actions.
