import Foundation
import Testing

/// Controls one injected operation, bounding missing requests and unreleased work.
actor OperationGate {
    struct Failure: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    private let timeout: Duration
    private var deadline: Task<Void, Never>?
    private var failure: Failure?
    private var entered = false
    private var request: CheckedContinuation<Void, any Error>?
    private var observer: CheckedContinuation<Void, any Error>?

    init(timeout: Duration = .seconds(10)) { self.timeout = timeout }
    deinit { deadline?.cancel() }

    func pause() async throws {
        if let failure { throw failure }
        guard !entered else {
            let error = Failure(message: "Duplicate operation gate request")
            abort(error)
            throw error
        }
        entered = true
        startDeadline()
        try await withCheckedThrowingContinuation {
            request = $0
            observer?.resume()
            observer = nil
        }
    }

    func waitForRequest() async throws {
        if let failure { throw failure }
        if entered { return }
        guard observer == nil else {
            let error = Failure(message: "Duplicate operation gate observer")
            abort(error)
            throw error
        }
        startDeadline()
        try await withCheckedThrowingContinuation { observer = $0 }
    }

    func finish() throws {
        guard let request else {
            let error = failure ?? Failure(message: "No pending operation gate request")
            abort(error)
            throw error
        }
        self.request = nil
        deadline?.cancel()
        deadline = nil
        request.resume()
    }

    private func startDeadline() {
        guard deadline == nil else { return }
        let timeout = timeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            await self?.expire()
        }
    }

    private func expire() {
        guard !Task.isCancelled, request != nil || observer != nil else { return }
        let error = Failure(message: "Operation gate timed out; requested: \(entered); waiting for request: \(observer != nil); awaiting release: \(request != nil)")
        Issue.record(error)
        abort(error)
    }

    private func abort(_ error: Failure) {
        failure = error
        deadline?.cancel()
        deadline = nil
        let request = request
        let observer = observer
        self.request = nil
        self.observer = nil
        request?.resume(throwing: error)
        observer?.resume(throwing: error)
    }
}
