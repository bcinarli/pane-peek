import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

@MainActor struct ScopedEditingTests {
    @Test func editingUpgradesAccessBeforeChangingTheDraftAndUsesAtomicSave() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = DirectoryEntry(url: root.appendingPathComponent("notes.txt"), isDirectory: false)
        var requests = 0
        let state = PreviewState(acquireWriteAccess: { selection in
            requests += 1
            #expect(selection.item == item)
            return DirectoryAccess(root: root, mode: .readWrite) {}
        })
        await state.load(selection(item, mode: .readOnly))
        #expect(state.canBeginEditing && !state.canEdit && !state.followsLinks)
        await state.updateText("must not edit")?.value
        #expect(state.text == "original" && !state.isDirty)
        await state.setMode(.edit)?.value
        #expect(state.canEdit && state.mode == .edit && requests == 1)
        await state.updateText("saved draft")?.value
        #expect(await state.save())
        #expect(try String(contentsOf: item.url, encoding: .utf8) == "saved draft")
        #expect(!state.isDirty && state.selection?.access?.mode == .readWrite)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["notes.txt"])
    }

    @Test(arguments: [false, true])
    func insufficientOrUnrelatedGrantsCannotEnableEditing(unrelated: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = DirectoryEntry(url: root.appendingPathComponent("notes.txt"), isDirectory: false)
        let state = PreviewState(acquireWriteAccess: { _ in
            DirectoryAccess(root: unrelated ? root.appendingPathComponent("elsewhere") : root,
                            mode: unrelated ? .readWrite : .readOnly) {}
        })
        await state.load(selection(item, mode: .readOnly))
        await state.setMode(.edit)?.value
        #expect(state.mode == .preview && !state.canEdit && !state.isRequestingWriteAccess)
        #expect(state.errorMessage != nil && state.text == "original")
    }

    @Test(.timeLimit(.minutes(1)))
    func supersededPermissionRequestRetainsItsReaderUntilCompletionAndCannotRedirectEditing() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = DirectoryEntry(url: root.appendingPathComponent("notes.txt"), isDirectory: false)
        let second = DirectoryEntry(url: root.appendingPathComponent("other.txt"), isDirectory: false)
        try Data("other".utf8).write(to: second.url)
        let released = Mutex(0)
        let (requests, request) = AsyncStream<CheckedContinuation<DirectoryAccess?, any Error>>.makeStream()
        defer { request.finish() }
        let state = PreviewState(acquireWriteAccess: { _ in
            try await withCheckedThrowingContinuation { request.yield($0) }
        })
        await state.load(DetailsSelection(item: first, listingRevision: UUID(), access: DirectoryAccess(root: root) {
            released.withLock { $0 += 1 }
        }))
        let pending = try #require(state.setMode(.edit))
        var iterator = requests.makeAsyncIterator()
        let response = try #require(await iterator.next())
        await state.load(selection(second, mode: .readOnly))
        #expect(released.withLock { $0 } == 0)
        response.resume(returning: DirectoryAccess(root: root, mode: .readWrite) {})
        await pending.value
        #expect(released.withLock { $0 } == 1)
        #expect(state.selection?.item == second && state.text == "other" && state.mode == .preview)
        #expect(!state.canEdit && !state.isRequestingWriteAccess && state.errorMessage == nil)
    }

    @Test func cancelKeepsTheReadOnlyDocumentAndAnExistingWriteGrantNeedsNoChooser() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = DirectoryEntry(url: root.appendingPathComponent("notes.txt"), isDirectory: false)
        var requests = 0
        let state = PreviewState(acquireWriteAccess: { _ in requests += 1; return nil })
        await state.load(selection(item, mode: .readOnly))
        await state.setMode(.edit)?.value
        #expect(state.mode == .preview && state.text == "original" && state.errorMessage == nil)
        await state.load(selection(item, mode: .readWrite))
        await state.setMode(.edit)?.value
        #expect(state.mode == .edit && state.canEdit && requests == 1)
    }

    @Test func externalChangesDuringPermissionSelectionStillRejectAnObsoleteSave() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = DirectoryEntry(url: root.appendingPathComponent("notes.txt"), isDirectory: false)
        let state = PreviewState(acquireWriteAccess: { _ in
            try Data("external".utf8).write(to: item.url)
            return DirectoryAccess(root: root, mode: .readWrite) {}
        })
        await state.load(selection(item, mode: .readOnly))
        await state.setMode(.edit)?.value
        await state.updateText("draft")?.value
        #expect(!(await state.save()))
        #expect(state.isDirty && state.text == "draft" && state.errorMessage != nil)
        #expect(try String(contentsOf: item.url, encoding: .utf8) == "external")
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-scoped-editing-" + UUID().uuidString, isDirectory: true).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try Data("original".utf8).write(to: root.appendingPathComponent("notes.txt"))
        return root
    }

    private func selection(_ item: DirectoryEntry, mode: DirectoryAccess.Mode) -> DetailsSelection {
        DetailsSelection(item: item, listingRevision: UUID(), access: DirectoryAccess(root: item.url.deletingLastPathComponent(), mode: mode) {})
    }
}
