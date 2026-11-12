# CLI and native path opening

[#132](https://github.com/bcinarli/pane-peek/issues/132) is a post-MVP feature for opening one local path from Terminal or macOS and managing the bundled launcher from **PanePeek → Terminal Command**.

The contract is accepted. C1–C7 and signed manual review of the copyable PATH panel remain pending.

| Record | Purpose |
| --- | --- |
| [Spec](spec.md) | Accepted command, window and setup contract. |
| [Integration plan](plan.md) | Runtime and packaging boundaries. |
| [CLI entry point](../../decisions/2026-11-09-cli-entry-point.md) | Launcher design and trade-offs. |
| [Tasks](tasks.md) | Manual checklist results, local commits and publication. |
| [Validation](validation.md) | Criterion coverage and remaining checks. |

The [MVP package](../001-mvp/README.md) remains the native baseline after [delivery closure with release-specific waivers](../../notes/2026-11-08-mvp-closure.md). The [shared review gates](../../validation/checklist.md) apply. See the [usage guide](../../../docs/usage.md#open-paths-from-terminal) for terminal setup and commands.
