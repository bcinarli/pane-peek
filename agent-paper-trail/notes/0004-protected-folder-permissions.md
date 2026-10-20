# Protected-folder permissions

Status: Active

Desktop, Documents and Downloads are subject to [macOS privacy controls](https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web), separately from sandbox folder grants. Those prompts have been observed; the precise triggering startup metadata call has not been isolated. Listing does not read child file contents or recursively enumerate folders.

A Home grant does not imply Full Disk Access or remove other filesystem/privacy restrictions. Fresh-launch prompt timing and denied-access acceptance remain unverified under the [sandbox access design](2026-10-20-app-store-sandbox-design.md). Permission prompts do not establish a signature failure.
