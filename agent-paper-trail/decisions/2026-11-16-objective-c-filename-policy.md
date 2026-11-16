---
status: Accepted
date: 2026-11-16
supersedes: []
superseded_by: ""
---

# Objective-C filename policy

## Decision

Map `.m` and `.mm` to Objective-C and Objective-C++ highlighting through the existing filename registry. Keep `.h` on its existing C-family treatment. Detection remains filename-only; do not inspect content to disambiguate `.m`.

## Rationale and consequences

PanePeek targets macOS, so Objective-C is the default for the shared `.m` extension. MATLAB and other `.m` files therefore receive Objective-C lexical colours; their content and editing remain unchanged. Restricting the dialect to `.mm` would avoid that ambiguity but leave ordinary Objective-C source without its language-specific treatment. Content inference would add a second detection policy outside the accepted scope.

The [highlighting contract](../specs/2026-11-11-highlighting-coverage/spec.md) owns lexical scope. This choice settles filename policy; native acceptance and H9 remain in the [validation record](../specs/2026-11-11-highlighting-coverage/validation.md).
