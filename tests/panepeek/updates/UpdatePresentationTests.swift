import Foundation
import Observation
import Synchronization
import Testing
@testable import PanePeek

@Suite(.serialized) @MainActor struct UpdatePresentationTests {
    @Test func repeatedManualChecksCoalesceWithoutABrowser() async {
        let provider = WindowUpdateProvider()
        let updates = AppUpdates(provider: provider)
        updates.check()
        updates.check()
        await updates.operation?.value
        #expect(provider.checks == 1 && updates.phase == .current)
        #expect(updates.closeManualCheck() && updates.phase == .hidden)
    }

    @Test func closingACheckSuppressesALateAvailableResult() async {
        let provider = WindowUpdateProvider()
        provider.pauseCheck = true
        let updates = AppUpdates(provider: provider)
        updates.check()
        let operation = updates.operation
        while provider.checkResult == nil { await Task.yield() }
        #expect(updates.closeManualCheck() && operation?.isCancelled == true)
        provider.checkResult?.resume(returning: provider.offer)
        await operation?.value
        #expect(updates.phase == .hidden && updates.offer == nil)
    }

    @Test func closingADownloadCannotOpenItsLateInstaller() async {
        let provider = WindowUpdateProvider()
        provider.available = true
        provider.pausePreparation = true
        let updates = AppUpdates(provider: provider)
        updates.check()
        await updates.operation?.value
        updates.download()
        let operation = updates.operation
        while provider.preparation == nil { await Task.yield() }
        #expect(updates.closeManualCheck() && operation?.isCancelled == true)
        provider.preparation?.resume(returning: provider.prepared)
        await operation?.value
        #expect(provider.performances == 0 && !updates.isBusy)
    }

    @Test func closingWaitsForAnAlreadyStartedSystemHandoff() async {
        let provider = WindowUpdateProvider()
        provider.available = true
        provider.pauseHandoff = true
        let updates = AppUpdates(provider: provider)
        updates.check()
        await updates.operation?.value
        updates.download()
        while provider.handoff == nil { await Task.yield() }
        #expect(!updates.closeManualCheck() && updates.phase == .opening)
        provider.handoff?.resume()
        await updates.operation?.value
        #expect(updates.closeManualCheck() && provider.performances == 1)
    }

    @Test func finishingCancellationInvalidatesTheBusyControls() async {
        let provider = WindowUpdateProvider()
        provider.pauseCheck = true
        let updates = AppUpdates(provider: provider)
        updates.check()
        let operation = updates.operation
        while provider.checkResult == nil { await Task.yield() }
        _ = updates.closeManualCheck()
        let changed = Mutex(false)
        withObservationTracking { _ = updates.isBusy } onChange: { changed.withLock { $0 = true } }
        provider.checkResult?.resume(returning: nil)
        await operation?.value
        #expect(!updates.isBusy && changed.withLock { $0 })
    }
}

@MainActor private final class WindowUpdateProvider: UpdateProvider {
    var checks = 0
    var performances = 0
    var available = false
    var pauseCheck = false
    var pausePreparation = false
    var pauseHandoff = false
    var checkResult: CheckedContinuation<UpdateOffer?, Never>?
    var preparation: CheckedContinuation<PreparedUpdate, Never>?
    var handoff: CheckedContinuation<Void, Never>?
    let offer = UpdateOffer(id: "window", version: "1.2.0", installedVersion: "1.1.0", actionTitle: "Download", actionHelp: "Download the DMG and install it manually.", progressTitle: "Downloading PanePeek 1.2.0…")
    let prepared = PreparedUpdate(id: UUID(), title: "Installer opened", message: "Quit PanePeek, then drag PanePeek to Applications.", reopenTitle: "Open installer again")
    func check() async throws -> UpdateOffer? {
        checks += 1
        if pauseCheck { return await withCheckedContinuation { checkResult = $0 } }
        return available ? offer : nil
    }
    func prepare(_ offer: UpdateOffer, progress: @escaping @Sendable (Double?) -> Void) async throws -> PreparedUpdate {
        if pausePreparation { return await withCheckedContinuation { preparation = $0 } }
        return prepared
    }
    func perform(_ update: PreparedUpdate) async throws {
        performances += 1
        if pauseHandoff { await withCheckedContinuation { handoff = $0 } }
    }
}

