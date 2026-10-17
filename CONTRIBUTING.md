# Contributing to PanePeek

PanePeek is a native macOS app for browsing and previewing documents, editing text inline and copying paths to share with AI agents. Keep changes focused on this local workflow.

Use [GitHub Issues](https://github.com/bcinarli/pane-peek/issues) for bugs and proposed changes. Include reproduction steps, the app version/build and macOS version. Use disposable sample files and remove private paths, document contents and credentials from reports and screenshots.

## Requirements

- macOS 26 or later.
- Swift 6.2 or later with a macOS SDK supporting the deployment target. Full Xcode with its licence accepted is required for app bundling; Command Line Tools can build the Swift package and run behaviour tests.
- Node.js 24 or later for the repository's development and privacy tooling, plus Git. No npm install is needed.
- The pinned Gitleaks version for privacy checks. Follow the [scanner setup and checksum instructions](scripts/README.md); set `GITLEAKS_BIN` if it is outside `PATH`.

The app has no runtime third-party package dependencies. UI icons are bundled locally; optional editor fonts are not bundled.

## Build and run

From the repository root, quit the running app before rebuilding:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

The script builds the debug executable and packages it with the development icon, UI icons and light/dark accent colours. About reads the packaged metadata; its Privacy and Acknowledgements links open derived local text copies in the default text app. The original LICENSE, NOTICE, PRIVACY.md and icon notices are also included unchanged. `Package.swift` owns the minimum macOS version. Generated output under `.build/` is ignored by Git.

The bundler uses one Xcode environment for Swift compilation, package inspection and asset compilation. It honours `DEVELOPER_DIR` or the selected Xcode installation. With Command Line Tools selected and no override, it uses `/Applications/Xcode.app/Contents/Developer`. Set `DEVELOPER_DIR` for another Xcode location; the script does not change global selection.

The local bundle runs outside the App Sandbox and is not distribution-signed or notarised. If a rebuilt executable is rejected because of a cached signature, follow the [generated-executable recovery](agent-paper-trail/notes/0001-build-and-bundle.md#rebuilt-executable-recovery).

## Tests

Use a consistent Xcode selection or `DEVELOPER_DIR` when comparing build and test results. The bundler's fallback does not change your shell's selection.

```sh
node scripts/test.mjs
```

The runner invokes `swift test`, adding the installed Testing macro search directory when available. Tests use disposable directories, isolated preference suites and generated media fixtures. They do not mutate working documents or the app's real preferences. Extra arguments are forwarded to Swift, for example:

```sh
node scripts/test.mjs --filter PathCopyTests
```

For privacy tooling changes, also run:

```sh
node --test tests/tooling/*.test.mjs
```

Use meaningful red/green tests for new automated behaviour. Packaging and layout need real build or native checks. For visible changes, include light/dark, keyboard and applicable VoiceOver checks; use disposable files for mutation tests. Automated success does not replace manual review.

## Privacy checks and local hooks

After staging a change, check the actual staged content before committing:

```sh
node scripts/check-privacy.mjs --staged
```

For a committed tree, use `node scripts/check-privacy.mjs --tree HEAD`. The [tooling guide](scripts/README.md) covers introduced-history scans, exit codes and scanner limits. Review screenshots, binary files and private prose separately; a passing scan does not cover all personal data.

Optional hooks run these checks before commit and push:

```sh
node scripts/privacy-hooks.mjs install
```

Read the [hook setup and removal rules](scripts/README.md#optional-local-hooks) first. Hooks are shared by linked worktrees using the default hooks directory. Setup refuses existing hooks or a configured hook manager; integrate through that manager using the documented commands instead of replacing it.

## Continuous integration

PRs targeting `main`, pushes to `main` and manual workflow requests run two required checks:

- [`macOS build and test`](.github/workflows/ci.yml) runs the full app tests and bundles the development app on macOS 26 Apple Silicon. The workflow owns its Xcode and Node.js versions.
- [`Privacy and secrets`](.github/workflows/privacy.yml) runs tooling regressions and checks the final tree and introduced commits with the pinned offline scanner.

Both checks must pass, the PR must be up to date and review conversations must be resolved before merge. See the [accepted merge policy](agent-paper-trail/decisions/2026-10-17-ci-and-merge-checks.md) and [privacy enforcement evidence](agent-paper-trail/specs/001-mvp/evidence/privacy-secrets-checker.md#hosted-ci-and-merge-enforcement-2026-10-17).

Successful build runs retain a `PanePeek-macos-arm64` development artifact for seven days. Download it from the run's **Artifacts** section, extract the outer archive, then the app zip. The inner archive preserves executable permissions. This is a development build, not a signed or notarised release.

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

Discuss substantial behaviour changes in an issue first. Work on a feature branch and open a focused PR targeting `main`. Explain the problem and resulting behaviour, record checks actually run and include screenshots for visible changes. Add a concise user-facing entry under [Unreleased](CHANGELOG.md#unreleased) when behaviour changes.

Read [AGENTS.md](AGENTS.md) and the [paper trail](agent-paper-trail/README.md) before agent-assisted implementation. Keep the task and validation records current, preserve unit review gates and apply simplification followed by correctness review. Private journals and raw conversations stay outside the repository. Commit, push, merge and release publication retain separate approval gates.

## Licence and attribution

Contributions use [Apache-2.0](LICENSE). Preserve the project-origin attribution in [NOTICE](NOTICE) and applicable copyright and third-party notices, including [Lucide/Feather](assets/lucide-LICENSE.txt). When redistributing modified files, include prominent notices stating that they were changed. See sections 4–5 of LICENSE for redistribution and contribution terms.

## Versioning and release checklist

[`version.json`](version.json) is the single source for release version and build number. Use three dot-separated integers for the version and a positive safe integer for the build. Increment the build number before deliberately sharing a new build; ordinary rebuilds reuse it. Change the release version for a new release. The bundler validates both before invoking build tools and writes them into `Info.plist` with copyright metadata.

Release preparation is manual. Current CI produces development artifacts; signing, notarisation and complete release packaging remain separate work.

1. Choose the release version and increment the build in `version.json`. For an approved release, curate Unreleased into a version heading using the publication date and leave a fresh Unreleased section. If publication is deferred, keep the entry under Unreleased; do not invent past releases.
2. Review and merge the release preparation through a PR with both required checks green. Build and test the exact reviewed commit intended for the release; inspect its complete tree and outgoing history with the privacy tooling.
3. Compare the packaged `CFBundleShortVersionString` and `CFBundleVersion` with `version.json`. Check copyright, executable, icons and deployment target in the actual bundle. Review the app's version display and affected workflows on disposable documents.
4. Before distributing an app, verify that its resources include readable LICENSE, NOTICE and PRIVACY.md alongside the existing Lucide/Feather notices. Keep third-party terms intact. Stop release preparation if required files are missing.
5. Complete the intended distribution signing, notarisation and installation checks under a separately reviewed distribution plan. The development bundler does not perform these steps.
6. With explicit maintainer approval, create a matching `vX.Y.Z` tag at that reviewed commit and publish the GitHub Release using the corresponding changelog entry. Attach only the reviewed package and verify its download, version and notices. Tagging and publication are not performed by the build script or current workflows.
