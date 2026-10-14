import Foundation
import Testing

@Suite @MainActor struct OperationGateTests {
    @Test(arguments: [false, true])
    func missingRequestOrReleaseReportsTimeout(missingRequest: Bool) async {
        let gate = OperationGate(timeout: .zero)
        let expected = OperationGate.Failure(message: "Operation gate timed out; requested: \(!missingRequest); waiting for request: \(missingRequest); awaiting release: \(!missingRequest)")
        var failure: OperationGate.Failure?
        await withKnownIssue {
            let request = Task {
                do {
                    if missingRequest { try await gate.waitForRequest() }
                    else { try await gate.pause() }
                } catch { failure = error as? OperationGate.Failure }
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(1))
            while failure == nil && ContinuousClock.now < deadline { await Task.yield() }
            #expect(failure == expected)
            await #expect(throws: expected) { try await gate.finish() }
            _ = await request.result
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
