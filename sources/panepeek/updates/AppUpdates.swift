import Foundation
import Observation

@MainActor @Observable final class AppUpdates {
    enum Phase { case hidden, checking, current, available, downloading, opening, completed, failed }
    var activeBrowser: ObjectIdentifier?
    private(set) var phase = Phase.hidden
    private(set) var offer: UpdateOffer?
    private(set) var completion: PreparedUpdate?
    private(set) var progress: Double?
    private(set) var errorMessage: String?
    private(set) var operation: Task<Void, Never>?
    @ObservationIgnored private let provider: (any UpdateProvider)?
    @ObservationIgnored private var prepared: PreparedUpdate?
    @ObservationIgnored private var request = UUID()

    init(provider: (any UpdateProvider)?) { self.provider = provider }
    var isEnabled: Bool { provider != nil }
    var isBusy: Bool { operation != nil }
    var isPresented: Bool { phase != .hidden }

    func check() {
        guard let provider, operation == nil else { return }
        offer = nil
        prepared = nil
        completion = nil
        errorMessage = nil
        phase = .checking
        let id = UUID()
        request = id
        operation = Task {
            defer { operation = nil }
            do {
                let found = try await provider.check()
                guard request == id, !Task.isCancelled else { return }
                offer = found
                phase = found == nil ? .current : .available
            } catch {
                guard request == id, !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    func download() {
        guard let provider, let offer, operation == nil else { return }
        let id = UUID()
        request = id
        progress = nil
        errorMessage = nil
        phase = .downloading
        operation = Task {
            defer { operation = nil }
            do {
                let result = try await provider.prepare(offer) { [self] progress in
                    Task { @MainActor in
                        guard self.request == id, self.phase == .downloading else { return }
                        self.progress = progress
                    }
                }
                guard request == id, !Task.isCancelled else { return }
                prepared = result
                phase = .opening
                try await provider.perform(result)
                guard request == id else { return }
                completion = result
                phase = .completed
            } catch {
                guard request == id, !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    func cancel() {
        guard phase == .checking || phase == .downloading else { return }
        let wasChecking = phase == .checking
        request = UUID()
        operation?.cancel()
        progress = nil
        phase = wasChecking ? .hidden : .available
    }

    func reopen() {
        guard let provider, let prepared, operation == nil else { return }
        phase = .opening
        errorMessage = nil
        completion = nil
        operation = Task {
            defer { operation = nil }
            do { try await provider.perform(prepared); completion = prepared; phase = .completed }
            catch { fail(error) }
        }
    }

    func retry() {
        if prepared != nil { reopen() }
        else if offer != nil { download() }
        else { check() }
    }

    func closeManualCheck() -> Bool {
        guard phase != .opening else { return false }
        if isBusy { cancel() }
        else { dismiss() }
        return true
    }

    func dismiss() {
        guard operation == nil else { return }
        phase = .hidden
    }

    private func fail(_ error: any Error) {
        errorMessage = (error as? UpdateError)?.localizedDescription ?? UpdateError.transport.localizedDescription
        phase = .failed
    }
}
