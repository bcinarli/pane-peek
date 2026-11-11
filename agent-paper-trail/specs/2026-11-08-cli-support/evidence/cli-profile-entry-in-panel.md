---
task: cli-profile-entry-in-panel
verdict: Pending
closed: ""
---

# Shell profile entry in the Terminal Command panel

The panel based on `35ebe66` shows the PATH entry in a wrapping code box with the file-preview copy icon beside it. Native checks verify placement, contrast, exact clipboard text and feedback across the checked panel states. Signed manual review, keyboard copying and VoiceOver remain pending.

The generated entry finds and runs the signed launcher in Bash, zsh, `sh`, `dash` and `ksh`. Bash and zsh login and interactive startup files load the entry. Fish, `csh` and `tcsh` require shell-native PATH syntax.
