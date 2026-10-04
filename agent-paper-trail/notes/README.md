# PanePeek notes

Add durable implementation gotchas here when evidence emerges.

The Swift package executable acquires its development icon from the local app bundle: `CFBundleIconFile` names `Contents/Resources/PanePeek.icns`. Normal builds copy the checked-in asset; icon regeneration is a separate step using the accepted SVG composition and built-in macOS tools. Quit and rebuild/relaunch after regenerating. [Build/run instructions](../../README.md#build-and-run) and [T01 evidence](../validation/t01-launchable-shell.md#unit-2-static-alignment-and-development-icon) describe the process and native checks. A resolved file icon does not prove every cached Dock/app-switcher presentation has refreshed.

The [spec](../specs/001-mvp/spec.md) already documents filesystem, external-writer and Finder limitations; reference those instead of duplicating them.

Keep environment setup observations and private session details outside the repository. Record only facts that change how future project work should proceed.

## Details width follow-up

Proposed on 2026-10-04 after Bilal confirmed the T01 manual checklist: allow Details to expand further by dragging its divider. [The current sidebar](../../Sources/PanePeek/BrowserWindow.swift) has a 400-point maximum. Consider relaxing this limit in a separately approved unit while keeping both directory panes usable and the balanced default required by the [accepted UI design](../specs/001-mvp/spec.md#accepted-ui-design). No width change has been implemented.
