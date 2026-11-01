import Foundation
import Testing
@testable import PanePeek

@Suite(.serialized) @MainActor struct AppUpdatesTests {
    @Test func anotherProviderUsesTheSameCheckPrepareAndPerformBoundary() async throws {
        let provider = OtherUpdateProvider()
        let updates = AppUpdates(provider: provider)
        updates.check()
        await updates.operation?.value
        #expect(updates.offer?.actionTitle == "Get update")
        updates.download()
        await updates.operation?.value
        #expect(provider.checks == 1 && provider.preparations == 1 && provider.performances == 1)
        #expect(updates.completion?.title == "Update ready")
        updates.reopen()
        await updates.operation?.value
        #expect(provider.performances == 2 && provider.preparations == 1)
    }

    @Test func openingFailureRetriesThePreparedUpdateWithoutDownloadingAgain() async {
        let provider = OtherUpdateProvider()
        provider.failOpening = true
        let updates = AppUpdates(provider: provider)
        updates.check()
        await updates.operation?.value
        updates.download()
        await updates.operation?.value
        #expect(updates.errorMessage != nil && updates.completion == nil)
        provider.failOpening = false
        updates.retry()
        await updates.operation?.value
        #expect(updates.completion != nil && provider.preparations == 1 && provider.performances == 2)
    }

    @Test func cancelledOrObsoletePreparationCannotPerformOrPublish() async throws {
        try await withNativeTestScope { scope in
            let provider = OtherUpdateProvider()
            let preparation: NativeTestRequest<PreparedUpdate> = scope.request("obsolete installer preparation")
            provider.preparationRequest = preparation
            let updates = AppUpdates(provider: provider)
            updates.check()
            await updates.operation?.value
            updates.download()
            let cancelled = updates.operation
            scope.track(cancelled)
            try await preparation.started.wait()
            updates.check()
            #expect(provider.checks == 1)
            updates.cancel()
            preparation.result.signal(provider.prepared)
            await cancelled?.value
            #expect(provider.performances == 0 && updates.completion == nil)
            #expect(updates.offer != nil && !updates.isBusy)
        }
    }

    @Test func disabledCompositionCannotIssueRequests() {
        let updates = AppUpdates(provider: nil)
        updates.check()
        updates.download()
        #expect(!updates.isEnabled && updates.operation == nil)
    }
}

@MainActor private final class OtherUpdateProvider: UpdateProvider {
    var checks = 0
    var preparations = 0
    var performances = 0
    var failOpening = false
    var preparationRequest: NativeTestRequest<PreparedUpdate>?
    let prepared = PreparedUpdate(id: UUID(), title: "Update ready", message: "Continue in another application.", reopenTitle: "Continue")
    func check() async throws -> UpdateOffer? {
        checks += 1
        return UpdateOffer(id: "test", version: "2.0.0", installedVersion: "1.0.0", actionTitle: "Get update",
                           actionHelp: "Continue with the other provider.", progressTitle: "Preparing update…")
    }
    func prepare(_ offer: UpdateOffer, progress: @escaping @Sendable (Double?) -> Void) async throws -> PreparedUpdate {
        preparations += 1
        if let preparationRequest { return try await preparationRequest.value() }
        return prepared
    }
    func perform(_ update: PreparedUpdate) async throws {
        performances += 1
        if failOpening { throw UpdateError.opening }
    }
}
