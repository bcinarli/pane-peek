import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct TestRequestGateTests {
    private enum InjectedFailure: Error { case rejected }
    private typealias Gate = TestRequestGate<String, Int>

    @Test func capturesRequestsAndCompletesThemInTheControllersOrder() async throws {
        try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
            let first = Task { try await gate.request("first") }
            gate.track(first)
            #expect(try await gate.waitForRequest(0) == "first")
            // An observer arriving after the request sees the same captured input.
            #expect(try await gate.waitForRequest(0) == "first")
            let second = Task { try await gate.request("second") }
            gate.track(second)
            #expect(try await gate.waitForRequest(1) == "second")
            try gate.finish(1, with: .success(20))
            #expect(try await second.value == 20)
            try gate.finish(0, with: .success(10))
            #expect(try await first.value == 10)
            #expect(throws: Gate.Failure.noPendingRequest(0)) { try gate.finish(0, with: .success(30)) }
            await #expect(throws: Gate.Failure.noPendingRequest(0)) { try await gate.waitForRequest(0) }
        }
    }

    @Test func explicitFailureReachesTheWorker() async throws {
        try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
            let worker = Task { try await gate.request("failure") }
            gate.track(worker)
            _ = try await gate.waitForRequest(0)
            try gate.finish(0, with: .failure(InjectedFailure.rejected))
            await #expect(throws: InjectedFailure.rejected) { try await worker.value }
        }
    }

    @Test func cancelledWorkerCanStillDeliverItsControlledLateResult() async throws {
        try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
            let worker = Task { try await gate.request("old work") }
            gate.track(worker)
            _ = try await gate.waitForRequest(0)
            worker.cancel()
            try gate.finish(0, with: .success(42))
            #expect(try await worker.value == 42)
        }
    }

    @Test func closingReleasesPendingWorkersAndObserversAndRejectsNewWork() async throws {
        let gate = Gate()
        defer { gate.close() }
        let observer = Task { try await gate.waitForRequest(1) }
        let worker = Task { try await gate.request("pending") }
        _ = try await gate.waitForRequest(0)
        gate.close()
        gate.close()
        await #expect(throws: Gate.Failure.closed) { try await observer.value }
        await #expect(throws: Gate.Failure.closed) { try await worker.value }
        await #expect(throws: Gate.Failure.closed) { try await gate.request("late") }
        await #expect(throws: Gate.Failure.closed) { try await gate.waitForRequest(2) }
        #expect(throws: Gate.Failure.closed) { try gate.finish(0, with: .success(1)) }
    }

    @Test func throwingControllerClosesTheGateAndJoinsItsWorkers() async throws {
        let finished = TestSharedState(false)
        await #expect(throws: InjectedFailure.rejected) {
            try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
                let worker = Task {
                    defer { finished.value.withLock { $0 = true } }
                    return try await gate.request("pending")
                }
                gate.track(worker)
                _ = try await gate.waitForRequest(0)
                throw InjectedFailure.rejected
            }
        }
        #expect(finished.value.withLock { $0 })
    }

    @Test func cancellingControllerClosesItsWaitAndJoinsItsWorkers() async throws {
        let finished = TestSharedState(false)
        let (started, signal) = AsyncStream<Void>.makeStream()
        let controller = Task {
            try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
                let worker = Task {
                    defer { finished.value.withLock { $0 = true } }
                    return try await gate.request("pending")
                }
                gate.track(worker)
                _ = try await gate.waitForRequest(0)
                signal.finish()
                _ = try await gate.waitForRequest(1)
            }
        }
        for await _ in started { }
        controller.cancel()
        await #expect(throws: Gate.Failure.closed) { try await controller.value }
        #expect(finished.value.withLock { $0 })
    }

    @Test func duplicateObserversDoNotLoseTheOriginalWaiter() async throws {
        try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
            let (results, source) = AsyncStream<Result<String, any Error>>.makeStream()
            defer { source.finish() }
            for _ in 0..<2 {
                let observer = Task {
                    do { source.yield(.success(try await gate.waitForRequest(0))) }
                    catch { source.yield(.failure(error)) }
                }
                gate.track(observer)
            }
            var iterator = results.makeAsyncIterator()
            let rejected = try #require(await iterator.next())
            #expect(throws: Gate.Failure.duplicateObserver(0)) { try rejected.get() }
            let worker = Task { try await gate.request("original observer") }
            gate.track(worker)
            let accepted = try #require(await iterator.next())
            #expect(try accepted.get() == "original observer")
            try gate.finish(0, with: .success(1))
            #expect(try await worker.value == 1)
        }
    }

    @Test func cancellationBeforeScopeEntryAlsoReleasesNewWorkers() async throws {
        let finished = TestSharedState(false)
        let controller = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await withTestRequestGate(of: String.self, returning: Int.self) { gate in
                let worker = Task {
                    defer { finished.value.withLock { $0 = true } }
                    return try await gate.request("already cancelled")
                }
                gate.track(worker)
                _ = try await gate.waitForRequest(0)
            }
        }
        await #expect(throws: Gate.Failure.closed) { try await controller.value }
        #expect(finished.value.withLock { $0 })
    }

    @Test func successfulScopeAlsoClosesItsGate() async throws {
        let gate = await withTestRequestGate(of: String.self, returning: Int.self) { $0 }
        await #expect(throws: Gate.Failure.closed) { try await gate.request("after scope") }
    }
}
