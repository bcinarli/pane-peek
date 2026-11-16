---
name: panepeek-paper-trail
description: Explore, specify, plan, implement, review, hand off or reconcile PanePeek work using its repository-owned contracts and workflow. Keep eligible durable facts current without recording execution history.
metadata:
  version: 0.2.1
  paper-trail-conventions: 0.7.0
---

# PanePeek project workflow

## Overview

Use this workflow for daily PanePeek work, including requests that combine operations. Paths below are repository-root paths; locate the checkout first. No personal skill, preference file or private journal is required.

## Source of truth

Read `AGENTS.md`, then `agent-paper-trail/README.md`. The README owns settings, content exclusions, maintenance and acceptance rules. Follow its conventions `0.7.0`; report a version/rule mismatch instead of silently upgrading guidance.

Read `agent-paper-trail/engineering-and-review.md` and select relevant sources through `agent-paper-trail/INDEX.md`. Consult only governing requirements, decisions, acceptance rows and legacy scope needed for the requested work. Open outcome summaries only when provenance or limitations matter. Use `CONTRIBUTING.md` for build/run commands.

## Operations

Identify the requested operations, existing authority and dependencies. Apply the README's gates and conversation-draft fallback when shared access or write authority is unavailable. Do not turn exploration, planning or review into implementation without authority.

| Operation | Action and output |
| --- | --- |
| `explore` | Inspect the bounded question; return evidence, options and consequential unknowns in the conversation or issue. Separate recommendations from accepted intent. |
| `spec` | Find or draft the governing capability contract under the spec-first setting. Read `agent-paper-trail/skills/panepeek-paper-trail/references/specification.md`. Present readiness gaps and decision-changing questions. |
| `plan` | Prepare or reuse a proportionate delivery plan in the GitHub issue. Read `agent-paper-trail/skills/panepeek-paper-trail/references/delivery.md`. Preserve existing legacy scope and identify the first reviewable unit. |
| `implement` | Verify dependencies on main, agreed scope/checkpoints and required performance baseline. Implement within that scope, run meaningful checks, simplify then check failure modes/evidence, and present the affected surface for manual review at agreed checkpoints and final acceptance. Follow the delivery reference and shared engineering rules. |
| `review` | Inspect the requested change against requirements and the selected lens. Use the delivery reference; return source-backed findings in the review surface. Do not edit or post without authority. |
| `handoff` | Use the delivery reference to prepare shared continuation in the issue, linked from the PR. State sources/revision, remaining scope, evidence, decisions and next action. |
| `reconcile` | Apply the README's content gate and Maintain sequence to changed eligible facts. Update their owners and affected acceptance/bindings; no changed eligible fact means no record update. |

Use `agent-paper-trail/skills/panepeek-paper-trail/references/writing.md` for authored records and instructions. The README remains sufficient for direct use or a reviewed skill opt-out.

## PanePeek review checks

Apply `agent-paper-trail/validation/checklist.md`. Preserve native accessibility, matched performance comparisons, meaningful red/green TDD and manual acceptance of the delivered result. Follow agreed intermediate checkpoints, maintainer/code-owner merge review and explicit release authority. A Ready row does not establish scope agreement or satisfied dependencies; a green build is not manual acceptance.

Before handoff, simplify duplicated guidance, then check requirement conflicts, unsupported verdicts, missing affected checks and broken links. Perform these checks directly or with available tools; no personal skill installation is required. Report actual validation and remaining limits in the PR or conversation draft.

## What not to do

Do not add records merely because a unit or review finished. Apply the README's exclusions before any task, criterion, evidence, decision or handoff-record obligation. Do not duplicate verdicts in outcome summaries or turn Pending coverage into a pass. Preserve existing IDs, acceptance owners, waivers and links until a reviewed migration changes ownership. Never infer acceptance from code, merge state or automated checks alone.
