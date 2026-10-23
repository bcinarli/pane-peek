import Synchronization

/// Holds injected work until its controller explicitly supplies a result.
final class TestRequestGate<Input: Sendable, Output: Sendable>: Sendable {
    enum Failure: Error, Equatable {
        case closed
        case noPendingRequest(Int)
        case duplicateObserver(Int)
    }

    private struct Request {
        let input: Input
        let continuation: CheckedContinuation<Output, any Error>
    }

    private struct Worker: Sendable {
        let cancel: @Sendable () -> Void
        let finish: @Sendable () async -> Void
    }

    private struct State {
        var nextID = 0
        var closed = false
        var requests: [Int: Request] = [:]
        var observers: [Int: CheckedContinuation<Input, any Error>] = [:]
        var workers: [Worker] = []
    }

    private let state = Mutex(State())

    // Worker cancellation deliberately permits a late result for stale-result tests.
    func request(_ input: Input) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let registration = state.withLock { state -> (accepted: Bool, observer: CheckedContinuation<Input, any Error>?) in
                guard !state.closed else { return (false, nil) }
                let id = state.nextID
                state.nextID += 1
                state.requests[id] = Request(input: input, continuation: continuation)
                return (true, state.observers.removeValue(forKey: id))
            }
            if registration.accepted { registration.observer?.resume(returning: input) }
            else { continuation.resume(throwing: Failure.closed) }
        }
    }

    func waitForRequest(_ id: Int) async throws -> Input {
        try await withCheckedThrowingContinuation { continuation in
            let result = state.withLock { state -> Result<Input, Failure>? in
                if state.closed { return .failure(.closed) }
                if let request = state.requests[id] { return .success(request.input) }
                if id < state.nextID { return .failure(.noPendingRequest(id)) }
                if state.observers[id] != nil { return .failure(.duplicateObserver(id)) }
                state.observers[id] = continuation
                return nil
            }
            if let result { continuation.resume(with: result) }
        }
    }

    func finish(_ id: Int, with result: Result<Output, any Error>) throws {
        let continuation = try state.withLock { state in
            if state.closed { throw Failure.closed }
            guard let request = state.requests.removeValue(forKey: id) else {
                throw Failure.noPendingRequest(id)
            }
            return request.continuation
        }
        continuation.resume(with: result)
    }

    /// Own the task until scoped teardown has closed requests and joined its result.
    func track<Value: Sendable, TaskFailure: Error>(_ task: Task<Value, TaskFailure>?) {
        guard let task else { return }
        let worker = Worker(cancel: { task.cancel() }, finish: { _ = await task.result })
        let closed = state.withLock { state in
            state.workers.append(worker)
            return state.closed
        }
        if closed { worker.cancel() }
    }

    func close() {
        let pending = state.withLock { state in
            state.closed = true
            let pending = (requests: state.requests, observers: state.observers, workers: state.workers)
            state.requests.removeAll()
            state.observers.removeAll()
            return pending
        }
        for request in pending.requests.values { request.continuation.resume(throwing: Failure.closed) }
        for observer in pending.observers.values { observer.resume(throwing: Failure.closed) }
        for worker in pending.workers { worker.cancel() }
    }

    fileprivate func tearDown() async {
        close()
        let workers = state.withLock { state in
            let workers = state.workers
            state.workers.removeAll()
            return workers
        }
        for worker in workers { await worker.finish() }
    }
}

func withTestRequestGate<Input: Sendable, Output: Sendable, Value>(
    of: Input.Type, returning: Output.Type,
    isolation: isolated (any Actor)? = #isolation,
    _ body: (TestRequestGate<Input, Output>) async throws -> Value
) async rethrows -> Value {
    let gate = TestRequestGate<Input, Output>()
    return try await withTaskCancellationHandler {
        do {
            let value = try await body(gate)
            await gate.tearDown()
            return value
        } catch {
            await gate.tearDown()
            throw error
        }
    } onCancel: {
        gate.close()
    }
}
