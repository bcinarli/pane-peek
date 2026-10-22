import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor struct SameFolderCopyTests {
    @Test(arguments: [false, true])
    func copiesThroughEitherReceivingRouteAndAnAliasedFolder(otherPane: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let occupied = try fixture.file("report (2).txt")
        let identity = try fixture.identity(source)
        let alias = fixture.root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.source)
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { _, answer in
            Issue.record("Same-folder copies must not ask for a name")
            answer(.cancel)
        })
        await browser.left.refresh()
        await browser.right.navigate(to: alias)
        browser.select([source], in: .left)
        if !otherPane { browser.setMode(.onePane) }
        for number in [3, 4] {
            if otherPane { _ = await browser.copyToOtherPane(from: .left) }
            else { await browser.submitDrop([source], into: .left, operation: .copy)?.value }
            try #require(browser.copyOutcome?.succeeded == true)
            #expect(browser.copyOutcome?.completed.map(\.lastPathComponent) == ["report (\(number)).txt"])
            #expect(try Data(contentsOf: fixture.source.appendingPathComponent("report (\(number)).txt")) == Data("original".utf8))
        }
        #expect(try fixture.identity(source) == identity)
        #expect(try Data(contentsOf: occupied) == Data("original".utf8))
        #expect(browser.left.selectedItems == [source])
    }

    @Test func batchPreservesFoldersPackagesAndListedLinks() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("report.txt")
        let folder = try fixture.file("folder/child.txt").deletingLastPathComponent()
        let package = try fixture.file("Sample.app/child.txt").deletingLastPathComponent()
        let link = fixture.source.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "missing")
        _ = try fixture.file("report (2).txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        let sources = [file, folder, package, link]
        await browser.submitDrop(sources, into: .left, operation: .copy)?.value
        try #require(browser.copyOutcome?.succeeded == true)
        let completed = try #require(browser.copyOutcome).completed
        #expect(completed.count == sources.count)
        #expect(Set(completed.map(\.lastPathComponent)) == ["report (3).txt", "folder (2)", "Sample (2).app", "link (2)"])
        for name in ["folder (2)", "Sample (2).app"] {
            #expect(try Data(contentsOf: fixture.source.appendingPathComponent(name + "/child.txt")) == Data("original".utf8))
        }
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.source.appendingPathComponent("link (2)").path) == "missing")
        #expect(sources.allSatisfy { (try? fixture.identity($0)) != nil })
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func dirtySourceStillRequiresAChoiceBeforeCopying(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in
            prompts += 1
            #expect(!FileManager.default.fileExists(atPath: fixture.source.appendingPathComponent("draft (2).txt").path))
            answer(choice)
        })
        await browser.left.refresh()
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.submitDrop([source], into: .left, operation: .copy)?.value
        #expect(prompts == 1)
        let destination = fixture.source.appendingPathComponent("draft (2).txt")
        if choice == .cancel {
            #expect(browser.copyOutcome == nil && browser.preview.isDirty)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        } else {
            #expect(browser.copyOutcome?.succeeded == true)
            #expect((try? Data(contentsOf: destination)) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test func lateCollisionReportsPartialOutcomeWithoutOverwriting() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        let last = try fixture.file("c.txt")
        let winner = fixture.source.appendingPathComponent("b (2).txt")
        let browser = BrowserState(homeDirectory: fixture.source, copy: { item in
            if item.source == first { try? Data("late winner".utf8).write(to: winner) }
            return await item.copy()
        })
        await browser.left.refresh()
        await browser.submitDrop([first, second, last], into: .left, operation: .copy)?.value
        let result = try #require(browser.copyOutcome)
        #expect(!result.succeeded && result.completed.map(\.lastPathComponent) == ["a (2).txt"])
        #expect(result.failed == second && result.unattempted == [last])
        #expect(try Data(contentsOf: winner) == Data("late winner".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.source.appendingPathComponent("c (2).txt").path))
        for source in [first, second, last] { #expect(try Data(contentsOf: source) == Data("original".utf8)) }
    }

    @Test func aLateWinnerDuringDirtyReviewRejectsTheWholeScopedBatch() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        let other = try fixture.file("other.txt")
        let winner = fixture.source.appendingPathComponent("draft (2).txt")
        var requested: [DirectoryAccess.Mode] = []
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, requiresFolderAccess: true,
            acquireOperationAccess: { directory, mode in
                requested.append(mode)
                return DirectoryAccess(root: directory, mode: mode) {}
            }, load: { directory in
                let listing = try await DirectoryListing.read(directory, followingLinks: false)
                return DirectoryListing(directory: directory, entries: listing.entries, access: DirectoryAccess(root: directory, mode: .readWrite) {})
            }, preview: PreviewState(), confirmChanges: { _, answer in
                prompts += 1
                try? Data("late winner".utf8).write(to: winner)
                answer(.discard)
            })
        await browser.left.refresh()
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        try #require(browser.preview.isDirty)
        await browser.submitDrop([source, other], into: .left, operation: .copy)?.value
        #expect(prompts == 1 && requested.contains(.readOnly) && requested.contains(.readWrite))
        let result = try #require(browser.copyOutcome)
        #expect(!result.succeeded && result.completed.isEmpty)
        #expect(result.failed == source && result.unattempted == [other])
        #expect(try Data(contentsOf: winner) == Data("late winner".utf8))
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.source.appendingPathComponent("other (2).txt").path))
    }
}
