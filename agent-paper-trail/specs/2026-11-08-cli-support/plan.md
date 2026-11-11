# CLI and native path opening implementation plan

Implement the units in dependency order. The [spec](spec.md) owns behaviour, [tasks](tasks.md) owns progress and [validation](validation.md) owns acceptance. Keep the existing app capabilities and add no runtime dependency or privileged helper.

Each unit requires approval, meaningful red/green checks, tighten then probe, and a signed app for manual review. Manual acceptance precedes the next unit; commit, push, merge and release retain separate gates under the [shared workflow](../001-mvp/plan.md#task-workflow-and-exit-gates).

## Integration boundaries

- `BrowserLifecycle` owns incoming requests and browser-window routing; `IncomingPath` uses existing access, navigation and document guards.
- `PanePeekMain` handles CLI mode before GUI state. Both build paths package the same launcher and URL declarations.
- Terminal setup belongs to the app, with permission and bookmark handling through existing access patterns. Its panel is independent of browser windows and the updater.

## Unit 1: Native incoming paths

Open one macOS-delivered folder or file through the [window and request policy](spec.md#window-and-request-ownership). Retain captured browser ownership, access before document decisions and atomic destination/selection publication. Native opening accepts a link target resolved by macOS before delivery.

## Unit 2: Bundled launcher and reveal handoff

Follow the [CLI entry-point decision](../../decisions/2026-11-09-cli-entry-point.md): the bundled shell captures the physical caller directory and invokes early CLI mode in the app executable. Send validated browse/reveal data to that exact app copy, without granting file access or constructing GUI state for informational commands. Preserve the [command and path contract](spec.md#command-and-destination-rules).

## Unit 3: Explicit setup, removal and usage

Provide **PanePeek → Terminal Command** in both distributions, outside the updater condition. Reuse the native Updates panel presentation, creating the panel and reading setup status only when requested. Confirm signed native chooser grants and saved access before production setup changes.

1. **Show status and actions.** Display the command location, installation status and any access or conflict issue. Add a short Terminal hint for `panepeek` and `panepeek --help`. Align the buttons to the trailing edge and label the dismissal button Close. Offer Install when absent and Uninstall for a link owned by this app, with explicit recovery after an app move or permission loss. Preserve browser and draft state.
2. **Install the link.** Use a dedicated user command directory linked to the current app's `Contents/Resources/panepeek`. Acquire native read/write access and retain it for later removal. Repeated installation is a no-op for the same target; conflicting items remain untouched.
3. **Configure shell lookup.** Offer launcher-only installation for every account. For standard macOS zsh, offer an explicit action that also adds the marked PATH block to `~/.zprofile`. Preserve command priority and profile contents. Report the launcher and profile states separately and direct users to verify lookup in a new shell session.
4. **Remove owned integration.** Verify and remove the launcher link, then remove any unchanged PanePeek profile block managed by that installation. Skip profile cleanup for launcher-only installations. Report `~/.zprofile` if its managed entry needs attention and retain safe retry behavior.
5. **Document usage.** Keep ordinary folder/file paths first and `--reveal` optional. Show the PATH entry in a code box with the file-preview copy icon beside it and a short instruction for using it after installation. Keep the example in the [usage guide](../../../docs/usage.md#open-paths-from-terminal).

Verify ownership, profile preservation, repeat operations, cancellation and recovery using real filesystem fixtures. Signed native review must cover chooser access, saved access after relaunch, command lookup, both build configurations and the [affected accessibility checks](../../validation/checklist.md#accessibility-checks). Keep results and remaining checks in [setup evidence](evidence/cli-setup-documentation.md).

## Known limitations

- Automatic profile setup initially supports standard macOS zsh. Custom shells, relocated profiles and later PATH overrides need explicit handling; installation alone cannot prove availability in every shell.
- User-selected access can expire, and moving the app can break its link. Recovery must preserve ownership and request access again where necessary.
- Local signed checks do not establish Apple-distributed Store or first quarantined GitHub-install behaviour. [Distribution and platform acceptance](validation.md) remains separate; no capability expansion or administrator installation is included.
