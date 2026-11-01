import Foundation
import Testing

struct NativeTestCoordinationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct NativeTestTimeout: LocalizedError, Equatable {
    let event: String
    var errorDescription: String? { "Timed out waiting for \(event)" }
}

@MainActor final class NativeTestEvent<Value: Sendable> {
    private let name: String
    private let timeout: Duration
    private var result: Result<Value, any Error>?
    private var waiter: CheckedContinuation<Value, any Error>?
    private var deadline: Task<Void, Never>?

    init(_ name: String, timeout: Duration) {
        self.name = name
        self.timeout = timeout
    }

    func wait() async throws -> Value {
        if let result { return try result.get() }
        guard waiter == nil else {
            throw NativeTestCoordinationFailure(message: "Duplicate observer for \(name)")
        }
        deadline = Task { [weak self, timeout] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, !Task.isCancelled else { return }
            let error = NativeTestTimeout(event: self.name)
            Issue.record(error)
            self.complete(.failure(error))
        }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }

    func signal(_ value: Value) { complete(.success(value)) }
    func close() { complete(.failure(CancellationError())) }

    private func complete(_ result: Result<Value, any Error>) {
        guard self.result == nil else { return }
        self.result = result
        deadline?.cancel()
        deadline = nil
        let waiter = waiter
        self.waiter = nil
        waiter?.resume(with: result)
    }
}

@MainActor final class NativeTestRequest<Value: Sendable> {
    let started: NativeTestEvent<Void>
    let result: NativeTestEvent<Value>

    init(started: NativeTestEvent<Void>, result: NativeTestEvent<Value>) {
        self.started = started
        self.result = result
    }

    func value() async throws -> Value {
        started.signal(())
        return try await result.wait()
    }
}

@MainActor final class NativeTestScope {
    private let timeout: Duration
    private var closed = false
    private var events: [() -> Void] = []
    private var workers: [(cancel: () -> Void, finish: () async -> Void)] = []

    init(timeout: Duration = .seconds(5)) { self.timeout = timeout }

    func event<Value: Sendable>(_ name: String) -> NativeTestEvent<Value> {
        let event = NativeTestEvent<Value>(name, timeout: timeout)
        if closed { event.close() }
        else { events.append { event.close() } }
        return event
    }

    func request<Value: Sendable>(_ name: String) -> NativeTestRequest<Value> {
        NativeTestRequest(started: event("\(name) start"), result: event("\(name) result"))
    }

    func track<Value: Sendable, Failure: Error>(_ task: Task<Value, Failure>?) {
        guard let task else { return }
        workers.append((cancel: { task.cancel() }, finish: { _ = await task.result }))
        if closed { task.cancel() }
    }

    func close() {
        closed = true
        let events = events
        self.events = []
        events.forEach { $0() }
        workers.forEach { $0.cancel() }
    }

    func tearDown() async {
        close()
        let workers = workers
        self.workers = []
        for worker in workers { await worker.finish() }
    }
}

@MainActor func withNativeTestScope<Value>(
    timeout: Duration = .seconds(5),
    _ body: (NativeTestScope) async throws -> Value
) async throws -> Value {
    let scope = NativeTestScope(timeout: timeout)
    return try await withTaskCancellationHandler {
        do {
            try Task.checkCancellation()
            let value = try await body(scope)
            await scope.tearDown()
            return value
        } catch {
            await scope.tearDown()
            throw error
        }
    } onCancel: {
        Task { @MainActor in scope.close() }
    }
}
