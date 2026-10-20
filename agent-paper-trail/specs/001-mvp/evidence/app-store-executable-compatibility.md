---
task: app-store-executable-compatibility
verdict: Passed
closed: ""
---

# Executable-file and quarantine compatibility

Sandbox script Copy and Save retain executable permissions with OS-managed quarantine; ordinary atomic Save preserves existing quarantine. Sandbox operations may replace quarantine provenance. Other executable types, full Finder/Gatekeeper launch acceptance and macOS 26 remain unverified.
