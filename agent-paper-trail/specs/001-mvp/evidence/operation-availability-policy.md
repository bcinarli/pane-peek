---
task: operation-availability-policy
verdict: Passed
closed: "2026-11-01"
---

# Shared operation availability

[PR #160](https://github.com/bcinarli/pane-peek/pull/160) gives BrowserState one owner for shared local operation, naming prompt and Save exclusions; pane, selection, drag and coordinator checks remain action-specific. Rename retains preparation during a pending dirty transition because submission rechecks it; Create retains its active-Rename/coordinator exclusion without depending on the duplicate-submission result slot. Automated availability/native-command checks, packaging and local keyboard/prompt smoke pass on macOS 27, with descriptive resource samples and a 192-byte bundle increase; C3.2 is accepted for the reviewed scope, while live cross-window operation/Save, physical dragging, native Trash and full accessibility remain unverified.
