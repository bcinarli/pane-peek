import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct SaveTests {
    @Test @MainActor func pendingSaveProtectsDraftAndKeepsSameFileSelectionCurrent() async throws {
        let fixture = try SaveFixture()
        defer { fixture.remove() }
        let item = try fixture.write("first.txt", bytes: Data("original".utf8))
        let gate = SaveGate()
        let state = PreviewState(write: { snapshot, text, url in
            await gate.hold()
            return try await snapshot.save(text, to: url)
        })
        await state.load(fixture.selection(item))
        state.setMode(.edit)
        await state.updateText("draft")?.value
        let document = state.documentID
        let revision = state.saveRevision
        let saving = Task { await state.save() }
        try await gate.waitUntilEntered()
        #expect(state.isSaving && !state.canEdit)
        #expect(!(await state.save()))
        await state.updateText("rejected")?.value
        state.discardChanges()
        let sameFile = fixture.selection(item)
        await state.load(sameFile)
        #expect(state.selection == sameFile)
        await state.load(nil)
        let browser = BrowserState(preview: state)
        #expect(!browser.resolveChangesIfNeeded())
        #expect(state.text == "draft" && state.documentID == document && state.isDirty)
        await gate.release()
        #expect(await saving.value)
        #expect(!state.isSaving && !state.isDirty && state.documentID == document)
        #expect(state.saveRevision != revision)
        #expect(try Data(contentsOf: item.url) == Data("draft".utf8))
    }

    @Test(arguments: [false, true]) @MainActor
    func savePromptResumesCapturedContextOnlyOnSuccess(conflict: Bool) async throws {
        let fixture = try SaveFixture()
        defer { fixture.remove() }
        let first = try fixture.write("first.txt", bytes: Data("original".utf8))
        let second = try fixture.write("second.txt", bytes: Data("second".utf8))
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let state = PreviewState()
        let browser = BrowserState(homeDirectory: fixture.root,
            load: { DirectoryListing(directory: $0, entries: [first, second]) },
            preview: state, confirmChanges: { _, completion in answer = completion })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([first.url])
        await state.load(browser.detailsSelection)
        state.setMode(.edit)
        await state.updateText("draft")?.value
        if conflict { try Data("external".utf8).write(to: first.url) }
        var resumed = 0
        let accepted = browser.targetContextItem(second.url, in: .right, then: { resumed += 1 })
        #expect(!accepted)
        let completion = try #require(answer)
        completion(.save)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while state.isDirty && state.errorMessage == nil && clock.now < deadline { await Task.yield() }
        #expect(conflict ? state.errorMessage != nil : !state.isDirty)
        #expect(state.text == "draft" && state.isDirty == conflict)
        #expect(resumed == (conflict ? 0 : 1))
        #expect(browser.focusedPane == (conflict ? .left : .right))
        #expect(browser.right.selectedItems == (conflict ? [] : [second.url]))
        #expect(try Data(contentsOf: first.url) == Data((conflict ? "external" : "draft").utf8))
        completion(.save)
        await Task.yield()
        #expect(resumed == (conflict ? 0 : 1))
    }

    @Test(arguments: [false, true]) @MainActor
    func explicitSavePreservesBytesPermissionsAndAdvancesBaseline(bom: Bool) async throws {
        let fixture = try SaveFixture()
        defer { fixture.remove() }
        let prefix = bom ? Data([0xEF, 0xBB, 0xBF]) : Data()
        let original = "Café 👀\r\nsecond\nlast\r"
        let item = try fixture.write("sample.txt", bytes: prefix + Data(original.utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: item.url.path)
        let openFile = try FileHandle(forReadingFrom: item.url)
        defer { try? openFile.close() }
        let state = PreviewState()
        await state.load(fixture.selection(item))
        state.setMode(.edit)
        let draft = original + "é\n"
        await state.updateText(draft)?.value
        let document = state.documentID
        state.setMode(.preview)
        let saved = await state.save()
        #expect(saved && !state.isDirty && state.errorMessage == nil)
        #expect(state.mode == .preview && state.text?.utf8.elementsEqual(draft.utf8) == true)
        #expect(state.documentID == document)
        #expect(try Data(contentsOf: item.url) == prefix + Data(draft.utf8))
        #expect(try openFile.readToEnd() == prefix + Data(original.utf8))
        #expect(try FileManager.default.attributesOfItem(atPath: item.url.path)[.posixPermissions] as? Int == 0o640)
        state.setMode(.edit)
        await state.updateText(draft + "again")?.value
        #expect(await state.save())
        await state.updateText("unsaved")?.value
        state.discardChanges()
        #expect(state.text == draft + "again" && !state.isDirty)
    }

    @Test(arguments: ["modified", "replaced", "deleted", "link", "fifo"]) @MainActor
    func externalChangesNeverOverwriteOrEraseDraft(change: String) async throws {
        let fixture = try SaveFixture()
        defer { fixture.remove() }
        let bytes = Data("original".utf8)
        let item = try fixture.write("source.txt", bytes: bytes)
        let state = PreviewState()
        await state.load(fixture.selection(item))
        state.setMode(.edit)
        await state.updateText("draft")?.value
        switch change {
        case "modified": try Data("external".utf8).write(to: item.url)
        case "replaced": try bytes.write(to: item.url, options: .atomic)
        case "deleted": try FileManager.default.moveItem(at: item.url, to: fixture.root.appendingPathComponent("moved"))
        case "link":
            try FileManager.default.moveItem(at: item.url, to: fixture.root.appendingPathComponent("target"))
            try FileManager.default.createSymbolicLink(atPath: item.url.path, withDestinationPath: "target")
        default:
            try FileManager.default.moveItem(at: item.url, to: fixture.root.appendingPathComponent("target"))
            try #require(mkfifo(item.url.path, 0o600) == 0)
        }
        let saved = await state.save()
        #expect(!saved && state.isDirty && state.text == "draft")
        #expect(state.errorMessage != nil)
        if change == "modified" { #expect(try Data(contentsOf: item.url) == Data("external".utf8)) }
        if change == "replaced" || change == "link" { #expect(try Data(contentsOf: item.url) == bytes) }
        if change == "deleted" { #expect(!FileManager.default.fileExists(atPath: item.url.path)) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).allSatisfy { !$0.hasPrefix(".panepeek-save-") })
    }

    @Test(arguments: [false, true]) @MainActor
    func permissionFailuresRetainDraftAndOriginalFile(directoryDenied: Bool) async throws {
        let fixture = try SaveFixture()
        defer { fixture.remove() }
        let bytes = Data("original".utf8)
        let item = try fixture.write("source.txt", bytes: bytes)
        let denied = directoryDenied ? fixture.root : item.url
        try FileManager.default.setAttributes([.posixPermissions: directoryDenied ? 0o500 : 0o400], ofItemAtPath: denied.path)
        let state = PreviewState()
        await state.load(fixture.selection(item))
        state.setMode(.edit)
        await state.updateText("draft")?.value
        #expect(!(await state.save()))
        #expect(state.isDirty && state.text == "draft" && state.errorMessage != nil)
        #expect(try Data(contentsOf: item.url) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["source.txt"])
    }

    @Test @MainActor func finalByteLimitIncludesRetainedBOM() async throws {
        let fixture = try SaveFixture()
        defer { fixture.remove() }
        let item = try fixture.write("bom.txt", bytes: Data([0xEF, 0xBB, 0xBF]))
        let state = PreviewState(highlight: { _, _ in [] })
        await state.load(fixture.selection(item))
        state.setMode(.edit)
        await state.updateText(String(repeating: "a", count: TextPreview.maximumBytes - 2))?.value
        #expect(!(await state.save()) && state.isDirty)
        #expect(state.errorMessage != nil)
        #expect(try Data(contentsOf: item.url) == Data([0xEF, 0xBB, 0xBF]))
        await state.updateText(String(repeating: "a", count: TextPreview.maximumBytes - 3))?.value
        #expect(await state.save())
        #expect(try Data(contentsOf: item.url).count == TextPreview.maximumBytes)
    }
}

private struct SaveFixture {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-save-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func write(_ name: String, bytes: Data) throws -> DirectoryEntry {
        let url = root.appendingPathComponent(name)
        try bytes.write(to: url)
        return DirectoryEntry(url: url, isDirectory: false)
    }
    func selection(_ item: DirectoryEntry) -> DetailsSelection {
        DetailsSelection(item: item, listingRevision: UUID())
    }
    func remove() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }
}

private actor SaveGate {
    private enum GateError: Error { case writeDidNotBeginWithinFiveSeconds }
    private var continuation: CheckedContinuation<Void, Never>?
    func hold() async {
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilEntered() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while continuation == nil {
            guard clock.now < deadline else { throw GateError.writeDidNotBeginWithinFiveSeconds }
            await Task.yield()
        }
    }
    func release() {
        continuation?.resume()
        continuation = nil
    }
}
