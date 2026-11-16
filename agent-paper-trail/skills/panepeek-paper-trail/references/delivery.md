# Delivery technique

Use the working-plan and review homes named in `agent-paper-trail/README.md`. Apply its authorisation and content rules before choosing where to write. Build/run commands belong in the project's contributor guide.

## Plan and implement

Plan from the requested outcome and governing requirements, or stated intent and established constraints when no spec is required. For each meaningful unit, name its scope, dependencies, validation and relevant requirement IDs. Keep plans proportional; a small change may need one sentence.

When planning from review findings, group them by shared cause, dependency or validation boundary. Keep their mapping to units in the working-plan home. Do not manufacture a fixed number of units or turn the mapping into paper-trail records.

Implement within existing authority and required review checkpoints. Simplify the result, then check realistic failure modes and affected validation. Report checks actually performed and material limits in the review home; a passing automated check is not human or release acceptance.

## Review

Read the bounded area and enough surrounding code to support the requested lens. Check requirements and behaviour, or maintainability, consistency, duplication, readability and test quality as requested. State each consequential finding with its source, triggering condition, consequence and smallest correction. Separate observed defects from missing evidence. If no material findings exist, say so without inventing work.

## Handoff

Apply the README's Team continuation rules. Update the shared working-plan home with the minimum continuation context: delivery item, governing sources and revision, completed/remaining scope, evidence links, unresolved decisions and next action. Preserve usable investigation there instead of requiring private chat history. No additional paper-trail summary is needed merely because work changes hands.

For PanePeek, the GitHub issue owns the delivery plan and handoff; the PR links to it and owns detailed verification. Apply `agent-paper-trail/engineering-and-review.md` for unit approval, performance baselines, affected-surface checks and manual acceptance.
