# CLI and native path opening implementation plan

The [spec](spec.md) owns the contract. Changes follow the [unit and publication gates](../001-mvp/plan.md#task-workflow-and-exit-gates) and [shared review checklist](../../validation/checklist.md).

## Integration boundaries

Both packaging paths use the same launcher resource and URL declarations.

## Unit 1: Native incoming paths

`BrowserLifecycle` owns event and scene routing. `IncomingPath` resolves destinations through the shared access and navigation flow. See the [window policy](spec.md#window-and-request-ownership).

## Unit 2: Bundled launcher and reveal handoff

`PanePeekMain` dispatches CLI mode before SwiftUI using the [accepted entry-point design](../../decisions/2026-11-09-cli-entry-point.md).

## Unit 3: Explicit setup, removal and usage

The Terminal Command panel uses shared folder access for install and removal. It opens on demand independently of browser and updater state. See the [setup contract](spec.md#setup-and-distribution).

## Open coverage

See [validation](validation.md) for remaining checks and [tasks](tasks.md) for manual review and publication.
