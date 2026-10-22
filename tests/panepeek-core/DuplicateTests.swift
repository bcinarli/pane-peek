import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor struct DuplicateTests {
    @Test(arguments: [BrowserMode.onePane, .twoPanes])
    func duplicatesTheCapturedSelectionInItsOwnFolder(mode: BrowserMode) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("report.txt")
        let folder = try fixture.file("examples/child.txt").deletingLastPathComponent()
        _ = try fixture.file("report (2).txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        try await fixture.prepare(browser, selecting: file)
        browser.select([file, folder], in: .left)
        browser.setMode(mode)
        #expect(browser.canDuplicate(in: .left))
        let result = try #require(await browser.duplicate(from: .left, items: [file, folder]))
        #expect(result.succeeded && Set(result.completed.map(\.lastPathComponent)) == ["report (3).txt", "examples (2)"])
        #expect(try Data(contentsOf: fixture.source.appendingPathComponent("examples (2)/child.txt")) == Data("original".utf8))
        #expect(try Data(contentsOf: file) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        #expect(browser.left.selectedItems == [file, folder])
    }

    @Test func staleHiddenAndEmptySelectionsCannotDuplicate() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("first.txt")
        let second = try fixture.file("second.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        try await fixture.prepare(browser, selecting: first)
        browser.select([second], in: .left)
        #expect(await browser.duplicate(from: .left, items: [first]) == nil)
        browser.select([], in: .left)
        #expect(!browser.canDuplicate(in: .left))
        #expect(await browser.duplicate(from: .left) == nil)
        browser.setMode(.onePane)
        #expect(!browser.canDuplicate(in: .right))
        #expect(await browser.duplicate(from: .right) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.source.path).count == 2)
    }

    @Test func contextTargetingPreservesTheSelectionAndRejectsConflictingWork() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("first.txt")
        let second = try fixture.file("second.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        browser.select([first, second], in: .left)
        var result: ItemCopy.Outcome?
        browser.targetContextItem(first, in: .left) {
            let items = browser.left.selectedItems
            #expect(items == [first, second])
            Task { result = await browser.duplicate(from: .left, items: items) }
        }
        try await waitForMove { result != nil }
        #expect(result?.succeeded == true && result?.completed.count == 2)
        let reservation = try #require(browser.operations.beginOperation(for: browser))
        #expect(!browser.canDuplicate(in: .left))
        #expect(await browser.duplicate(from: .left) == nil)
        browser.operations.endOperation(reservation)
    }
}
