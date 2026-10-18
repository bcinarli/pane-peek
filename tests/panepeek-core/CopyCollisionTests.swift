import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor struct CopyCollisionTests {
    @Test(arguments: [false, true])
    func copyResolvesDuplicatesAndKeepsItsSource(replace: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let sourceIdentity = try fixture.identity(source)
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { collision, answer in
            prompts += 1
            #expect(collision.operation == .copy && collision.canReplace && collision.suggestedName == "report (2).txt")
            answer(replace ? .replace : .keepBoth(collision.suggestedName))
        })
        try await fixture.prepare(browser, selecting: source)
        let result = await browser.copyToOtherPane(from: .left)
        let copied = fixture.destination.appendingPathComponent(replace ? "report.txt" : "report (2).txt")
        #expect(prompts == 1 && result?.succeeded == true)
        #expect((try? Data(contentsOf: copied)) == Data("original".utf8))
        #expect((try? fixture.identity(source)) == sourceIdentity)
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
        if !replace { #expect((try? Data(contentsOf: destination)) == Data("previous".utf8)) }
        #expect((try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path)).allSatisfy { !$0.hasPrefix(".panepeek-") })
    }

    @Test func cancellingTheLastCollisionCopiesNothing() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "z.txt"].map(fixture.file)
        try Data("previous".utf8).write(to: fixture.destination.appendingPathComponent("z.txt"))
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { _, answer in prompts += 1; answer(.cancel) })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select(Set(sources), in: .left)
        #expect(await browser.copyToOtherPane(from: .left) == nil)
        #expect(prompts == 1 && !browser.operations.isBusy)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path) == ["z.txt"])
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], [false, true])
    func replacementProtectsForeignDestinationDrafts(choice: BrowserState.UnsavedChoice, saveFails: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        let destination = fixture.destination.appendingPathComponent("draft.txt")
        try Data("previous".utf8).write(to: destination)
        let operations = FileOperationCoordinator()
        let browser = BrowserState(homeDirectory: fixture.source, operations: operations, resolveTransferCollision: { _, answer in answer(.replace) })
        var prompts = 0
        let preview = saveFails ? PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) }) : PreviewState()
        let editor = BrowserState(homeDirectory: fixture.destination, operations: operations, preview: preview,
            confirmChanges: { _, answer in prompts += 1; answer(choice) })
        operations.register(editor)
        try await fixture.prepare(browser, selecting: source)
        try await fixture.prepare(editor, selecting: destination, dirty: true)
        let result = await browser.copyToOtherPane(from: .left)
        #expect(prompts == 1 && !operations.isBusy)
        if choice == .cancel || (choice == .save && saveFails) {
            #expect(result == nil && editor.preview.isDirty)
            #expect((try? Data(contentsOf: destination)) == Data("previous".utf8))
        } else {
            #expect(result?.succeeded == true && editor.preview.selection == nil)
            #expect((try? Data(contentsOf: destination)) == Data("original".utf8))
        }
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
    }

    @Test(arguments: [false, true])
    func stagingFailureOrChangedDestinationPreservesBothFiles(lateChange: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            await operation.copy(using: { source, staging in
                try FileManager.default.copyItem(at: source, to: staging)
                if lateChange { try Data("late winner".utf8).write(to: destination) }
                else { throw POSIXError(.EACCES) }
            })
        }, resolveTransferCollision: { _, answer in answer(.replace) })
        try await fixture.prepare(browser, selecting: source)
        let result = await browser.copyToOtherPane(from: .left)
        #expect(result?.succeeded == false && result?.completed.isEmpty == true)
        #expect((try? Data(contentsOf: destination)) == Data((lateChange ? "late winner" : "previous").utf8))
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path) == ["report.txt"])
    }

    @Test(arguments: ["folder", "package", "link"])
    func keepBothCopiesNonReplaceableItems(kind: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let name = kind == "package" ? "Sample.app" : "sample"
        let source = fixture.source.appendingPathComponent(name, isDirectory: kind != "link")
        if kind == "link" { try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: "missing") }
        else { _ = try fixture.file(name + "/child.txt") }
        try Data("previous".utf8).write(to: fixture.destination.appendingPathComponent(name))
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { collision, answer in
            #expect(!collision.canReplace)
            answer(.keepBoth(collision.suggestedName))
        })
        await browser.left.refresh()
        let listed = try #require(browser.left.entries.first { $0.name == name }?.url)
        try await fixture.prepare(browser, selecting: listed)
        let result = await browser.copyToOtherPane(from: .left)
        let copied = try #require(result?.completed.first, "\(result?.message ?? "No copy outcome")")
        #expect(result?.succeeded == true && (try? fixture.identity(source)) != nil)
        #expect(copied.lastPathComponent == (kind == "package" ? "Sample (2).app" : "sample (2)"))
        if kind == "link" { #expect(try FileManager.default.destinationOfSymbolicLink(atPath: copied.path) == "missing") }
        else { #expect((try? Data(contentsOf: copied.appendingPathComponent("child.txt"))) == Data("original".utf8)) }
    }

    @Test func reservedNamesAndInvalidInputAreResolvedBeforeAnyCopy() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let reserved = try fixture.file("a (2).txt")
        try Data("previous".utf8).write(to: fixture.destination.appendingPathComponent("a.txt"))
        var choices = ["../bad", "a (2).txt", "custom.txt"]
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { collision, answer in
            #expect(collision.suggestedName == "a (3).txt")
            #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a (2).txt").path))
            answer(.keepBoth(choices.removeFirst()))
        })
        try await fixture.prepare(browser, selecting: first)
        browser.select([first, reserved], in: .left)
        #expect(await browser.copyToOtherPane(from: .left)?.succeeded == true)
        #expect(choices.isEmpty)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("custom.txt"))) == Data("original".utf8))
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("a.txt"))) == Data("previous".utf8))
    }

    @Test(arguments: [false, true])
    func publicationFailureRestoresOrRetainsThePreviousDestination(lateWinner: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let captured = try await ItemCopy.Batch.capture([source], to: fixture.destination, allowingCollisions: true)
        let resolved = try #require(try await captured.resolvingCollisions { _ in .replace })
        let item = try #require(resolved.items.first)
        let replacement = try #require(item.replacement)
        let result = await item.copyReplacing(replacement, using: { try FileManager.default.copyItem(at: $0, to: $1) }, publish: { _, target in
            if lateWinner { try Data("winner".utf8).write(to: target) }
            throw POSIXError(.EACCES)
        })
        #expect(!result.succeeded && result.replaced.isEmpty)
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
        #expect((try? Data(contentsOf: destination)) == Data((lateWinner ? "winner" : "previous").utf8))
        if lateWinner {
            let recovery = try #require(FileManager.default.contentsOfDirectory(at: fixture.destination, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix(".panepeek-replace-") })
            #expect((try? Data(contentsOf: recovery.appendingPathComponent("previous"))) == Data("previous".utf8))
            #expect(result.restored.isEmpty && result.message.contains(recovery.lastPathComponent))
        } else {
            #expect(result.restored == [destination])
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path) == ["report.txt"])
        }
    }
}
