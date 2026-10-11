# PanePeek review standards

The paper trail owns project requirements. Apply the brief rules below to changed behaviour; follow the linked records for scope. Flag a mismatch between a rule and its source. Use `.github/instructions/code-review.instructions.md` for investigation and comment style.

## Review rules

- **Product boundary:** Keep the native app macOS 26+ and local-only. Transfers reject collisions; deletion uses Trash without permanent fallback. Flag violations in implemented operations, not missing future tasks. [Source](../agent-paper-trail/decisions/0001-product-boundaries.md).
- **Foundation:** Preserve the Swift package/native app foundation and single deployment-target owner. Revisit it through a decision when an integration limitation requires change. [Source](../agent-paper-trail/decisions/0004-swift-package-application.md).
- **Navigation:** Resolve directory links to canonical locations off the UI thread; only the latest successful read replaces the location/listing. Keep selected-item link identity for metadata and copied paths. [Source](../agent-paper-trail/decisions/0005-finder-directory-symlink-navigation.md).
- **Sorting:** Name keeps folders first; Modified sorts all kinds by actual date, with unknowns last in either direction. Preserve selected URLs and pane independence. [Source](../agent-paper-trail/decisions/2026-10-11-modified-sort-policy.md).
- **Preview and Save:** Keep reads bounded to 1 MiB/UTF-8, links read-only for editing, drafts intact on rejected transitions/save failures, and conflict checks before atomic replacement. Preserve BOM, newline sequences and permissions. [Source](../agent-paper-trail/specs/001-mvp/spec.md#details-sidebar-and-preview-editor).
- **Layout:** T19 retains the active browser/document, restores the hidden browser on the right and rejects new hidden-target transfers. Preserve preferred Details width through clamping. Flag regressions when this scope is implemented. [Source](../agent-paper-trail/decisions/2026-10-11-browser-layout-modes-and-details-sizing.md).
- **Accessibility:** Record affected native/keyboard/VoiceOver and appearance checks; visual approval or native defaults do not establish an app-wide pass. [Source](../agent-paper-trail/decisions/2026-10-11-native-accessibility-baseline.md).
- **Intent and evidence:** Keep progress/results out of specs/plans. Task and criterion verdicts need linked evidence; unexecuted manual checks remain pending. [Source](../agent-paper-trail/specs/README.md).
- **Source hygiene:** Keep directory names lowercase except platform-required bundle names. Keep tracking IDs and private paths out of shipped comments; comments explain intent. [Source](../AGENTS.md).

## Keep review bindings in sync

| Restated record | Binding |
| --- | --- |
| `agent-paper-trail/decisions/0001-product-boundaries.md` | this file |
| `agent-paper-trail/decisions/0004-swift-package-application.md` | this file |
| `agent-paper-trail/decisions/0005-finder-directory-symlink-navigation.md` | this file |
| `agent-paper-trail/decisions/2026-10-11-modified-sort-policy.md` | this file |
| `agent-paper-trail/decisions/2026-10-11-browser-layout-modes-and-details-sizing.md` | this file |
| `agent-paper-trail/decisions/2026-10-11-native-accessibility-baseline.md` | this file |
| `agent-paper-trail/specs/001-mvp/spec.md` | this file |
| `agent-paper-trail/specs/README.md` | this file |
| `AGENTS.md` | this file |

When a PR adds, edits or supersedes a mapped record in `agent-paper-trail/decisions/`, `agent-paper-trail/specs/` or `AGENTS.md`, update every mapped binding in the same PR. Flag a missed update or a changed restatement without a map update. Binding changes require code-owner review before merge; ownership is in `.github/CODEOWNERS`.
