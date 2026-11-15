# Highlighting coverage tasks

Scope: Proposed, 2026-11-11. Unit 1 is accepted and on `main`. The [plan](plan.md) owns dependencies and unit boundaries; [validation](validation.md) owns H1–H9 verdicts. Ready means specified work, not coding approval or satisfied dependencies. Each unit needs explicit coding approval and manual acceptance; publication is separate.

| Task | Status | Verdict | Next gate | Manual review | Publication | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| [alias-registration](plan.md#alias-registration) | Completed | Passed | None | Signed-app review and H9 passed | Merged in [PR #195](https://github.com/bcinarli/pane-peek/pull/195) (`b51bf75`) | [Evidence](evidence/alias-registration.md) |
| [markdown-preview-responsiveness](plan.md#markdown-preview-responsiveness) | Completed | Passed | None | Signed-app interactive validation passed | Merged in [PR #205](https://github.com/bcinarli/pane-peek/pull/205) (`4e8ba6b`) | [Evidence](evidence/markdown-preview-responsiveness.md) |
| [docker-ignore](plan.md#docker-ignore) | Completed | Passed | PR review | Signed-app functional, accessibility and H9 checks passed | [PR #196](https://github.com/bcinarli/pane-peek/pull/196) draft | [Evidence](evidence/docker-ignore.md) |
| [version-files](plan.md#version-files) | Blocked | Pending | Deferred until a concrete editing need | Pending | Not published | Not started |
| [dotenv](plan.md#dotenv) | Ready | Pending | Unit 1 accepted and on `main`, Unit 4 coding approval | Pending | Not published | Not started |
| [kotlin](plan.md#kotlin) | Active | Pending | Scope review; Unit 1 acceptance (H9); signed-app and matched Release checks and Unit 5 manual review | Pending | [PR #199](https://github.com/bcinarli/pane-peek/pull/199) draft | [Evidence](evidence/kotlin.md) |
| [ruby](plan.md#ruby) | Ready | Pending | Unit 1 on `main`, scope review and Unit 6 coding approval | Pending | Not published | Not started |
| [objective-c](plan.md#objective-c) | Blocked | Pending | `.m` decision | Pending | Not published | Not started |
| [vimscript](plan.md#vimscript) | Blocked | Pending | Deferred until a concrete editing need | Pending | Not published | Not started |
| [tmux](plan.md#tmux) | Blocked | Pending | Deferred until a concrete editing need | Pending | Not published | Not started |

Keep an implemented unit Active/Pending until its manual review is accepted.
