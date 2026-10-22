# Protected-folder permissions

Status: Active

Desktop, Documents and Downloads are subject to [macOS privacy controls](https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web), separately from sandbox folder grants. Pending privacy decisions held Home in Loading during native review; system request/reply logs confirm the waits. The precise triggering startup metadata call has not been isolated. Listing does not read child file contents or recursively enumerate folders.

Changed ad hoc review binaries can fail the stored code-requirement match and trigger these prompts again. An unchanged review binary with the same code signature loaded Home promptly on relaunch and from a newly packaged bundle path after the decisions completed. This does not establish fresh-account or denied-access acceptance.

Use [stable certificate signing](../decisions/2026-10-22-stable-review-signing.md) for repeated local review. The first certificate transition can require approval to access existing review-container data; changed executables with the same designated requirement retained that approval in native review. Initial protected-folder choices and certificate-renewal behaviour remain separate.

A Home grant does not imply Full Disk Access or remove other filesystem/privacy restrictions. Fresh-launch prompt timing and denied-access acceptance remain unverified under the [sandbox access design](2026-10-20-app-store-sandbox-design.md). Permission prompts do not establish a signature failure.
