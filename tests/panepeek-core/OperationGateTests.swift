import Foundation
import Testing

@Suite @MainActor struct OperationGateTests {
    @Test(arguments: [false, true])
    func missingRequestOrReleaseReportsTimeout(missingRequest: Bool) async {
        let gate = OperationGate(timeout: .zero)
        let expected = OperationGate.Failure(message: "Operation gate timed out; requested: \(!missingRequest); waiting for request: \(missingRequest); awaiting release: \(!missingRequest)")
        await withKnownIssue {
            await #expect(throws: expected) {
                if missingRequest { try await gate.waitForRequest() }
                else { try await gate.pause() }
            }
            await #expect(throws: expected) { try await gate.finish() }
            await #expect(throws: expected) { try await gate.waitForRequest() }
            await #expect(throws: expected) { try await gate.pause() }
        } matching: { $0.error as? OperationGate.Failure == expected }
    }

    @Test func releasesAnObservedOperationAndRejectsDuplicateCompletion() async throws {
        let gate = OperationGate()
        let request = Task { try await gate.pause() }
        try await gate.waitForRequest()
        try await gate.finish()
        try await request.value
        await #expect(throws: OperationGate.Failure(message: "No pending operation gate request")) {
            try await gate.finish()
        }
    }

    @Test func duplicateObserversFailBothWaitersInsteadOfReplacingAContinuation() async {
        let gate = OperationGate()
        let expected = OperationGate.Failure(message: "Duplicate operation gate observer")
        let observer = Task { try await gate.waitForRequest() }
        await #expect(throws: expected) { try await gate.waitForRequest() }
        await #expect(throws: expected) { try await observer.value }
    }
}
