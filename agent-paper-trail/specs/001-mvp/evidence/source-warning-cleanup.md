---
task: source-warning-cleanup
verdict: Passed
closed: "2026-10-17"
---

# Evidence: source-warning cleanup

- 2026-10-17: Bilal approved fixing the ten source warnings and explicitly required proper fixes without suppression. One compatibility unit covers the existing Save and Quick Look/window-lifecycle behaviour. Build-script/toolchain changes, commit, push and merge are separate.
- Environment: macOS 27.0.1 (26A434), Swift 6.4 and Node 26.1.0. The deployment minimum remains macOS 26; no macOS 26 runtime check is claimed.

## Implementation and checks

The save path decodes bounded UTF-8 bytes before the null terminator, retaining signed C-byte values. Quick Look's synchronous controller callbacks use checked main-actor entry. Window-delegate forwarding reads an immutable predecessor; only its UI state and controls require the main actor. No diagnostic suppression or unsafe isolation annotation is added.

- Baseline: the affected 29 test functions pass, including the extended optional-delegate forwarding check and Unicode save-path fixtures. This preserves existing behaviour; no intentional failing behaviour test is claimed for the warning-only edits.
- Fresh application builds with `-Xswiftc -warnings-as-errors` pass under both selected Command Line Tools and full Xcode. All ten source diagnostics are absent. Command Line Tools retains the three known linker search-path warnings; full Xcode reports none.
- An attempted warnings-as-errors test build stops on three existing unused-expression diagnostics in unrelated `ItemRenameTests`. Normal affected-suite execution passes all 29 functions. Those test-only warnings are outside the approved unit.
- Probe found a controller-lifetime regression when a native delegate changes on an already installed guard. The new compiled regression failed one expectation before stopping the previous controller before replacement. Final affected-suite execution passes all 30 functions (24 app, 6 core), including guard replacement, forwarded optional methods, controller teardown, keyboard routing, Unicode save paths, conflicts and permissions.
- The normal `node scripts/build-app.mjs` command passes with only the three known linker search-path warnings. The final full-Xcode application recheck with compiler warnings treated as errors passes without diagnostics. Review/package executable bytes match; review plist lint and `git diff --check` pass.
- Native isolated-app checks pass: Space opens saved text, Down updates the selected preview, Escape retains selection, Save clears the draft and updates metadata in a Unicode directory, and Quick Look reads the saved Unicode text. New Window releases the old panel; closing that temporary window returns to the fixture window with selection/content retained. Saved bytes match the intended UTF-8 content on disk. The isolated review app is left running; the normal preference domain is untouched.
- Standard tighten retains local actor boundaries and an immutable forwarding reference, reusing existing state, fixtures and tests. Standard probe checks bounded signed-byte decoding, synchronous callback order, delegate restoration/forwarding and controller teardown. Actual VoiceOver and appearance/settings review remain unexecuted.
- 2026-10-17: Bilal accepted the presented unit overall, authorised its local commit and approved the separate linker-warning fix next, also without suppression. Publication remains separately gated; no PR or CI closure is claimed.

## Run and manual review

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Use disposable text files in a directory with spaces and non-ASCII characters. Check Edit/Save and Undo, Space/Escape, selection changes, preview handoff between windows and owning-window close. Review affected keyboard/focus and VoiceOver behaviour; unexecuted accessibility checks remain Pending. This follow-up does not change existing full-criterion verdicts or establish app-wide acceptance.
