# PanePeek notes

Add durable implementation gotchas here when evidence emerges.

Source, test and asset directories use lowercase names with explicit package paths, following Bilal's T02 Unit 1 instruction. Swift module/type names and platform-required bundle directories retain their standard case.

Directory-link navigation uses the canonical target and its ancestry, following the [Finder-style decision](../decisions/0005-finder-directory-symlink-navigation.md). The off-thread read returns that directory together with its entries; only the latest successful request updates the pane. Foundation can normalise enumerated child URLs differently from the directory URL, so rebase children on the returned canonical directory. A link in its parent listing retains its own identity.

The [test runner](../../scripts/test.mjs) adds the installed Testing macro search directory when present; some Command Line Tools builders omit it. The UI's private `ViewState` alias selects SwiftUI's existing property wrapper on SDKs that also declare a `State` macro. These choices allow the current package to build/test without requiring a full Xcode installation.

The Swift package executable acquires its development icon from the local app bundle: `CFBundleIconFile` names `Contents/Resources/PanePeek.icns`. Normal builds copy the checked-in asset; icon regeneration is a separate step using the accepted SVG composition and built-in macOS tools. Quit and rebuild/relaunch after regenerating. [Build/run instructions](../../README.md#build-and-run) and [T01 evidence](../validation/t01-launchable-shell.md#unit-2-static-alignment-and-development-icon) describe the process and native checks. A resolved file icon does not prove every cached Dock/app-switcher presentation has refreshed.

The [spec](../specs/001-mvp/spec.md) already documents filesystem, external-writer and Finder limitations; reference those instead of duplicating them.

Keep environment setup observations and private session details outside the repository. Record only facts that change how future project work should proceed.

## Details width follow-up

Proposed on 2026-10-04 after Bilal confirmed the T01 manual checklist: allow Details to expand further by dragging its divider. [The current sidebar](../../sources/panepeek/BrowserWindow.swift) has a 400-point maximum. Consider relaxing this limit in a separately approved unit while keeping both directory panes usable and the balanced default required by the [accepted UI design](../specs/001-mvp/spec.md#accepted-ui-design). No width change has been implemented.
