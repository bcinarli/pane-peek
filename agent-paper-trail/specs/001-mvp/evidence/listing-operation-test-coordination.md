---
task: listing-operation-test-coordination
verdict: Pending
closed: ""
---

# Listing and operation test coordination

Controlled listing and operation tests use explicit request acknowledgement and scoped cleanup; paired gates close before owned workers are joined. Local validation passes on Swift 6.4; hosted validation on Swift 6.3.3 remains pending. Other operation tests still contain callback polling.
