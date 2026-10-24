import Foundation
import Observation

@MainActor @Observable final class AppUpdates {
    enum Phase { case hidden, checking, current, available, downloading, opening, completed, failed }
    private enum Presentation { case manual, reminder }
    private enum Key {
        static let automatic = "updates.automaticChecking"
        static let attempted = "updates.lastAttempt"
        static let later = "updates.remindAfter"
        static let skipped = "updates.skippedRelease"
    }
    private static let day: TimeInterval = 24 * 60 * 60
    private(set) var phase = Phase.hidden
    private(set) var offer: UpdateOffer?
    private(set) var completion: PreparedUpdate?
    private(set) var progress: Double?
    private(set) var errorMessage: String?
    private(set) var operation: Task<Void, Never>?
    private(set) var automaticChecking: Bool
    private(set) var isApplicationActive = false
    private var presentation = Presentation.manual
    @ObservationIgnored private let provider: (any UpdateProvider)?
    @ObservationIgnored private var prepared: PreparedUpdate?
    @ObservationIgnored private var request = UUID()
    @ObservationIgnored private let preferences: UserDefaults?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var remindAfter: Date?
    @ObservationIgnored private var skippedRelease: String?
    @ObservationIgnored private var automaticStarted = false
    @ObservationIgnored private var scheduledCheck: Task<Void, Never>?

    init(provider: (any UpdateProvider)?, preferences: UserDefaults? = nil, now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.preferences = preferences
        self.now = now
        automaticChecking = provider != nil && preferences?.bool(forKey: Key.automatic) == true
        lastAttempt = preferences?.object(forKey: Key.attempted) as? Date
        remindAfter = preferences?.object(forKey: Key.later) as? Date
        skippedRelease = preferences?.string(forKey: Key.skipped)
    }
    var isEnabled: Bool { provider != nil }
    var isBusy: Bool { operation != nil }
    var isPresented: Bool { phase != .hidden }

    var isAutomaticPresentation: Bool { presentation == .reminder }
    var isReminderPresented: Bool { isApplicationActive && isAutomaticPresentation && phase == .available }

    func setAutomaticChecking(_ enabled: Bool) {
        guard isEnabled, automaticChecking != enabled else { return }
        automaticChecking = enabled
        preferences?.set(enabled, forKey: Key.automatic)
        if !enabled, presentation == .reminder {
            if phase == .checking { cancel() }
            else if phase == .available { dismiss() }
        }
        resumeAutomaticChecks()
    }

    func setApplicationActive(_ active: Bool) {
        isApplicationActive = active
        if active { resumeAutomaticChecks() }
    }

    func startAutomaticChecks() {
        automaticStarted = true
        resumeAutomaticChecks()
    }

    func stopAutomaticChecks() {
        automaticStarted = false
        scheduledCheck?.cancel()
        scheduledCheck = nil
        if presentation == .reminder && phase == .checking { cancel() }
    }

    func resumeAutomaticChecks() {
        scheduledCheck?.cancel()
        scheduledCheck = nil
        guard automaticStarted, automaticChecking, isEnabled, operation == nil,
              phase == .hidden else { return }
        let nextCheck = max(lastAttempt?.addingTimeInterval(Self.day) ?? now(), remindAfter ?? .distantPast)
        let delay = nextCheck.timeIntervalSince(now())
        if delay <= 0 { check(automatically: true); return }
        scheduledCheck = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(min(delay, Self.day))) }
            catch { return }
            self?.resumeAutomaticChecks()
        }
    }

    func remindLater() {
        guard presentation == .reminder, phase == .available, !isBusy else { return }
        remindAfter = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now()))
        preferences?.set(remindAfter, forKey: Key.later)
        dismiss()
    }

    func skipVersion() {
        guard presentation == .reminder, phase == .available, !isBusy, let offer else { return }
        skippedRelease = offer.id
        preferences?.set(offer.id, forKey: Key.skipped)
        dismiss()
    }

    func check(reusingResult: Bool = false) {
        guard isEnabled else { return }
        if isBusy || reusingResult { presentation = .manual; return }
        check(automatically: false)
    }

    private func check(automatically: Bool) {
        guard let provider, operation == nil else { return }
        presentation = automatically ? .reminder : .manual
        offer = nil
        prepared = nil
        completion = nil
        errorMessage = nil
        phase = .checking
        lastAttempt = now()
        preferences?.set(lastAttempt, forKey: Key.attempted)
        let id = UUID()
        request = id
        operation = Task {
            defer { finishOperation() }
            do {
                let found = try await provider.check()
                guard request == id, !Task.isCancelled else { return }
                offer = found
                if presentation == .manual { phase = found == nil ? .current : .available }
                else {
                    let allowed = found.map { $0.id != skippedRelease } == true && (remindAfter ?? .distantPast) <= now()
                    phase = allowed ? .available : .hidden
                }
            } catch {
                guard request == id, !Task.isCancelled else { return }
                if presentation == .manual { fail(error) }
                else { phase = .hidden }
            }
        }
    }

    func download() {
        guard let provider, let offer, operation == nil else { return }
        presentation = .manual
        let id = UUID()
        request = id
        progress = nil
        errorMessage = nil
        phase = .downloading
        operation = Task {
            defer { finishOperation() }
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
            defer { finishOperation() }
            do { try await provider.perform(prepared); completion = prepared; phase = .completed }
            catch { fail(error) }
        }
    }

    func retry() {
        if prepared != nil { reopen() }
        else if offer != nil { download() }
        else { check() }
    }

    func closeWindow() -> Bool {
        guard phase != .opening else { return false }
        if isAutomaticPresentation, phase == .available, !isBusy { remindLater() }
        else if isBusy { cancel() }
        else { dismiss() }
        return true
    }

    func dismiss() {
        guard operation == nil else { return }
        phase = .hidden
        resumeAutomaticChecks()
    }

    private func finishOperation() {
        operation = nil
        resumeAutomaticChecks()
    }

    private func fail(_ error: any Error) {
        errorMessage = (error as? UpdateError)?.localizedDescription ?? UpdateError.transport.localizedDescription
        phase = .failed
    }
}
