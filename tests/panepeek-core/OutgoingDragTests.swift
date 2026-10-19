import Foundation
import Testing
@testable import PanePeekCore

@MainActor struct OutgoingDragTests {
    @Test func capturesDisplayedOrderAndLocksOnlyDraggedSources() async throws {
        let fixture = try DragFixture()
        defer { fixture.remove() }
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select(Set(browser.left.entries.map(\.url)), in: .left, focusedItem: fixture.file)
        await browser.preview.load(browser.detailsSelection)
        let expected = browser.left.entries.map(\.url)
        #expect(browser.beginDrag(in: .left, items: Set(expected)) == expected)
        #expect(browser.draggedSources == expected && browser.isDragging)
        #expect(!browser.preview.canEdit && !browser.canCopy(in: .left) && !browser.canRename() && !browser.canTrash() && !browser.canCreate())
        browser.beginCreation(.textFile)
        #expect(browser.creationRequest == nil)
        browser.endDrag()
        #expect(!browser.isDragging && browser.preview.canEdit && browser.canCreate())
        #expect(try String(contentsOf: fixture.file, encoding: .utf8) == "original")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.link.path) == "z.txt")
    }

    @Test func hiddenEmptyAndStaleNativeSetsCannotExportAPartialSelection() async throws {
        let fixture = try DragFixture()
        defer { fixture.remove() }
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        await browser.right.refresh()
        browser.select([fixture.file, fixture.link], in: .left)
        #expect(browser.beginDrag(in: .left, items: [fixture.file]) == nil)
        #expect(browser.beginDrag(in: .left, items: []) == nil)
        browser.setMode(.onePane)
        #expect(browser.beginDrag(in: .right, items: [fixture.file]) == nil)
        #expect(!browser.isDragging && browser.draggedSources.isEmpty)
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], ["file", "folder", "package"])
    func dirtyFileOrContainingContainerIsResolvedBeforeARepeatedGesture(choice: BrowserState.UnsavedChoice, kind: String) async throws {
        let fixture = try DragFixture()
        defer { fixture.remove() }
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in prompts += 1; answer(choice) })
        await browser.left.refresh()
        let dragged = kind == "file" ? fixture.file : (kind == "folder" ? fixture.folder : fixture.package)
        browser.select([dragged], in: .left)
        let edited = kind == "file" ? fixture.file : (kind == "folder" ? fixture.child : fixture.packageChild)
        await browser.preview.load(DetailsSelection(item: DirectoryEntry(url: edited, isDirectory: false), listingRevision: UUID()))
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        #expect(browser.beginDrag(in: .left, items: [dragged]) == nil)
        try await waitForState { !browser.operations.isBusy }
        #expect(prompts == 1 && !browser.isDragging && browser.draggedSources.isEmpty)
        #expect(browser.dragNotice != nil)
        if choice == .cancel {
            #expect(browser.preview.isDirty && browser.preview.text == "draft")
        } else {
            try await waitForState { !browser.preview.isDirty && !browser.preview.isSaving }
            #expect(browser.beginDrag(in: .left, items: [dragged]) == [dragged])
            #expect(prompts == 1)
            #expect(try String(contentsOf: edited, encoding: .utf8) == (choice == .save ? "draft" : "original"))
            browser.endDrag()
        }
    }

    @Test(arguments: [false, true])
    func failedSaveExportsNothingAndRetainsTheDraft(slowSave: Bool) async throws {
        let fixture = try DragFixture()
        defer { fixture.remove() }
        let preview = PreviewState(write: { snapshot, text, url in
            if slowSave { try await Task.sleep(for: .seconds(6)) }
            return try await snapshot.save(text, to: url)
        })
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        browser.select([fixture.file], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        try Data("external".utf8).write(to: fixture.file)
        #expect(browser.beginDrag(in: .left, items: [fixture.file]) == nil)
        try await waitForState { browser.preview.errorMessage != nil }
        #expect(browser.preview.isDirty && browser.preview.text == "draft")
        #expect(!browser.isDragging && browser.draggedSources.isEmpty)
        #expect(try String(contentsOf: fixture.file, encoding: .utf8) == "external")
    }

    @Test func aListedLinkDoesNotDiscardItsTargetsDirtyBuffer() async throws {
        let fixture = try DragFixture()
        defer { fixture.remove() }
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        browser.select([fixture.link], in: .left)
        await browser.preview.load(DetailsSelection(item: DirectoryEntry(url: fixture.file, isDirectory: false), listingRevision: UUID()))
        browser.preview.setMode(.edit)
        await browser.preview.updateText("unrelated draft")?.value
        #expect(browser.beginDrag(in: .left, items: [fixture.link]) == [fixture.link])
        #expect(prompts == 0 && browser.preview.isDirty && browser.preview.canEdit)
        browser.endDrag(external: true)
        #expect(browser.dragNotice != nil && !browser.isDragging)
        #expect(browser.preview.text == "unrelated draft")
    }

    @Test(arguments: [BrowserState.DropOperation.copy, .move])
    func capturedSelectionCanDropIntoTheOtherPaneWhileTheSourceIsLocked(operation: BrowserState.DropOperation) async throws {
        let fixture = try DragFixture()
        defer { fixture.remove() }
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        let sources = browser.left.entries.map(\.url)
        browser.select(Set(sources), in: .left)
        let exported = try #require(browser.beginDrag(in: .left, items: Set(sources)))
        let task = browser.submitDrop(exported, into: .right, operation: operation)
        #expect(task != nil)
        browser.endDrag(external: true)
        #expect(browser.dragNotice == nil)
        await task?.value
        if operation == .copy { #expect(browser.copyOutcome?.succeeded == true) }
        else { #expect(browser.moveOutcome?.succeeded == true) }
        #expect(browser.right.entries.count == sources.count)
        #expect(!browser.isDragging)
    }
}

private struct DragFixture {
    let root: URL
    let source: URL
    let destination: URL
    let file: URL
    let folder: URL
    let child: URL
    let package: URL
    let packageChild: URL
    let link: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-outgoing-\(UUID())")
        source = root.appendingPathComponent("source")
        destination = root.appendingPathComponent("destination")
        file = source.appendingPathComponent("z.txt")
        folder = source.appendingPathComponent("folder", isDirectory: true)
        child = folder.appendingPathComponent("child.txt")
        package = source.appendingPathComponent("Sample.app")
        packageChild = package.appendingPathComponent("Contents/child.txt")
        link = source.appendingPathComponent("a-link")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packageChild.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("original".utf8).write(to: file)
        try Data("original".utf8).write(to: child)
        try Data("original".utf8).write(to: packageChild)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "z.txt")
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
