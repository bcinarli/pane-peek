---
status: Accepted
date: 2026-10-22
supersedes: []
superseded_by: ""
---
# Stable review signing

## Decision and rationale

Allow explicit certificate signing for the isolated sandbox review build, using the exact fingerprint of a valid Apple Development or Developer ID Application identity with its private key. Prefer Apple Development for daily development. Reusing a stable signing identity allows macOS to recognise changed review executables; ad hoc signatures identify a particular build and can renew privacy prompts. Apple describes the identity constraint in [TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

Keep the separate review identifier/container, Hardened Runtime and the exact [approved sandbox capabilities](2026-10-20-webkit-sandbox-capability.md). Verify the selected Apple-issued certificate and bundle seal after signing. Review signing remains local without a secure timestamp or notarisation. Preserve explicit Developer ID release signing, timestamp/notarisation gates, ordinary unsandboxed development and existing metadata.

## Alternatives and limits

Retain ad hoc review signing when no certificate is selected. Explicit selection avoids silently changing identity or falling back after a signing failure. The initial identity transition can require macOS approval to reuse existing container data; protected-folder privacy choices remain separate. This does not add file access or establish fresh-account, certificate-renewal or distribution acceptance.
