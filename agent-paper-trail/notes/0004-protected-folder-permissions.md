# Protected-folder permission requests

macOS requires consent for access to Desktop, Documents and Downloads, as described in [Apple Platform Security](https://support.apple.com/en-ph/guide/security/secddd1d86a6/web). Bilal reported these requests during T03 review. Startup lists home in both panes and checks each child's metadata/type; those checks are a likely trigger, but the exact call has not been isolated. The listing does not read child file contents or recursively enumerate folders.

Use disposable temporary fixtures for task validation and leave privacy choices to Bilal. Investigating prompt timing on a fresh launch and handling denied access is a separate follow-up; permission prompts do not establish a signature crash.
