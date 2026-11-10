---
task: cli-launcher
verdict: Passed
closed: 2026-11-10
---

# Bundled launcher

Unit 2 on `feature/132-cli`, based on `f98db39`, implements the shell bootstrap, early CLI dispatch and shared guarded browse/reveal flow. Signed local checks verify physical caller-directory handling, literal arguments and links, reveal selection, informational isolation, exit statuses and intended-copy reuse, including two running copies with the same identifier. Both compiled configurations also retain captured-pane ownership, saved two-pane layout and no-open-window delivery. The supplied manual checklist is accepted for ordinary browsing, optional reveal, link/hidden selection, cold/no-window opening, two-pane isolation, dirty-draft cancellation, target-list keyboard focus and informational commands.

The certificate-signed scripted build and profile-signed native archive/export retain the executable launcher, shared metadata, resource integrity and existing capabilities. Store-configuration runtime checks use Developer ID signing: the actual local Store distribution-profile export is killed before command execution, consistent with [Apple's distribution-profile restriction](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles). Apple-distributed runtime acceptance remains pending.

The earlier matched release comparison against `f98db39` found no consistent startup slowdown from the dispatcher; warm or uncontrolled caches and small folders limit that result. The final local debug bundle grows by about 133 KiB without a new runtime dependency. The full native run retains a video-readiness failure reproduced on unchanged `f98db39`; affected launcher checks pass.

Broader Finder/Dock, denied/privacy and document outcomes, full-screen/Spaces, VoiceOver, appearance/settings and protected/large-folder checks remain pending. macOS 26, quarantined/translocated installs, external volumes and Apple-distributed builds remain unverified. Setup/removal belongs to Unit 3; no publication or App Store approval is established.
