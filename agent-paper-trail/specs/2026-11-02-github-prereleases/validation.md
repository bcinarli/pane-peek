# GitHub prerelease validation

The [contract](README.md#installation-and-validation) owns P1–P5. [Tasks](tasks.md) owns manual acceptance and publication. Partial local verification does not establish hosted or public-release acceptance.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| P1 Identity | Passed | [Candidate validation](evidence/prerelease-candidate-notes.md) and [real hosted/published beta identity](evidence/beta-1-3-0.md). |
| P2 Metadata and notes | Passed | [Published metadata and notes](evidence/beta-1-3-0.md) match the exact main source and Unreleased changes. |
| P3 Hosted preparation | Passed | [Real main preparation](evidence/prerelease-hosted-preparation.md) and [accepted downloaded packages](evidence/beta-1-3-0.md). |
| P4 Installation and isolation | Pending | [Public/browser downloads, checksums, prerelease/Latest isolation and signed app launch](evidence/beta-1-3-0.md) pass. Native installation from a browser-quarantined download and stable upgrade eligibility remain unverified. |
| P5 Publication | Passed | [Read-only preparation](evidence/prerelease-hosted-preparation.md) and [separate manual publication](evidence/beta-1-3-0.md) use the unused identity and exact reviewed source; public assets and flags verified. |
