import Foundation
import Testing
import PanePeekCore
@testable import PanePeek

@MainActor struct IncomingPathTests {
    @Test func launcherRevealSelectsDirectoriesAndNamedLinksInTheirParent() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("folder", isDirectory: true)
        let link = root.appendingPathComponent("folder-link")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        for item in [directory, link] {
            let request = LauncherRequest(path: item.path, intent: .reveal, requiresDirectory: true)
            let destination = try await IncomingPath.prepare(.launcher(request), access: nil) { _ in
                Issue.record("Unexpected folder choice"); return nil
            }
            #expect(destination.listing.directory.path == root.path && destination.selection?.path == item.path)
        }
        let rootRequest = LauncherRequest(path: "/", intent: .reveal)
        #expect(try await IncomingPath.prepare(.launcher(rootRequest), access: nil) { _ in nil }.selection == nil)
    }

    @Test func launcherDataCannotAdoptANativeDirectoryScope() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let access = FolderAccess(bookmarking: .init(start: { _ in true }), stop: { _ in })
        var choices = 0
        await #expect(throws: CancellationError.self) {
            _ = try await IncomingPath.prepare(.launcher(LauncherRequest(path: root.path, intent: .open)), access: access) { _ in
                choices += 1
                return nil
            }
        }
        #expect(choices == 1)
    }

    @Test func directoryRequirementIsCheckedAgainInTheApp() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file")
        try Data().write(to: file)
        let request = LauncherRequest(path: file.path, intent: .open, requiresDirectory: true)
        await #expect(throws: (any Error).self) {
            try await IncomingPath.prepare(.launcher(request), access: nil) { _ in nil }
        }
    }

    @Test func aRevealedDirectoryLinksTargetCannotChangeDuringTheDocumentGuard() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("folder", isDirectory: true)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        let request = LauncherRequest(path: link.path, intent: .reveal, requiresDirectory: true)
        let destination = try await IncomingPath.prepare(.launcher(request), access: nil) { _ in nil }
        try FileManager.default.moveItem(at: folder, to: root.appendingPathComponent("retired"))
        try Data().write(to: folder)
        await #expect(throws: (any Error).self) { try await destination.validate() }
    }

    @Test func launcherPathsDoNotLexicallyRemoveUnresolvedAncestorTraversal() {
        let path = "/a/directory-link/../file"
        #expect(IncomingRequest.launcher(LauncherRequest(path: path, intent: .open)).url.path == path)
    }

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
        let opening = Task { await browser.openExternal(directory: root, selecting: destination.selection, in: .left, request: request) { saved, refresh in
            try await destination.listingForOpen(after: saved, refresh: refresh, access: nil)
        } }
        while answer == nil { await Task.yield() }
        try FileManager.default.moveItem(at: file, to: root.appendingPathComponent("moved.txt"))
        try Data("replacement".utf8).write(to: file)
        answer?(.discard)
        guard case .failed = await opening.value else { Issue.record("Expected a destination validation failure"); return }
        #expect(browser.left.listingRevision == revision && browser.left.selectedItems == [draft])
        #expect(browser.left.errorMessage != nil)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func incomingOpenRechecksTheDestinationAfterSorting(replaceTarget: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let prior = root.appendingPathComponent("previous.txt")
        let folder = root.appendingPathComponent("destination", isDirectory: true)
        let file = folder.appendingPathComponent(".incoming.txt")
        try Data("previous".utf8).write(to: prior)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try Data("incoming".utf8).write(to: file)
        let destination = try await prepare(file)
        let sorting = AsyncStream<Void>.makeStream(), resume = AsyncStream<Void>.makeStream()
        defer { sorting.continuation.finish(); resume.continuation.finish() }
        let browser = BrowserState(homeDirectory: root, sortEntries: { entries, _, _ in
            if entries.contains(where: { $0.url == file }) {
                sorting.continuation.yield()
                for await _ in resume.stream { break }
            }
            return entries
        })
        await browser.left.navigate(to: root)
        try #require(browser.select([prior], in: .left))
        let revision = browser.left.listingRevision
        let request = browser.beginExternalOpen(in: .left)
        let opening = Task {
            await browser.openExternal(directory: destination.listing.directory, selecting: destination.selection, in: .left, request: request) { saved, refresh in
                try await destination.listingForOpen(after: saved, refresh: refresh, access: nil)
            }
        }
        defer { opening.cancel() }
        for await _ in sorting.stream { break }
        if replaceTarget {
            try FileManager.default.moveItem(at: file, to: folder.appendingPathComponent("moved.txt"))
            try Data("replacement".utf8).write(to: file)
        }
        resume.continuation.finish()
        let outcome = await opening.value
        if replaceTarget {
            if case .failed = outcome {} else { Issue.record("Expected a destination validation failure, got \(outcome)") }
            #expect(browser.left.listingRevision == revision)
            #expect(browser.left.selectedItems == [prior] && !browser.left.showHiddenFiles)
        } else {
            #expect(outcome == .opened)
            #expect(browser.left.selectedItems == [file] && browser.left.showHiddenFiles)
        }
    }

    @Test func aSheetAppearingDuringAnIncomingReadDefersPublication() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("incoming.txt")
        try Data("incoming".utf8).write(to: file)
        let destination = try await prepare(file)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.navigate(to: root)
        let request = browser.beginExternalOpen(in: .left)
        let gate = AsyncStream<Void>.makeStream()
        defer { gate.continuation.finish() }
        var hasSheet = false
        let opening = Task {
            await browser.openExternal(directory: root, selecting: destination.selection, in: .left,
                                       request: request, hasAttachedSheet: { hasSheet }) { saved, refresh in
                for await _ in gate.stream { break }
                return try await destination.listingForOpen(after: saved, refresh: refresh, access: nil)
            }
        }
        defer { opening.cancel() }
        let readDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !browser.left.isLoading && ContinuousClock.now < readDeadline { await Task.yield() }
        try #require(browser.left.isLoading)
        hasSheet = true
        gate.continuation.finish()
        let pauseDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while browser.left.isLoading && ContinuousClock.now < pauseDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!browser.left.isLoading && browser.left.selectedItems.isEmpty)
        hasSheet = false
        #expect(await opening.value == .opened)
        #expect(browser.left.selectedItems == [file])
    }

    enum RenameTiming: CaseIterable { case beforeOpen, duringRead, submittedDuringRead }

    @Test(arguments: RenameTiming.allCases)
    func incomingOpenResolvesRenameBeforePublishing(timing: RenameTiming) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.txt")
        let renamed = root.appendingPathComponent("renamed.txt")
        try Data("original".utf8).write(to: source)
        let destination = try await prepare(root)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.navigate(to: root)
        try #require(browser.select([source], in: .left))
        func editName() async throws {
            await browser.beginRename()
            try #require(browser.renameRequest != nil)
            browser.updateRenameName(renamed.lastPathComponent)
        }
        if timing == .beforeOpen { try await editName() }

        let gate = AsyncStream<Void>.makeStream()
        defer { gate.continuation.finish() }
        let request = browser.beginExternalOpen(in: .left)
        let opening = Task {
            await browser.openExternal(directory: root, selecting: nil, in: .left, request: request) { saved, refresh in
                if timing != .beforeOpen { for await _ in gate.stream { break } }
                return try await destination.listingForOpen(after: saved, refresh: refresh, access: nil)
            }
        }
        defer { opening.cancel() }
        if timing != .beforeOpen {
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while !browser.left.isLoading && ContinuousClock.now < deadline { await Task.yield() }
            try #require(browser.left.isLoading)
            try await editName()
            if timing == .submittedDuringRead {
                #expect(await browser.submitRename(named: renamed.lastPathComponent) == renamed)
            }
            gate.continuation.finish()
        }

        #expect(await opening.value == .opened)
        #expect(browser.left.directory.path == root.path && browser.renameRequest == nil)
        #expect(browser.left.entries.map(\.url) == [renamed])
        #expect(try String(contentsOf: renamed, encoding: .utf8) == "original")
        #expect(!FileManager.default.fileExists(atPath: source.path))
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
