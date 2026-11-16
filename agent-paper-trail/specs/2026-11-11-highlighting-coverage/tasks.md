# Highlighting coverage tasks

Scope and manual acceptance are recorded per unit below. Unit 1 is accepted and on `main`. The [plan](plan.md) owns dependencies and unit boundaries; [validation](validation.md) owns H1–H9 verdicts. Ready means specified work, not coding approval or satisfied dependencies. Each unit needs explicit coding approval and manual acceptance; publication is separate.

| Task | Status | Verdict | Next gate | Manual review | Publication | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| [alias-registration](plan.md#alias-registration) | Completed | Passed | None | Signed-app review and H9 passed | Merged in [PR #195](https://github.com/bcinarli/pane-peek/pull/195) (`b51bf75`) | [Evidence](evidence/alias-registration.md) |
| [markdown-preview-responsiveness](plan.md#markdown-preview-responsiveness) | Completed | Passed | None | Signed-app interactive validation passed | Merged in [PR #205](https://github.com/bcinarli/pane-peek/pull/205) (`4e8ba6b`) | [Evidence](evidence/markdown-preview-responsiveness.md) |
| [docker-ignore](plan.md#docker-ignore) | Completed | Passed | None | Signed-app functional, accessibility and H9 checks passed | Merged in [PR #196](https://github.com/bcinarli/pane-peek/pull/196) (`41573f9`) | [Evidence](evidence/docker-ignore.md) |
| [version-files](plan.md#version-files) | Blocked | Pending | Deferred until a concrete editing need | Pending | Not published | Not started |
| [dotenv](plan.md#dotenv) | Completed | Passed | CI and merge | Scope, signed-app review, accessibility and H9 accepted 2026-11-16 | [PR #198](https://github.com/bcinarli/pane-peek/pull/198) awaiting merge | [Evidence](evidence/dotenv.md) |
| [kotlin](plan.md#kotlin) | Ready | Pending | Unit 1 on `main`, scope review and Unit 5 coding approval | Pending | Not published | Not started |
| [ruby](plan.md#ruby) | Ready | Pending | Unit 1 on `main`, scope review and Unit 6 coding approval | Pending | Not published | Not started |
| [objective-c](plan.md#objective-c) | Blocked | Pending | `.m` decision | Pending | Not published | Not started |
| [vimscript](plan.md#vimscript) | Blocked | Pending | Deferred until a concrete editing need | Pending | Not published | Not started |
| [tmux](plan.md#tmux) | Blocked | Pending | Deferred until a concrete editing need | Pending | Not published | Not started |

Keep an implemented unit Active/Pending until its manual review is accepted.
