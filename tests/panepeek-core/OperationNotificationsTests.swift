import Foundation
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1))) @MainActor
struct OperationNotificationsTests {
    @Test func successExpiresAfterFiveSecondsWithoutRemovingNewerResults() async throws {
        try await withOperationGates { first, second in
            var sleeps: [Duration] = []
            let state = OperationNotifications { duration in
                sleeps.append(duration)
                try await (sleeps.count == 1 ? first : second).pause()
            }
            let old = state.post("Copied 1 item.\nCompleted: /example/old", kind: .success)
            try await first.waitForRequest()
            let new = state.post("Moved 1 item.\nCompleted: /example/new", kind: .success)
            try await second.waitForRequest()
            #expect(sleeps == [.seconds(5), .seconds(5)])
            #expect(state.notices.map(\.id) == [new, old])
            try await first.finish()
            try await waitForState { !state.notices.contains { $0.id == old } }
            #expect(state.notices.map(\.id) == [new])
            try await second.finish()
            try await waitForState { state.notices.isEmpty }
            #expect(state.notices.isEmpty)
        }
    }

    @Test func progressBecomesPersistentFailureWithCompleteDetails() async {
        var sleeps = 0
        let state = OperationNotifications { _ in sleeps += 1 }
        let progress = state.post("Moving selected items…", kind: .progress)
        #expect(state.notices.first?.kind == .progress)
        let message = "Move stopped after 1 item.\nCompleted: /a\nFailed: /b\nUnattempted: /c\nPrevious destination: /recovery/old"
        state.finish(progress, message: message, succeeded: false)
        let failure = state.notices.first
        #expect(failure?.kind == .error && failure?.message == message)
        #expect(failure?.summary == "Move stopped after 1 item.")
        #expect(failure?.id != progress)
        let next = state.post("Copying selected items…", kind: .progress)
        state.dismiss(next)
        #expect(state.notices == [failure].compactMap { $0 })
        await Task.yield()
        #expect(sleeps == 0)
        if let failure { state.dismiss(failure.id) }
        #expect(state.notices.isEmpty)
    }

    @Test func dismissedSuccessTimerCannotRemoveFailureOrReplacement() async throws {
        try await withOperationGate { gate in
            let (finished, completion) = AsyncStream<Void>.makeStream()
            let state = OperationNotifications { _ in
                defer { completion.finish() }
                try await gate.pause()
            }
            let old = state.post("Copied 1 item.", kind: .success)
            try await gate.waitForRequest()
            state.dismiss(old)
            let error = state.post("Copy rejected. Existing path: /example/winner", kind: .error)
            try await gate.finish()
            for await _ in finished { }
            #expect(state.notices.map(\.id) == [error])
            #expect(state.notices.first?.kind == .error)
        }
    }

    @Test(arguments: ["copy", "move", "trash"], [false, true])
    func browserProgressReplacesOnlyItsOwnNotice(operation: String, batch: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("notice.txt")
        let sources = batch ? [source, try fixture.file("second.txt")] : [source]
        try await withOperationGate { gate in
            let browser = BrowserState(homeDirectory: fixture.source,
                copy: { item in
                    if item.source == source { try? await gate.pause() }
                    return await item.copy()
                }, move: { item in
                    if item.source == source { try? await gate.pause() }
                    return await item.move()
                }, trash: { item in
                    if item.source == source { try? await gate.pause() }
                    return await item.trash { url in
                        try FileManager.default.moveItem(at: url, to: fixture.root.appendingPathComponent("recycled-" + url.lastPathComponent))
                    }
                })
            try await fixture.prepare(browser, selecting: source)
            browser.select(Set(sources), in: .left, focusedItem: source)
            let retained = browser.notifications.post("Earlier failure. Retain /recovery/original", kind: .error)
            let task = Task {
                switch operation {
                case "copy": _ = await browser.copyToOtherPane(from: .left)
                case "move": _ = await browser.moveToOtherPane(from: .left)
                default: _ = await browser.moveToTrash()
                }
            }
            gate.track(task)
            try await gate.waitForRequest()
            #expect(browser.notifications.notices.map(\.kind) == [.progress, .error])
            try await gate.finish()
            await task.value
            #expect(browser.notifications.notices.map(\.kind) == [.success, .error])
            let action = operation == "copy" ? "copied" : (operation == "move" ? "moved" : "moved to Trash")
            #expect(browser.notifications.notices.first?.message == "\(batch ? "2 items" : "notice.txt") \(action).")
            #expect(browser.notifications.notices.last?.id == retained)
            #expect(browser.notifications.notices.last?.message.contains("/recovery/original") == true)
            for notice in browser.notifications.notices { browser.notifications.dismiss(notice.id) }
        }
    }

}
