# PanePeek notes

Add durable implementation gotchas here when evidence emerges.

Source, test and asset directories use lowercase names with explicit package paths, following Bilal's T02 Unit 1 instruction. Swift module/type names and platform-required bundle directories retain their standard case.

Directory-link navigation uses the canonical target and its ancestry, following the [Finder-style decision](../decisions/0005-finder-directory-symlink-navigation.md). The off-thread read returns that directory together with its entries; only the latest successful request updates the pane. Foundation can normalise enumerated child URLs differently from the directory URL, so rebase children on the returned canonical directory. A link in its parent listing retains its own identity.

Breadcrumb scrolling keeps short paths beside Home and reveals the current component for long paths. SwiftUI's [scroll anchor roles](https://developer.apple.com/documentation/swiftui/view/defaultscrollanchor(_:for:)) separate undersized-content alignment from initial position. The scroll view's identity follows the displayed path so a new directory starts at its current component; failed navigation preserves the existing breadcrumb and scroll position.

Give the scroll content itself a fixed height and reserve space beneath its labels for the native horizontal scroller. An outer frame alone does not prevent overlap. Matching Home/Details spacing keeps headings aligned. Native buttons follow macOS Keyboard navigation: Tab traversal requires that setting, and Space activates a focused button. See [Apple's focus guidance](https://developer.apple.com/videos/play/wwdc2023/10162/).

The [test runner](../../scripts/test.mjs) adds the installed Testing macro search directory when present; some Command Line Tools builders omit it. The UI's private `ViewState` alias selects SwiftUI's existing property wrapper on SDKs that also declare a `State` macro. These choices allow the current package to build/test without requiring a full Xcode installation.

The Swift package executable acquires its development icon from the local app bundle: `CFBundleIconFile` names `Contents/Resources/PanePeek.icns`. Normal builds copy the checked-in asset; icon regeneration is a separate step using the accepted SVG composition and built-in macOS tools. Quit and rebuild/relaunch after regenerating. [Build/run instructions](../../README.md#build-and-run) and [T01 evidence](../validation/t01-launchable-shell.md#unit-2-static-alignment-and-development-icon) describe the process and native checks. A resolved file icon does not prove every cached Dock/app-switcher presentation has refreshed.

The [spec](../specs/001-mvp/spec.md) already documents filesystem, external-writer and Finder limitations; reference those instead of duplicating them.

Keep environment setup observations and private session details outside the repository. Record only facts that change how future project work should proceed.

## Listing timestamps and links

Read each listed link's own modification date and link flag without resolving its target. Target resolution is used separately to establish whether it navigates as a directory or represents a package. Reordering must retain the listed URL identity and apply the pane's current settings after an asynchronous read completes.

Name groups folders first; Modified compares raw timestamps across all kinds. Equal timestamps use ascending natural names, then paths, even in descending date order. Keep this in the existing comparator and filter the sorted listing for visibility; [A30](../specs/001-mvp/spec.md#breadcrumbs-and-sorting) owns the accepted rule. Kind grouping remains deferred.

Sample the current wall clock when rendering relative date labels. A minute timeline's context date can precede timestamps loaded by Refresh, briefly sending just-modified items into the future-date fallback. Keep the timeline for ageing labels and preserve raw timestamps for sorting.

## Protected-folder permission requests

macOS requires consent for access to Desktop, Documents and Downloads, as described in [Apple Platform Security](https://support.apple.com/en-ph/guide/security/secddd1d86a6/web). Bilal reported these requests during T03 review. Startup lists home in both panes and checks each child's metadata/type; those checks are a likely trigger, but the exact call has not been isolated. The listing does not read child file contents or recursively enumerate folders.

Use disposable temporary fixtures for task validation and leave privacy choices to Bilal. Investigating prompt timing on a fresh launch and handling denied access is a separate follow-up; permission prompts do not establish a signature crash.

## Hidden visibility and Refresh

The core listing reads all immediate entries, including dot-prefixed and filesystem-hidden items. Each pane stores that sorted listing once and filters its exposed entries using its own visibility setting. Toggling uses the cached listing; new files or changed hidden flags appear after Refresh or navigation. No filesystem watcher is installed.

Refresh reuses navigation's latest-request/error handling and preserves sort/visibility settings. Shared actions capture the focused pane before starting asynchronous work. Native selection remains URL-based: keep a visible URL through sorting/Refresh, and clear it when the row becomes hidden or disappears. [T03 evidence](../validation/t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh) covers the native selection seam.

## Rebuilt executable recovery

In-place replacement of a previously launched executable can leave macOS rejecting the rebuilt bundle with `Taskgated Invalid Signature`. During T03 review the compiled output verified on disk, but the bundle failed to relaunch. Moving its generated executable aside and copying the build output into a fresh file restored launch without signing changes. This supports a cached-signature explanation; it does not establish that every signing failure has this cause.

Quit PanePeek first. To recover the local generated bundle while preserving its previous executable:

```sh
node --input-type=module <<'JS'
import { mkdtemp, rename } from 'node:fs/promises';
import { join } from 'node:path';
const backup = await mkdtemp('.build/executable-backup-');
await rename('.build/PanePeek.app/Contents/MacOS/PanePeek', join(backup, 'PanePeek'));
JS
node scripts/build-app.mjs
open .build/PanePeek.app
```

The bundler is unchanged. Atomic executable replacement is a bounded packaging follow-up requiring separate approval; preserve these local backups until cleanup is authorised.

## Details width follow-up

Proposed on 2026-10-04 after Bilal confirmed the T01 manual checklist: allow Details to expand further by dragging its divider. [The current sidebar](../../sources/panepeek/BrowserWindow.swift) has a 400-point maximum. Consider relaxing this limit in a separately approved unit while keeping both directory panes usable and the balanced default required by the [accepted UI design](../specs/001-mvp/spec.md#accepted-ui-design). No width change has been implemented.
