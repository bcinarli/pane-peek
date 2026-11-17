# Specification technique

Follow the Specs and changes, readiness and acceptance rules in `agent-paper-trail/README.md`. Read the governing spec and only the code, decisions or source material needed to resolve the requested behaviour.

- State observable requirements with stable IDs in the existing format. Keep unsupported assumptions and open questions distinct from accepted requirements.
- Give each requirement meaningful acceptance, including boundary/error cases whose failure matters. Link the configured acceptance home; do not copy verdicts between records.
- Use `design-approach.md` only when future changes need technical choices, responsibilities, interfaces, compatibility or rationale that the spec and code do not make clear. One constraint may fit in the spec. Link existing decisions instead of repeating their alternatives.
- For changes, edit the governing spec on the branch and explain the changed intent in the review home. Keep still-binding requirements in their capability home after delivery finishes.

Present the draft, decision-changing questions and readiness gaps. When reviewed intent merges before code, follow the README's undelivered-requirement rule. Do not treat a draft, accepted intent or delivered code as acceptance of the result.
