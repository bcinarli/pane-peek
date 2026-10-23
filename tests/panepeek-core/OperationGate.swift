import Foundation

/// Controls one injected operation; its enclosing scope owns cancellation and cleanup.
actor OperationGate {
    struct Failure: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    private let requests: TestRequestGate<Void, Void>
    private let workers: TestRequestGate<Void, Void>
    private var failure: Failure?
    private var entered = false

    init(requests: TestRequestGate<Void, Void>, workers: TestRequestGate<Void, Void>) {
        self.requests = requests
        self.workers = workers
    }

    func pause() async throws {
        if let failure { throw failure }
        guard !entered else {
            let error = Failure(message: "Duplicate operation gate request")
            abort(error)
            throw error
        }
        entered = true
        do { try await requests.request(()) }
        catch {
            if let failure { throw failure }
            throw error
        }
    }

    func waitForRequest() async throws {
        if let failure { throw failure }
        do { _ = try await requests.waitForRequest(0) }
        catch TestRequestGate<Void, Void>.Failure.noPendingRequest(0) where entered { return }
        catch TestRequestGate<Void, Void>.Failure.duplicateObserver(0) {
            let error = Failure(message: "Duplicate operation gate observer")
            abort(error)
            throw error
        } catch {
            if let failure { throw failure }
            throw error
        }
    }

    func finish() throws {
        if let failure { throw failure }
        do { try requests.finish(0, with: .success(())) }
        catch {
            let error = Failure(message: "No pending operation gate request")
            abort(error)
            throw error
        }
    }

    nonisolated func track<Value: Sendable, TaskFailure: Error>(_ task: Task<Value, TaskFailure>?) {
        workers.track(task)
    }

    nonisolated func close() { requests.close() }

    private func abort(_ error: Failure) {
        failure = error
        requests.close()
    }
}

func withOperationGate<Value>(
    isolation: isolated (any Actor)? = #isolation,
    _ body: (OperationGate) async throws -> Value
) async rethrows -> Value {
    try await withTestRequestGate(of: Void.self, returning: Void.self, isolation: isolation) { requests in
        try await body(OperationGate(requests: requests, workers: requests))
    }
}

func withOperationGates<Value>(
    isolation: isolated (any Actor)? = #isolation,
    _ body: (OperationGate, OperationGate) async throws -> Value
) async rethrows -> Value {
    try await withTestRequestGate(of: Void.self, returning: Void.self, isolation: isolation) { first in
        try await withTestRequestGate(of: Void.self, returning: Void.self, isolation: isolation) { second in
            // The inner scope closes before the outer scope joins either gate's workers.
            try await body(OperationGate(requests: first, workers: first),
                           OperationGate(requests: second, workers: first))
        }
    }
}
