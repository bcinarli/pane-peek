import Foundation
import Observation

/// Window-local operation messages, including failures retained across later operations.
@MainActor @Observable
public final class OperationNotifications {
    public struct Notice: Identifiable, Equatable, Sendable {
        public enum Kind: Sendable { case progress, success, error, information }
        public let id: UUID
        public let kind: Kind
        public let message: String
        public var summary: String { String(message.split(separator: "\n", maxSplits: 1).first ?? "") }
    }

    public private(set) var notices: [Notice] = []
    @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void
    @ObservationIgnored private var timers: [UUID: Task<Void, Never>] = [:]

    public init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    deinit { for timer in timers.values { timer.cancel() } }

    @discardableResult public func post(_ message: String, kind: Notice.Kind) -> UUID {
        let notice = Notice(id: UUID(), kind: kind, message: message)
        notices.insert(notice, at: 0)
        if kind == .success {
            let sleep = sleep
            timers[notice.id] = Task { [weak self] in
                do { try await sleep(.seconds(5)) } catch { return }
                guard !Task.isCancelled else { return }
                self?.dismiss(notice.id)
            }
        }
        return notice.id
    }

    public func finish(_ id: UUID, message: String, succeeded: Bool) {
        dismiss(id)
        post(message, kind: succeeded ? .success : .error)
    }

    public func dismiss(_ id: UUID) {
        timers.removeValue(forKey: id)?.cancel()
        notices.removeAll { $0.id == id }
    }
}
