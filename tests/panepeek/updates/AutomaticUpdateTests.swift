import Foundation
import Testing
@testable import PanePeek

@MainActor @Suite(.serialized) struct AutomaticUpdateTests {
    @Test func automaticCheckingDefaultsOffAndDisabledProvidersStayOff() async {
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider)
        updates.startAutomaticChecks()
        await Task.yield()
        #expect(!updates.automaticChecking && provider.checks == 0)
        let disabled = AppUpdates(provider: nil)
        disabled.startAutomaticChecks()
        disabled.setAutomaticChecking(true)
        #expect(!disabled.automaticChecking && disabled.operation == nil)
    }

    @Test func automaticAttemptsAreDailyEvenAfterFailuresAndAcrossRelaunches() async throws {
        let preferences = try preferences()
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = ReminderProvider()
        provider.fails = true
        let updates = AppUpdates(provider: provider, preferences: preferences, now: { time })
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        #expect(provider.checks == 1 && updates.phase == .hidden && updates.errorMessage == nil)
        time = time.addingTimeInterval(86_399)
        updates.resumeAutomaticChecks()
        updates.setApplicationActive(true)
        #expect(provider.checks == 1 && updates.operation == nil)
        let restored = AppUpdates(provider: provider, preferences: preferences, now: { time })
        defer { restored.stopAutomaticChecks() }
        restored.startAutomaticChecks()
        #expect(restored.automaticChecking && restored.operation == nil)
        time = time.addingTimeInterval(1)
        restored.resumeAutomaticChecks()
        restored.resumeAutomaticChecks()
        await restored.operation?.value
        #expect(provider.checks == 2 && provider.preparations == 0)
    }

    @Test func availableRemindersWaitForActivation() async {
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider)
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        #expect(updates.phase == .available && !updates.isReminderPresented)
        updates.setApplicationActive(true)
        #expect(updates.isReminderPresented)
        #expect(provider.checks == 1 && provider.preparations == 0)
        updates.setApplicationActive(false)
        #expect(!updates.isReminderPresented)
    }

    @Test func currentAutomaticResultsStayQuietAndDoNotReplaceAManualDialog() async {
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = ReminderProvider()
        provider.available = false
        let updates = AppUpdates(provider: provider, now: { time })
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setApplicationActive(true)
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        #expect(updates.phase == .hidden && !updates.isReminderPresented && provider.preparations == 0)
        updates.check()
        await updates.operation?.value
        time = time.addingTimeInterval(86_400)
        updates.resumeAutomaticChecks()
        #expect(updates.phase == .current && provider.checks == 2)
        updates.dismiss()
        await updates.operation?.value
        #expect(provider.checks == 3 && updates.phase == .hidden)
    }

    @Test func optingOutKeepsAnExplicitlyRequestedDownload() async {
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider)
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setApplicationActive(true)
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        updates.download()
        updates.setAutomaticChecking(false)
        await updates.operation?.value
        #expect(provider.preparations == 1 && updates.phase == .completed && !updates.isAutomaticPresentation)
        updates.dismiss()
        #expect(!updates.isReminderPresented)
    }

    @Test func laterAndSkipPersistWhileManualChecksOverrideThem() async throws {
        let preferences = try preferences()
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider, preferences: preferences, now: { time })
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setApplicationActive(true)
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        updates.remindLater()
        let remindAfter = try #require(preferences.object(forKey: "updates.remindAfter") as? Date)
        #expect(Calendar.current.isDate(remindAfter, inSameDayAs: time.addingTimeInterval(86_400)))
        #expect(updates.phase == .hidden)
        updates.check()
        await updates.operation?.value
        #expect(updates.phase == .available && !updates.isReminderPresented)
        updates.dismiss()
        time = time.addingTimeInterval(86_400)
        updates.resumeAutomaticChecks()
        await updates.operation?.value
        #expect(updates.isReminderPresented)
        updates.skipVersion()
        #expect(updates.phase == .hidden)
        let restored = AppUpdates(provider: provider, preferences: preferences, now: { time })
        defer { restored.stopAutomaticChecks() }
        restored.setApplicationActive(true)
        restored.startAutomaticChecks()
        time = time.addingTimeInterval(86_400)
        restored.resumeAutomaticChecks()
        await restored.operation?.value
        #expect(!restored.isReminderPresented && restored.phase == .hidden)
        restored.check()
        await restored.operation?.value
        #expect(restored.phase == .available)
        restored.dismiss()
        provider.offerID = "next-release"
        time = time.addingTimeInterval(86_400)
        restored.resumeAutomaticChecks()
        await restored.operation?.value
        #expect(restored.isReminderPresented)
    }

    @Test func optingOutSuppressesALateAutomaticResultButKeepsAManualTakeover() async {
        let provider = ReminderProvider()
        provider.pauses = true
        let updates = AppUpdates(provider: provider)
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setAutomaticChecking(true)
        let cancelled = updates.operation
        while provider.result == nil { await Task.yield() }
        updates.setAutomaticChecking(false)
        provider.result?.resume(returning: provider.offer)
        provider.result = nil
        await cancelled?.value
        #expect(updates.phase == .hidden && updates.offer == nil)
        updates.check()
        while provider.result == nil { await Task.yield() }
        updates.setAutomaticChecking(true)
        updates.setAutomaticChecking(false)
        provider.result?.resume(returning: provider.offer)
        await updates.operation?.value
        #expect(updates.phase == .available && !updates.isReminderPresented)
    }

    @Test func manualCommandsJoinAnAutomaticCheckAndRetainHonestFailures() async {
        let provider = ReminderProvider()
        provider.pauses = true
        let updates = AppUpdates(provider: provider)
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setAutomaticChecking(true)
        while provider.result == nil { await Task.yield() }
        updates.check()
        updates.setAutomaticChecking(false)
        provider.result?.resume(returning: nil)
        await updates.operation?.value
        #expect(provider.checks == 1 && updates.phase == .current)
        updates.dismiss()
        provider.pauses = false
        provider.fails = true
        updates.check()
        await updates.operation?.value
        #expect(updates.phase == .failed && updates.errorMessage != nil)
    }

    @Test(arguments: [false, true])
    func closingManualChecksRestoresNextDaysReminders(whileChecking: Bool) async {
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider, now: { time })
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setApplicationActive(true)
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        #expect(updates.isReminderPresented)
        provider.pauses = whileChecking
        updates.check()
        let manual = updates.operation
        if whileChecking {
            while provider.result == nil { await Task.yield() }
        } else { await manual?.value }
        #expect(updates.closeWindow())
        time = time.addingTimeInterval(86_400)
        updates.resumeAutomaticChecks()
        if whileChecking {
            provider.pauses = false
            provider.result?.resume(returning: provider.offer)
            await manual?.value
        }
        await updates.operation?.value
        #expect(provider.checks == 3 && updates.isReminderPresented && provider.preparations == 0)
    }

    @Test func anOfferedReminderWaitsForAChoiceAcrossDays() async {
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider, now: { time })
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setApplicationActive(true)
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        time = time.addingTimeInterval(86_400)
        updates.resumeAutomaticChecks()
        await updates.operation?.value
        #expect(provider.checks == 1 && updates.phase == .available && updates.isReminderPresented)
        #expect(updates.closeWindow())
        await updates.operation?.value
        #expect(updates.phase == .hidden && provider.checks == 1)
    }

    @Test func manualPresentationReusesTheOfferedReminder() async {
        let provider = ReminderProvider()
        let updates = AppUpdates(provider: provider)
        defer { updates.stopAutomaticChecks() }
        updates.startAutomaticChecks()
        updates.setApplicationActive(true)
        updates.setAutomaticChecking(true)
        await updates.operation?.value
        updates.check(reusingResult: true)
        await updates.operation?.value
        #expect(provider.checks == 1 && updates.phase == .available && !updates.isAutomaticPresentation)
        #expect(updates.closeWindow() && updates.phase == .hidden)
    }

    private func preferences() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "PanePeek-update-tests-\(UUID())"))
    }
}

@MainActor private final class ReminderProvider: UpdateProvider {
    var checks = 0
    var preparations = 0
    var available = true
    var fails = false
    var pauses = false
    var offerID = "release"
    var result: CheckedContinuation<UpdateOffer?, Never>?
    var offer: UpdateOffer {
        UpdateOffer(id: offerID, version: "1.2.0", installedVersion: "1.1.0", actionTitle: "Download",
            actionHelp: "Download the DMG and install it manually.", progressTitle: "Downloading…")
    }
    func check() async throws -> UpdateOffer? {
        checks += 1
        if pauses { return await withCheckedContinuation { result = $0 } }
        if fails { throw UpdateError.transport }
        return available ? offer : nil
    }
    func prepare(_ offer: UpdateOffer, progress: @escaping @Sendable (Double?) -> Void) async throws -> PreparedUpdate {
        preparations += 1
        return PreparedUpdate(id: UUID(), title: "Installer opened", message: "Install manually.", reopenTitle: "Open installer again")
    }
    func perform(_ update: PreparedUpdate) async throws {}
}
