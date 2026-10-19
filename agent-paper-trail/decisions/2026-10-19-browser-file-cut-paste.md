---
status: Accepted
date: 2026-10-19
supersedes: []
superseded_by: ""
---

# Browser file Cut and Paste

## Context

The browser Edit menu supports file Copy/Paste and explicit Move Item Here. Add Command-X followed by Command-V for moving files within PanePeek, while retaining Option-Command-V and native text editing.

## Decision

- Cut exports the selected file URLs and records pending move intent in app memory. It does not mutate files. Bind the intent to the exact clipboard revision and contents; external clipboard flags cannot create move intent.
- Paste moves a matching Cut selection into the receiving browser directory, across panes/windows and in one-pane mode. Otherwise Paste copies. Existing transfer capture, collision handling, dirty-document protection and operation coordination apply.
- Clipboard replacement or a new Copy cancels pending Cut intent. Cancellation before mutation retains it for retry. After a partial move, retain only sources not reported as relocated; after all sources move, clear the matching clipboard. Completion must not overwrite newer clipboard contents or a newer Cut.
- Pending intent is session-local. Finder receives ordinary file URLs: its normal Paste copies, and Option-Command-V remains the explicit move route. Text/rename fields retain native Cut/Paste.
- File-operation Undo/Redo remains excluded.

## Alternatives

Keep only Copy followed by Option-Command-V: simpler, but does not offer the requested Cut/Paste gesture. Trust a clipboard marker as move intent: rejected because another app could supply or restore it.

## Consequences

The clipboard workflow needs the actual move result to distinguish cancellation from partial relocation. Reuse the existing transfer engine and expose its move completion; do not infer success from shared UI state or source existence.
