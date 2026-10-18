---
task: command-drag-and-preview-contrast
verdict: Passed
closed: "2026-10-18"
---

# Command-drag and Preview contrast

## Native failure and correction (2026-10-18)

Author-operated checks confirm default Copy works but Command-move fails. The first move-only-mask correction passes its regressions but does not fix the full gesture. The recording shows a later Copy leaving its source in place; the dark Preview label works.

The diagnostic native retry captures Command in the delivered event and current keyboard state while every receiving-pane callback offers an empty operation mask; the session ends rejected. The table's default modifier-filtering policy also fails the source-contract regression. PanePeek's table now disables that filtering so destinations receive the permitted Copy/Move mask and apply their own modifier choice. This follows the [AppKit source policy](https://developer.apple.com/documentation/appkit/nsdraggingsource/ignoremodifierkeys(for:)). Incoming source restrictions, dirty guards and transfer coordination remain in force. Move-only offered masks are also accepted when independently sampled Command flags are empty; Copy remains preferred when both operations are offered without Command.

The selected Dark Preview/Edit label keeps Base ink while its Mauve bezel remains visible during drag disablement. Manual feedback confirms dark text and clarifies the requested appearance: keep the normal active Dark fill during dragging. An enabled copy of the segmented cell supplies drawing while the live control stays disabled. Agent-observed native rendering confirms stable Mauve fill and dark text, with disabled Preview/Edit accessibility states during the drag and enabled controls after Escape. Light/inactive rendering continues through the native path.

## Executed checks (2026-10-18)

- Red: two operation/native-callback tests fail with six issues, including rejected Move, retained source and absent destination. The native source-policy regression separately fails because modifier filtering is enabled.
- Green: 38 affected functions and all 572 functions pass after the final source correction, with nine expected timeout diagnostics. Two full runs during this unit hit the same restoration timing self-test assertion; both isolated repeats and subsequent full runs pass. No restoration code changed.
- App packaging and isolated launch pass on macOS 27.0.1, Xcode 27.0 / Apple Swift 6.4. Temporary file diagnostics are absent from source and both final app binaries. The final cell-copy appearance change also passes all 12 affected app tests and actual native disabled/enabled rendering checks. Whitespace and changed-document local links pass. Tighten retains the local source/negotiation/label corrections; probe covers copy-only restrictions, unsupported masks, captured selections, guarded actions, draft retention and drag cleanup.

## Manual outcome and limits

Author-operated final default Copy and Command-move checks both pass. A filesystem check independently confirms Command-move source removal and destination bytes. Copy source retention is author-reported. Author-operated stable-fill drag/cancel review also passes. Native automation also fails selected/unselected Finder control drags, so the end-to-end gesture verdict requires an author-operated check. Full VoiceOver, enlarged text and increased-contrast/settings checks remain unreported.

Published in [PR #40](https://github.com/bcinarli/pane-peek/pull/40), targeting `main`. Merge remains separately gated.
