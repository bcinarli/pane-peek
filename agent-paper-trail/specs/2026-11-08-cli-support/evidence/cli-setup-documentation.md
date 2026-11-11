---
task: cli-setup-documentation
verdict: Passed
closed: 2026-11-11
---

# Terminal setup and usage

The Terminal Command panel manages the bundled launcher from `be0a2e2` and one marked zsh PATH entry. Install and removal preserve unrelated commands and profile contents; app-copy ownership and moved-app recovery are verified locally. Custom shell profiles can add the installed command directory to PATH.

Signed local checks verify installation under a native directory grant, shell lookup with quarantine retained and removal after saved access is restored. Removal restores the original profile bytes and permissions. These checks use Developer ID signatures in both build configurations and generated homes. The signed review app and local Store export retain the bundled launcher and existing app capabilities.

The signed setup flow and revised panel are accepted for Unit 3. Native panel checks verify trailing actions, the Terminal usage hint, initial focus and Close dismissal. Native chooser, broader keyboard and VoiceOver checks, actual Apple-distributed Store runtime and first quarantined GitHub-install behaviour remain open. See the [validation matrix](../validation.md) and [launcher evidence](cli-launcher.md).
