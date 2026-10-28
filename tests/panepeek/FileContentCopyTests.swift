import AppKit
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct FileContentCopyTests {
    @Test(arguments: ["notes.txt", "code.swift", "notes.md", "page.html", "art.svg"])
    func copiesTheCompleteCurrentSourceInBothModesWithoutSaving(name: String) async throws {
        let source = "---\r\ntitle: Café 👀\r\n---\r\n\t# Source <tag>\r\n\r\n"
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(name)
        let bytes = Data([0xEF, 0xBB, 0xBF]) + Data(source.utf8)
        try bytes.write(to: file)
        let selection = selected(file)
        let preview = PreviewState()
        await preview.load(selection)
        let notices = OperationNotifications()
        let sidebar = DetailsSidebar(selection: selection, preview: preview, sizing: DetailsSizing(), notifications: notices)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        #expect(sidebar.canCopyFileContent)
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string)?.utf8.elementsEqual(source.utf8) == true)
        preview.setMode(.edit)
        let draft = source + "Unsaved source\r\n"
        await preview.updateText(draft)?.value
        try #require(preview.isDirty)
        let document = preview.documentID
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string)?.utf8.elementsEqual(draft.utf8) == true)
        #expect(preview.mode == .edit)
        await preview.setMode(.preview)?.value
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string)?.utf8.elementsEqual(draft.utf8) == true)
        #expect(preview.isDirty && preview.documentID == document && preview.mode == .preview)
        #expect(try Data(contentsOf: file) == bytes)
        #expect(notices.notices.count == 3 && notices.notices.allSatisfy { $0.kind == .success })
    }

    @Test func anEmptyBufferReplacesAFileCutClipboard() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("empty.txt")
        try Data().write(to: file)
        let selection = selected(file)
        let preview = PreviewState()
        await preview.load(selection)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        weak var retainedAccess: DirectoryAccess?
        do {
            let access = DirectoryAccess(root: root, release: {})
            retainedAccess = access
            FileClipboard.write([file], access: [access], to: board, cutting: true)
        }
        #expect(retainedAccess != nil)
        #expect(FileClipboard.sources(from: board) == [file])
        let sidebar = DetailsSidebar(selection: selection, preview: preview, sizing: DetailsSizing(), notifications: OperationNotifications())
        #expect(sidebar.canCopyFileContent)
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "")
        #expect(retainedAccess == nil)
        #expect(FileClipboard.sources(from: board) == nil)
        #expect(try Data(contentsOf: file).isEmpty)
    }

    @Test func readableTextCopiesWithoutRequestingWriteAccess() async throws {
        var prompts = 0
        let preview = PreviewState(acquireWriteAccess: { _ in prompts += 1; return nil }, read: { _ in .text("readable") })
        let selection = selected(URL(fileURLWithPath: "/copy-fixture/read-only.txt"))
        await preview.load(selection)
        let sidebar = DetailsSidebar(selection: selection, preview: preview, sizing: DetailsSizing(), notifications: OperationNotifications())
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        #expect(!preview.canEdit && sidebar.canCopyFileContent)
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "readable" && prompts == 0)
        #expect(preview.mode == .preview && !preview.isDirty)
    }

    @Test func loadingAndOtherSelectionsCannotCopyThePreviousDocument() async throws {
        let (reads, requests) = AsyncStream<CheckedContinuation<TextPreview, any Error>>.makeStream()
        defer { requests.finish() }
        var iterator = reads.makeAsyncIterator()
        let preview = PreviewState(read: { _ in try await withCheckedThrowingContinuation { requests.yield($0) } })
        let first = selected(URL(fileURLWithPath: "/copy-fixture/first.txt"))
        let second = selected(URL(fileURLWithPath: "/copy-fixture/second.txt"))
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("unchanged", forType: .string)
        let firstRead = Task { await preview.load(first) }
        let response = try #require(await iterator.next())
        let loading = DetailsSidebar(selection: first, preview: preview, sizing: DetailsSizing(), notifications: OperationNotifications())
        #expect(!loading.canCopyFileContent)
        loading.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "unchanged")
        response.resume(returning: .text("first"))
        await firstRead.value
        for selection in [nil, second] {
            let stale = DetailsSidebar(selection: selection, preview: preview, sizing: DetailsSizing(), notifications: OperationNotifications())
            #expect(!stale.canCopyFileContent)
            stale.copyFileContent(to: board)
            #expect(board.string(forType: .string) == "unchanged")
        }
        let nextRead = Task { await preview.load(second) }
        let nextResponse = try #require(await iterator.next())
        let current = DetailsSidebar(selection: second, preview: preview, sizing: DetailsSizing(), notifications: OperationNotifications())
        current.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "unchanged")
        nextResponse.resume(returning: .text("second"))
        await nextRead.value
        current.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "second")
        loading.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "second")
    }

    @Test(arguments: [TextPreview.UnavailableReason.folder, .package, .tooLarge, .binary, .invalidUTF8, .nonRegularFile, .symbolicLink])
    func unavailableTextCannotReplaceTheClipboard(reason: TextPreview.UnavailableReason) async {
        let preview = PreviewState(read: { _ in .unavailable(reason) })
        let selection = selected(URL(fileURLWithPath: "/copy-fixture/unavailable.txt"))
        await preview.load(selection)
        let notices = OperationNotifications()
        let sidebar = DetailsSidebar(selection: selection, preview: preview, sizing: DetailsSizing(), notifications: notices)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("unchanged", forType: .string)
        #expect(!sidebar.canCopyFileContent)
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string) == "unchanged" && notices.notices.isEmpty)
    }

    @Test func writeFailureIsReportedWithoutAFalseSuccess() async {
        let preview = PreviewState(read: { _ in .text("source") })
        let selection = selected(URL(fileURLWithPath: "/copy-fixture/notes.txt"))
        await preview.load(selection)
        let notices = OperationNotifications()
        let sidebar = DetailsSidebar(selection: selection, preview: preview, sizing: DetailsSizing(), notifications: notices)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        sidebar.copyFileContent(to: board, write: { _, _ in false })
        #expect(notices.notices.count == 1 && notices.notices.first?.kind == .error)
        #expect(preview.text == "source" && !preview.isDirty)
    }

    private func selected(_ file: URL) -> DetailsSelection {
        DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID())
    }

    private func folder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-content-copy-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
