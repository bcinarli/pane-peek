# Protected-folder permission requests

Status: Active

macOS requires consent for access to Desktop, Documents and Downloads, as described in [Apple Platform Security](https://support.apple.com/en-ph/guide/security/secddd1d86a6/web). Bilal reported these requests during T03 review. Startup lists home in both panes and checks each child's metadata/type; those checks are a likely trigger, but the exact call has not been isolated. The listing does not read child file contents or recursively enumerate folders.

Use disposable temporary fixtures for task validation and leave privacy choices to Bilal. Investigating prompt timing on a fresh launch and handling denied access is a separate follow-up; permission prompts do not establish a signature crash.

## Trash access recovery

An iCloud-managed Desktop can be browsable with Desktop privacy consent while File Provider still rejects Trash with Cocoa error 513. Native selection of the containing folder resolved a same-file, same-release-process control; subsequent app restart retained access. This is distinct from enumerating Trash, which has separate privacy requirements, and does not establish a need for broader filesystem permissions.

The [Trash recovery follow-up](../specs/001-mvp/plan.md#trash-folder-access-recovery) requests the captured parent through a native chooser on permission denial. Do not infer mutation access from successful listing or a writable-mode check. Its [evidence](../specs/001-mvp/evidence/trash-folder-access-recovery.md) retains implementation/native acceptance limits; startup prompt timing remains a separate investigation.
