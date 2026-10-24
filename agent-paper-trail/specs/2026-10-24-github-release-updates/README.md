# GitHub release updates

GitHub-distributed PanePeek builds check for releases, download a DMG on request and open it for manual installation. The update provider is replaceable; automatic availability checking is opt-in. [Issue #98](https://github.com/bcinarli/pane-peek/issues/98) defines the workstream.

| Record | Purpose |
| --- | --- |
| [Spec](spec.md) | Current behaviour, integration boundary and known limits. |
| [Plan](plan.md) | Implementation units, dependencies and validation gates. |
| [Tasks](tasks.md) | Implementation, manual-review and publication state. |
| [Validation](validation.md) | Update acceptance criteria and remaining checks. |
| [Evidence](evidence/github-release-updates.md) | Verified outcome and material acceptance limits. |
| [Decision](../../decisions/2026-10-24-github-release-updates.md) | Provider choice and privacy/sandbox policy. |
| [Design](../../design/001-mvp/README.md#release-update-banner) | Accepted banner and editable app preview. |

The [native MVP baseline](../001-mvp/spec.md) remains binding for browser/editor isolation, guarded quitting, accessibility and release packaging. Its A40 entry links this package's update contract and acceptance.
