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
| `tests/tooling/` | Privacy checker and hook regressions. |
| `scripts/` | Build, test, asset and privacy tools. |
| [`assets/`](assets/README.md) | Development app icon, UI icons, colours and third-party notices. |
| [`agent-paper-trail/`](agent-paper-trail/README.md) | Requirements, decisions, task state and validation evidence. |

Use lowercase source/test directories with explicit package paths. Swift module names retain normal capitalisation; app bundles require `Contents`, `MacOS` and `Resources`. Normal builds use checked-in icons. To regenerate the development app icon from its accepted SVG geometry, run `node scripts/export-app-icon.mjs`; it uses built-in macOS tools and writes intermediate files to `.build/app-icon/`.

## Pull requests

Start with an issue and agree the scope with the maintainer before preparing a pull request. Once the change is agreed, work on a feature branch and open a focused PR targeting `main`. Explain the problem and resulting behaviour. Record the checks you ran and include screenshots for visible changes. Add a short user-facing entry under [Unreleased](CHANGELOG.md#unreleased) when behaviour changes.

Read [AGENTS.md](AGENTS.md) and the [paper trail](agent-paper-trail/README.md) before agent-assisted implementation. Keep task and validation records current. Each unit needs a review, with simplification followed by a correctness check. Private journals and raw conversations stay outside the repository. Commit, push, merge and release publication retain separate approval gates.

## Licence and attribution

Contributions use [Apache-2.0](LICENSE). Preserve the project-origin attribution in [NOTICE](NOTICE) and applicable copyright and third-party notices, including [Lucide/Feather](assets/lucide-LICENSE.txt). When sharing modified files, include prominent notices stating that they were changed. See sections 4–5 of LICENSE for redistribution and contribution terms.

## Versioning and release checklist

[`version.json`](version.json) is the single source for release version and build number. Use three dot-separated integers for the version and a positive safe integer for the build. Increment the build number when sharing a new build; ordinary rebuilds reuse it. Change the release version for a new release. The bundler validates both before invoking build tools and writes them into `Info.plist` with copyright metadata.

Release preparation is manual. CI provides development artifacts. A release also needs signing and notarisation, with packaging and installation checks.

To build an optimised Apple Silicon package locally:

```sh
node scripts/build-app.mjs --release
```

The command explicitly builds arm64 code with Swift's release configuration. It keeps the development bundle at `.build/PanePeek.app` unchanged and writes each package into a fresh directory under `.build/packages/`. The printed directory contains `PanePeek.app`, a `PanePeek-VERSION-buildBUILD-macos-arm64.zip` archive and its `.zip.sha256` checksum. Version, build and minimum macOS version use the same maintained sources as the development build. Rebuilding does not increment them.

In that package directory, run `shasum -a 256 -c *.zip.sha256` to verify the archive. Extract it into an empty directory with Archive Utility or `ditto -x -k`, then check the extracted app's version, notices and launch. The archive preserves the executable's permissions and the complete app bundle. These are local packages; Developer ID signing, notarisation and installation through a real browser download remain separate release steps. Complete signing before creating the final archive and checksum.

1. Choose the release version and increment the build in `version.json`. For an approved release, move the agreed Unreleased notes under a version heading with the publication date. Leave a fresh Unreleased section. Keep the entry under Unreleased until publication is agreed.
2. Review and merge the release preparation through a PR with both required checks green. Build and test the exact reviewed commit intended for the release; inspect its complete tree and outgoing history with the privacy tooling.
3. Compare the packaged `CFBundleShortVersionString` and `CFBundleVersion` with `version.json`. Check copyright, executable, icons and deployment target in the actual bundle. Review the app's version display and affected workflows on disposable documents.
4. Before distributing an app, verify that its resources include readable LICENSE, NOTICE and PRIVACY.md alongside the existing Lucide/Feather notices. Keep third-party terms intact. Continue release preparation once all required files are present.
5. Complete the intended distribution signing, notarisation and installation checks under a separately reviewed distribution plan.
6. With explicit maintainer approval, create a matching `vX.Y.Z` tag at that reviewed commit and publish the GitHub Release using the corresponding changelog entry. Attach only the reviewed package and verify its download, version and notices. Tagging and publication are manual actions.
