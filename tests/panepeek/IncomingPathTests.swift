import Foundation
import Testing
import PanePeekCore
@testable import PanePeek

@MainActor struct IncomingPathTests {
    @Test func replacingADirectoryLinkTargetInvalidatesThePreparedListing() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("folder", isDirectory: true)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        let destination = try await prepare(link)
        try FileManager.default.moveItem(at: folder, to: root.appendingPathComponent("retired"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        await #expect(throws: (any Error).self) { try await destination.validate() }
    }

    @Test func selectsActualCaseAndUnicodeNamesWithoutConfusingHardLinksOrAncestorLinks() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let file = directory.appendingPathComponent("Café.TXT")
        try Data("contents".utf8).write(to: file)
        let hardLink = directory.appendingPathComponent("other.txt")
        try FileManager.default.linkItem(at: file, to: hardLink)
        let ancestor = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: ancestor, withDestinationURL: directory)
        let spelling = (try directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])).volumeSupportsCaseSensitiveNames == true
            ? "Cafe\u{301}.TXT" : "cafe\u{301}.txt"
        let incoming = try await prepare(ancestor.appendingPathComponent(spelling))
        #expect(incoming.listing.directory == directory && incoming.selection == file)
        #expect(try await prepare(hardLink).selection == hardLink)
    }

    @Test func packagesAndFileLinksStaySelectedWhileDirectoryLinksBrowseTheirTarget() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false)
        let file = root.appendingPathComponent("document.txt")
        try Data().write(to: file)
        let link = root.appendingPathComponent("file-link")
        let dangling = root.appendingPathComponent("dangling")
        let folderLink = root.appendingPathComponent("folder-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        try FileManager.default.createSymbolicLink(at: dangling, withDestinationURL: root.appendingPathComponent("absent"))
        try FileManager.default.createSymbolicLink(at: folderLink, withDestinationURL: root)
        for selected in [package, link, dangling] {
            let result = try await prepare(selected)
            #expect(result.selection?.path == selected.path && result.listing.directory.path == root.path)
        }
        let browsed = try await prepare(folderLink)
        #expect(browsed.selection == nil && browsed.listing.directory.path == root.path)
        #expect(try await prepare(URL(fileURLWithPath: "/")).selection == nil)
    }

    @Test func fileOnlyDeliveryRequiresParentPermissionAndHonoursCancellation() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("document.txt")
        try Data("original".utf8).write(to: file)
        var choices = 0
        let access = FolderAccess(stop: { _ in })
        await #expect(throws: CancellationError.self) {
            _ = try await IncomingPath.prepare(file, access: access) { initial in
                #expect(initial.path == root.path)
                choices += 1
                return nil
            }
        }
        #expect(choices == 1)
    }

    @Test func replacementDuringADirtyDecisionCannotPublishTheCapturedDestination() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let draft = root.appendingPathComponent("draft.txt")
        let file = root.appendingPathComponent("incoming.txt")
        try Data("draft".utf8).write(to: draft)
        try Data("incoming".utf8).write(to: file)
        let preview = PreviewState()
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: root, preview: preview, confirmChanges: { _, completion in answer = completion })
        await browser.left.navigate(to: root)
        browser.select([draft], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("unsaved")?.value
        let destination = try await prepare(file)
        let revision = browser.left.listingRevision
        let request = browser.beginExternalOpen(in: .left)
        let opening = Task { await browser.openExternal(directory: root, selecting: destination.selection, in: .left, request: request) { _ in
            try await destination.validate()
            return destination.listing
        } }
        while answer == nil { await Task.yield() }
        try FileManager.default.moveItem(at: file, to: root.appendingPathComponent("moved.txt"))
        try Data("replacement".utf8).write(to: file)
        answer?(.discard)
        #expect(await opening.value == false)
        #expect(browser.left.listingRevision == revision && browser.left.selectedItems == [draft])
        #expect(browser.left.errorMessage != nil)
    }

    private func prepare(_ url: URL) async throws -> IncomingPath {
        try await IncomingPath.prepare(url, access: nil) { _ in Issue.record("Unexpected folder choice"); return nil }
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-incoming-" + UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
