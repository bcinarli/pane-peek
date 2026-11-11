# CLI and native path opening validation

The [spec](spec.md#acceptance-criteria) defines C1–C7. [Task verdicts](tasks.md) apply to the reviewed scope. MVP delivery is closed under [release-specific waivers](../../notes/2026-11-08-mvp-closure.md).

| Criterion | Verdict | Verified scope | Remaining coverage |
| --- | --- | --- | --- |
| C1 Native destinations | Pending | [Folder, file and hidden-item opening, including macOS-delivered link targets](evidence/native-path-opening.md). | Native selection of case-distinct entries on a case-sensitive volume. |
| C2 Launch and ownership | Pending | [Native opening](evidence/native-path-opening.md), [exact-copy launcher delivery](evidence/cli-launcher.md) and [saved and fresh window startup](evidence/cli-typed-window-restoration.md). | Finder opening in cold and running states, Dock activation with a minimised window, multi-item delivery and error dismissal with no browser window. |
| C3 Access and document safeguards | Pending | [Saved read-only access, write upgrade and document choices](evidence/native-path-opening.md). [Busy-window waiting, supersession and cancellation](evidence/cli-busy-incoming-open.md). | Native rename, denied and protected-folder access, and close or quit with a permission request pending. |
| C4 Launcher paths | Pending | [Physical caller directory, literal arguments and links, and running reveal](evidence/cli-launcher.md). | Signed root and external-volume opens. See C3 and C5 for permission outcomes. |
| C5 CLI output and exit status | Pending | [GUI-free help/version, usage errors, confirmed absence and invalid bundle metadata](evidence/cli-launcher.md). | End-to-end handoff failure, protected-folder preflight, first-install side effects, macOS 26 and Apple-distributed runtime. |
| C6 Setup and distribution | Pending | [Local signed setup, saved-access removal and packaging](evidence/cli-setup-documentation.md). [Installer and recovery task verdicts](tasks.md). | Native chooser, [signed manual PATH panel review](evidence/cli-profile-entry-in-panel.md), Apple-distributed runtime and first quarantined GitHub install, including translocation. |
| C7 Native and accessibility review | Pending | [Native window/pane and document checks](evidence/native-path-opening.md) and [target-list keyboard focus](evidence/cli-launcher.md). | Terminal Command keyboard, VoiceOver and appearance. Full-screen and Spaces, enlargement and accessibility settings, and protected or large folders. |
