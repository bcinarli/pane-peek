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
        #expect(updates.closeWindow() && updates.phase == .hidden)
    }

    @Test func closingACheckSuppressesALateAvailableResult() async throws {
        try await withNativeTestScope { scope in
            let provider = WindowUpdateProvider()
            let check: NativeTestRequest<UpdateOffer?> = scope.request("update check")
            provider.checkRequest = check
            let updates = AppUpdates(provider: provider)
            updates.check()
            let operation = updates.operation
            scope.track(operation)
            try await check.started.wait()
            #expect(updates.closeWindow() && operation?.isCancelled == true)
            check.result.signal(provider.offer)
            await operation?.value
            #expect(updates.phase == .hidden && updates.offer == nil)
        }
    }

    @Test func closingADownloadCannotOpenItsLateInstaller() async throws {
        try await withNativeTestScope { scope in
            let provider = WindowUpdateProvider()
            provider.available = true
            let preparation: NativeTestRequest<PreparedUpdate> = scope.request("installer preparation")
            provider.preparationRequest = preparation
            let updates = AppUpdates(provider: provider)
            updates.check()
            await updates.operation?.value
            updates.download()
            let operation = updates.operation
            scope.track(operation)
            try await preparation.started.wait()
            #expect(updates.closeWindow() && operation?.isCancelled == true)
            preparation.result.signal(provider.prepared)
            await operation?.value
            #expect(provider.performances == 0 && !updates.isBusy)
        }
    }

    @Test func closingWaitsForAnAlreadyStartedSystemHandoff() async throws {
        try await withNativeTestScope { scope in
            let provider = WindowUpdateProvider()
            provider.available = true
            let handoff: NativeTestRequest<Void> = scope.request("installer handoff")
            provider.handoffRequest = handoff
            let updates = AppUpdates(provider: provider)
            updates.check()
            await updates.operation?.value
            updates.download()
            scope.track(updates.operation)
            try await handoff.started.wait()
            #expect(!updates.closeWindow() && updates.phase == .opening)
            handoff.result.signal(())
            await updates.operation?.value
            #expect(updates.closeWindow() && provider.performances == 1)
        }
    }

    @Test func finishingCancellationInvalidatesTheBusyControls() async throws {
        try await withNativeTestScope { scope in
            let provider = WindowUpdateProvider()
            let check: NativeTestRequest<UpdateOffer?> = scope.request("update check")
            provider.checkRequest = check
            let updates = AppUpdates(provider: provider)
            updates.check()
            let operation = updates.operation
            scope.track(operation)
            try await check.started.wait()
            _ = updates.closeWindow()
            let changed = Mutex(false)
            withObservationTracking { _ = updates.isBusy } onChange: { changed.withLock { $0 = true } }
            check.result.signal(nil)
            await operation?.value
            #expect(!updates.isBusy && changed.withLock { $0 })
        }
    }
}

@MainActor private final class WindowUpdateProvider: UpdateProvider {
    var checks = 0
    var performances = 0
    var available = false
    var checkRequest: NativeTestRequest<UpdateOffer?>?
    var preparationRequest: NativeTestRequest<PreparedUpdate>?
    var handoffRequest: NativeTestRequest<Void>?
    let offer = UpdateOffer(id: "window", version: "1.2.0", installedVersion: "1.1.0", actionTitle: "Download", actionHelp: "Download the DMG and install it manually.", progressTitle: "Downloading PanePeek 1.2.0…")
    let prepared = PreparedUpdate(id: UUID(), title: "Installer opened", message: "Quit PanePeek, then drag PanePeek to Applications.", reopenTitle: "Open installer again")
    func check() async throws -> UpdateOffer? {
        checks += 1
        if let checkRequest { return try await checkRequest.value() }
        return available ? offer : nil
    }
    func prepare(_ offer: UpdateOffer, progress: @escaping @Sendable (Double?) -> Void) async throws -> PreparedUpdate {
        if let preparationRequest { return try await preparationRequest.value() }
        return prepared
    }
    func perform(_ update: PreparedUpdate) async throws {
        performances += 1
        if let handoffRequest { try await handoffRequest.value() }
    }
}

