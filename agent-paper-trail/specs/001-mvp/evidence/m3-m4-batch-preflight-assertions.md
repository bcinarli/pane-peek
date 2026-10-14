---
task: m3-m4-batch-preflight-assertions
verdict: Passed
closed: "2026-10-14"
---

# M3/M4 batch-preflight assertions

C1.2 addresses reviewed finding F4. Bilal approved implementation on 2026-10-14 after accepting C1.1. Bilal accepted the presented unit and authorised its commit on 2026-10-14. Publication retains separate approval.

## Scope and checks

The identified batch Copy/Move conflict tests now require their operation's PreflightError and verify its source, destination and collision/ancestry reason. Unexpected errors propagate as test failures. Expected reasons use the existing public error categories without pinning the complete formatted message. Move's occupied-destination and duplicate-name cases use independent fixtures. Preservation checks cover selected source contents and occupied destinations.

- 2026-10-14: existing behaviour remained green during assertion tightening; final `node scripts/test.mjs --filter 'BatchCopyTests|BatchMoveTests'` passed 21 tests across three suites. `swift build --product PanePeek` and `git diff --check` passed on macOS 27.0.1 with Swift 6.4.
- 2026-10-14: production sources are unchanged; the isolated C1.1 review app remains running and is reused for this test-only unit. No new packaging run or interactive native check is claimed. The unit adds no affected accessibility checks; the existing T18 audit remains pending.
- Tighten parameterised equivalent Move cases and kept assertions local. Probe checked the conflicting source/destination attribution, canonical Copy destination, exact public rejection category and preservation of the actual duplicate-name source. Bilal accepted the unit overall on 2026-10-14; individual native observations were not separately supplied.

Reproduce:

```sh
node scripts/test.mjs --filter 'BatchCopyTests|BatchMoveTests'
swift build --product PanePeek
```
