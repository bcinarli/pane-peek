import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1))) @MainActor struct OperationGateTests {
    @Test(arguments: [false, true])
    func closureReleasesMissingRequestsAndUnreleasedOperations(missingRequest: Bool) async throws {
        try await withOperationGate { gate in
            let pending = Task {
                if missingRequest { try await gate.waitForRequest() }
                else { try await gate.pause() }
            }
            gate.track(pending)
            if !missingRequest { try await gate.waitForRequest() }
            gate.close()
            await #expect(throws: TestRequestGate<Void, Void>.Failure.closed) { try await pending.value }
        }
    }

    @Test func releasesAnObservedOperationAndRejectsDuplicateCompletion() async throws {
        try await withOperationGate { gate in
            let request = Task { try await gate.pause() }
            gate.track(request)
            try await gate.waitForRequest()
            try await gate.finish()
            try await request.value
            await #expect(throws: OperationGate.Failure(message: "No pending operation gate request")) {
                try await gate.finish()
            }
        }
    }

    @Test func duplicateObserversFailBothWaitersInsteadOfReplacingAContinuation() async {
        await withOperationGate { gate in
            let expected = OperationGate.Failure(message: "Duplicate operation gate observer")
            let observer = Task { try await gate.waitForRequest() }
            gate.track(observer)
            await #expect(throws: expected) { try await gate.waitForRequest() }
            await #expect(throws: expected) { try await observer.value }
        }
    }

    @Test func duplicateRequestReleasesTheOriginalOperation() async throws {
        try await withOperationGate { gate in
            let request = Task { try await gate.pause() }
            gate.track(request)
            try await gate.waitForRequest()
            let expected = OperationGate.Failure(message: "Duplicate operation gate request")
            await #expect(throws: expected) { try await gate.pause() }
            await #expect(throws: expected) { try await request.value }
        }
    }

    @Test func pairedScopeFailureClosesBothGatesBeforeJoiningEitherWorker() async {
        let finished = Mutex(0)
        let expected = OperationGate.Failure(message: "Paired controller stopped")
        await #expect(throws: expected) {
            try await withOperationGates { first, second in
                for gate in [first, second] {
                    let pending = Task {
                        defer { finished.withLock { $0 += 1 } }
                        try await gate.pause()
                    }
                    gate.track(pending)
                    try await gate.waitForRequest()
                }
                throw expected
            }
        }
        #expect(finished.withLock { $0 } == 2)
    }

    @Test func requestAcknowledgementAlsoWorksAfterCompletion() async throws {
        try await withOperationGate { gate in
            let request = Task { try await gate.pause() }
            gate.track(request)
            try await gate.waitForRequest()
            try await gate.finish()
            try await request.value
            try await gate.waitForRequest()
        }
    }
}
