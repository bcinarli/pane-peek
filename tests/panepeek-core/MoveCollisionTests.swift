import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor struct MoveCollisionTests {
    @Test(arguments: ["report.pdf", ".env", "name", "配置.json", "folder.v1", "Sample.app", "linked.txt"])
    func keepsBothWithTheFirstAvailableName(name: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        var source = try fixture.file(name)
        if name == "folder.v1" || name == "Sample.app" {
            try FileManager.default.removeItem(at: source)
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
            try Data("child".utf8).write(to: source.appendingPathComponent("child.txt"))
        } else if name == "linked.txt" {
            try FileManager.default.removeItem(at: source)
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: "missing")
        }
        source = try #require(try await DirectoryListing.read(fixture.source).entries.first { $0.name == name }?.url)
        let originalDestination = fixture.destination.appendingPathComponent(name)
        try Data("winner".utf8).write(to: originalDestination)
        let stem = name == "folder.v1" ? name : (source.pathExtension.isEmpty ? name : source.deletingPathExtension().lastPathComponent)
        let suffix = name == "folder.v1" || source.pathExtension.isEmpty ? "" : "." + source.pathExtension
        let occupied = fixture.destination.appendingPathComponent(stem + " (2)" + suffix)
        try FileManager.default.createSymbolicLink(atPath: occupied.path, withDestinationPath: "missing")
        let expectedName = stem + " (3)" + suffix
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveMoveCollision: { collision, answer in
            prompts += 1
            #expect(collision.source.path == source.path && collision.destination.path == originalDestination.path)
            #expect(collision.suggestedName == expectedName && collision.errorMessage == nil)
            answer(.keepBoth(collision.suggestedName))
            answer(.cancel)
        })
        browser.left.showHiddenFiles = true
        try await fixture.prepare(browser, selecting: source)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(prompts == 1 && result?.succeeded == true)
        let kept = fixture.destination.appendingPathComponent(expectedName)
        #expect(result?.completed.map(\.path) == [kept.path])
        #expect(try Data(contentsOf: originalDestination) == Data("winner".utf8))
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: occupied.path) == "missing")
        if name == "linked.txt" { #expect(try FileManager.default.destinationOfSymbolicLink(atPath: kept.path) == "missing") }
        else if name == "folder.v1" || name == "Sample.app" { #expect(try Data(contentsOf: kept.appendingPathComponent("child.txt")) == Data("child".utf8)) }
        else { #expect(try Data(contentsOf: kept) == Data("original".utf8)) }
        #expect(!browser.left.entries.contains { $0.url == source })
    }

    @Test func retriesInvalidOccupiedAndBatchReservedNamesBeforeMoving() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "a (2).txt"].map(fixture.file)
        try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("a.txt"))
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveMoveCollision: { collision, answer in
            #expect(collision.suggestedName == "a (3).txt")
            #expect((collision.errorMessage != nil) == (prompts > 0))
            #expect((try? FileManager.default.contentsOfDirectory(atPath: fixture.destination.path)) == ["a.txt"])
            let names = ["../escape.txt", "", "a.txt", "a (2).txt", "custom name ü.txt"]
            let name = names[min(prompts, names.count - 1)]
            prompts += 1
            answer(.keepBoth(name))
        })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select(Set(sources), in: .left)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(prompts == 5 && result?.succeeded == true)
        #expect(result?.completed.map(\.lastPathComponent) == ["a (2).txt", "custom name ü.txt"])
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("a.txt")) == Data("winner".utf8))
    }

    @Test func laterCollisionCancelAbortsTheWholeBatchBeforeDirtyChoices() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "z.txt"].map(fixture.file)
        for source in sources { try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent(source.lastPathComponent)) }
        var prompts = 0
        var dirtyPrompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveMoveCollision: { collision, answer in
            prompts += 1
            answer(prompts == 1 ? .keepBoth(collision.suggestedName) : .cancel)
        }, confirmChanges: { _, answer in dirtyPrompts += 1; answer(.discard) })
        try await fixture.prepare(browser, selecting: sources[1], dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: sources[1])
        #expect(await browser.moveToOtherPane(from: .left) == nil)
        #expect(prompts == 2 && dirtyPrompts == 0 && browser.preview.isDirty && browser.preview.canEdit)
        #expect(!browser.operations.isBusy)
        for source in sources { #expect(try Data(contentsOf: source) == Data("original".utf8)) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).count == 2)
    }

    @Test(arguments: [false, true])
    func pendingCollisionLocksForeignEditorsAndRetainsCapturedTargets(sourceReplaced: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("a.txt"))
        let coordinator = FileOperationCoordinator()
        var answer: (@MainActor (ItemMove.CollisionChoice) -> Void)?
        let browser = BrowserState(homeDirectory: fixture.source, operations: coordinator, resolveMoveCollision: { _, completion in answer = completion })
        let editor = BrowserState(homeDirectory: fixture.source, operations: coordinator)
        coordinator.register(editor)
        try await fixture.prepare(browser, selecting: source)
        try await fixture.prepare(editor, selecting: source)
        await editor.preview.load(editor.detailsSelection)
        editor.preview.setMode(.edit)
        #expect(editor.preview.canEdit)
        let moving = Task { await browser.moveToOtherPane(from: .left) }
        try await waitForMove { answer != nil }
        let completion = try #require(answer)
        defer { completion(.cancel) }
        #expect(!editor.preview.canEdit && !editor.canCreate() && !browser.canMove(in: .left))
        await browser.right.navigate(to: fixture.root)
        browser.setMode(.onePane)
        if sourceReplaced {
            try FileManager.default.moveItem(at: source, to: fixture.source.appendingPathComponent("preserved"))
            try Data("replacement".utf8).write(to: source)
        }
        completion(.keepBoth("a (2).txt"))
        let result = await moving.value
        #expect(result?.succeeded == !sourceReplaced)
        #expect(browser.right.directory == fixture.root && browser.mode == .onePane && !coordinator.isBusy)
        if sourceReplaced {
            #expect(result?.failed?.path == source.path && result?.completed.isEmpty == true)
            #expect(try Data(contentsOf: source) == Data("replacement".utf8))
            #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a (2).txt").path))
        } else { #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("a (2).txt")) == Data("original".utf8)) }
    }

    @Test func lateCollisionAfterDirtyChoiceRejectsBeforeTheFirstMoveAndRetainsDraft() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "z.txt"].map(fixture.file)
        try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("z.txt"))
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveMoveCollision: { collision, answer in
            prompts += 1; answer(.keepBoth(collision.suggestedName))
        }, confirmChanges: { _, answer in
            try? Data("late winner".utf8).write(to: fixture.destination.appendingPathComponent("z (2).txt"))
            answer(.discard)
        })
        try await fixture.prepare(browser, selecting: sources[1], dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: sources[1])
        let result = await browser.moveToOtherPane(from: .left)
        #expect(prompts == 1 && result?.succeeded == false && result?.completed.isEmpty == true)
        #expect(browser.preview.isDirty && browser.preview.text == "draft")
        #expect(try Data(contentsOf: sources[0]) == Data("original".utf8))
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("z (2).txt")) == Data("late winner".utf8))
    }
    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func incomingKeepBothProtectsSourceDraftAndRetainsTheExistingDestinationsDraft(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let destination = fixture.destination.appendingPathComponent("a.txt")
        try Data("winner".utf8).write(to: destination)
        let operations = FileOperationCoordinator()
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.destination, operations: operations,
            resolveMoveCollision: { collision, answer in answer(.keepBoth(collision.suggestedName)) })
        let editor = BrowserState(homeDirectory: fixture.source, operations: operations,
            confirmChanges: { _, answer in prompts += 1; answer(choice) })
        let existing = BrowserState(homeDirectory: fixture.destination, operations: operations,
            confirmChanges: { _, answer in Issue.record("Keep Both must retain the existing destination draft"); answer(.cancel) })
        operations.register(editor)
        operations.register(existing)
        try await fixture.prepare(editor, selecting: source, dirty: true)
        await existing.left.refresh()
        existing.select([destination], in: .left)
        await existing.preview.load(existing.detailsSelection)
        existing.preview.setMode(.edit)
        await existing.preview.updateText("existing draft")?.value
        await browser.left.refresh()
        await browser.submitDrop([source], into: .left, operation: .move)?.value
        #expect(prompts == 1 && existing.preview.isDirty && existing.preview.text == "existing draft")
        #expect(existing.preview.canEdit && existing.preview.selection?.item.url == destination)
        #expect(try Data(contentsOf: destination) == Data("winner".utf8))
        let kept = fixture.destination.appendingPathComponent("a (2).txt")
        if choice == .cancel {
            #expect(editor.preview.isDirty && browser.moveOutcome == nil)
            #expect(!FileManager.default.fileExists(atPath: kept.path))
        } else {
            #expect(browser.moveOutcome?.succeeded == true && editor.preview.selection == nil)
            #expect(try Data(contentsOf: kept) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test func numberedSuggestionFitsTheFilesystemNameLimit() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let name = String(repeating: "a", count: 251) + ".txt"
        let source = try fixture.file(name)
        let destination = fixture.destination.appendingPathComponent(name)
        try Data("winner".utf8).write(to: destination)
        let expected = String(repeating: "a", count: 247) + " (2).txt"
        let browser = BrowserState(homeDirectory: fixture.source, resolveMoveCollision: { collision, answer in
            #expect(collision.suggestedName == expected)
            answer(.keepBoth(collision.suggestedName))
        })
        try await fixture.prepare(browser, selecting: source)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == true && result?.completed.map(\.lastPathComponent) == [expected])
        #expect(try Data(contentsOf: destination) == Data("winner".utf8))
    }

    @Test(arguments: [false, true])
    func customExtensionKeepsCachedFolderClassificationCorrectWhenRefreshFails(package: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let name = package ? "Sample.app" : "Folder"
        let nameAfterMove = package ? "Kept folder" : "Kept.app"
        let source = fixture.source.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try Data("payload".utf8).write(to: source.appendingPathComponent("child.txt"))
        try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent(name))
        let moved = fixture.destination.appendingPathComponent(nameAfterMove, isDirectory: true)
        let browser = BrowserState(homeDirectory: fixture.source, load: { directory in
            if FileManager.default.fileExists(atPath: moved.path) { throw CocoaError(.fileReadNoPermission) }
            return try await DirectoryListing.read(directory)
        }, resolveMoveCollision: { _, answer in answer(.keepBoth(nameAfterMove)) })
        let listedSource = try #require(try await DirectoryListing.read(fixture.source).entries.first { $0.name == name }?.url)
        try await fixture.prepare(browser, selecting: listedSource)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == true && result?.message.contains("refresh") == true)
        let actual = try #require(browser.right.entries.first { $0.name == nameAfterMove })
        let expected = try #require(try await DirectoryListing.read(fixture.destination).entries.first { $0.name == nameAfterMove })
        #expect(actual.isPackage == expected.isPackage && actual.isDirectory == expected.isDirectory)
    }

}
