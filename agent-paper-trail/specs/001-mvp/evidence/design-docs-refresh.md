---
task: design-docs-refresh
verdict: Passed
closed: "2026-10-18"
---

# Design and documentation refresh

## Scope

Align the editable design and its reference images with the current native UI. Refresh the screenshots used by README and the usage guide; review both documents and CONTRIBUTING with the internal-doc wording preset. Contribution guidance prefers reproducible issues and encourages AI help with issue drafts, with the reporter checking the details.

## Executed checks, 2026-10-18

- The unchanged native app builds and packages from `main` at `c51d98d` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer node scripts/build-app.mjs`. The check uses macOS 27.0.1, Xcode 27.0/Swift 6.4 and Node.js 26.1.0. Light/Dark screenshot bundles use byte-identical executables and separate preferences. Native captures show the shared fictional Project/Reference documents: light Markdown preview, dark unsaved inline editing and the path-copy menu. The three public screenshots are PNG exports from native captures with retained colour profiles. Pointer/glow cleanup is confined to a small area in each image; dimensions and pixels outside those areas are unchanged. Text and controls are checked against the originals. The macOS sharing indicator remains. Visible content was inspected for personal paths and owner fields; owner/group metadata is below the captured scroll area.
- The draft uses Base `#24273A`, Mantle `#1E2030` and Crust `#181926`, with Base ink on selected Mauve Preview/Edit. Browser inspection confirms these computed colours. Visual checks cover the three starting variants and refreshed 1248×656 references, neutral layout controls, compact file rows, muted editor selection and scrolling breadcrumbs. All six PNGs have verified dimensions and contain no EXIF or descriptive text metadata. The editable source exports successfully with the bundled renderer; extracted JavaScript passes `node --check`.
- Browser interaction checks pass Favourites name/path filtering and no-match state, numeric Size ordering with folders last, one/two-browser modes, Copy, horizontal duplicate choices with editable Keep Both name, and inline rename via Return. These checks exercise the in-memory preview; native behaviour and full accessibility retain their existing evidence and verdicts.
- The existing privacy regression first rejects the new Shared breadcrumb in the actual exported draft. Exact file/value exceptions then pass all 42 tooling tests. A separate check confirms that descendant paths and unrelated files remain rejected; the scanner engine is unchanged.
- All 417 local links/anchors across the nine changed Markdown files pass, alongside fence, README build-anchor, exact source/export and whitespace checks. README, usage and CONTRIBUTING render with loaded screenshots and tables and have no horizontal overflow at the observed desktop viewport. The final shared privacy scan checks 19 proposed file versions with zero findings; all seven images receive separate visual privacy review. All 42 tooling regressions pass again against the final export. The final screenshot cleanup also passes bounded pixel-difference and colour-profile checks.
- Tighten removes repeated development wording and stale draft controls. Probe checks labels against native source, preserves Save/partial-transfer safeguards, distinguishes list folder-size placeholders from Details metadata and verifies exact privacy exceptions against rejected descendant/unrelated-file cases.

## Review and limits

Document and visual review accepted on 2026-10-18, with the requested pointer/glow cleanup applied and checked. Full native accessibility, VoiceOver and system-setting checks belong to their existing task gates. This refresh changes design tooling and documentation; the app source and version metadata are unchanged.
