import Foundation
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1)))
struct MetadataTests {
    @Test @MainActor func heldMetadataReadWaitsForItsController() async throws {
        try await withTestRequestGate(of: DirectoryEntry.self, returning: ItemMetadata.self) { gate in
            let details = DetailsState(read: { try await gate.request($0) })
            let pending = Task { await details.load(selection("held.txt")) }
            gate.track(pending)
            _ = try await gate.waitForRequest(0)
            // Delay the controller while the operation remains explicitly held.
            try await Task.sleep(for: .seconds(11))
            #expect(details.isLoading)
            try gate.finish(0, with: .success(ItemMetadata(type: "File", size: 42)))
            await pending.value
            #expect(details.metadata?.size == 42 && details.errorMessage == nil && !details.isLoading)
        }
    }

    @Test func permissionsIncludeSpecialBitsAndUnavailableModes() {
        for (mode, expected): (UInt16, String) in [
            (0o0644, "0644 · rw-r--r--"), (0o0755, "0755 · rwxr-xr-x"),
            (0o4755, "4755 · rwsr-xr-x"), (0o2640, "2640 · rw-r-S---"),
            (0o1700, "1700 · rwx-----T"), (0o7111, "7111 · --s--s--t")
        ] {
            #expect(ItemMetadata(permissions: mode).permissionsDescription == expected)
        }
        #expect(ItemMetadata().permissionsDescription == "Unavailable")
    }

    @Test func realMetadataDescribesTheItemAndLinksWithoutReadingTheirTargets() async throws {
        let fixture = try MetadataFixture()
        defer { fixture.remove() }
        let files = FileManager.default
        let file = fixture.root.appendingPathComponent("file.txt")
        try Data("five!".utf8).write(to: file)
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        try files.setAttributes([.posixPermissions: 0o640, .modificationDate: modified], ofItemAtPath: file.path)
        let metadata = try await ItemMetadata.read(DirectoryEntry(url: file, isDirectory: false))
        #expect(metadata.type == "File" && metadata.size == 5)
        #expect(metadata.permissionsDescription == "0640 · rw-r-----")
        #expect(metadata.modifiedDate == modified)
        #expect(metadata.createdDate != nil && metadata.owner != nil && metadata.group != nil)

        for (name, target) in [("relative-link", "file.txt"), ("broken-link", "missing.txt")] {
            let link = fixture.root.appendingPathComponent(name)
            try files.createSymbolicLink(atPath: link.path, withDestinationPath: target)
            let linkMetadata = try await ItemMetadata.read(DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: true))
            #expect(linkMetadata.type == "Symbolic link")
            #expect(linkMetadata.targetPath == target)
            #expect(linkMetadata.size == UInt64(target.utf8.count))
            #expect(linkMetadata.modifiedDate != modified)
        }
        for (name, package) in [("folder", false), ("Example.app", true)] {
            let directory = fixture.root.appendingPathComponent(name, isDirectory: true)
            try files.createDirectory(at: directory, withIntermediateDirectories: false)
            let info = try await ItemMetadata.read(DirectoryEntry(url: directory, isDirectory: !package, isPackage: package))
            #expect(info.type == (package ? "Package" : "Folder"))
            #expect(info.size == nil)
        }
        await #expect(throws: (any Error).self) {
            try await ItemMetadata.read(DirectoryEntry(url: fixture.root.appendingPathComponent("absent"), isDirectory: false))
        }
    }

    @Test(arguments: [false, true]) @MainActor
    func olderMetadataSuccessOrFailureCannotReplaceNewerSelection(olderFails: Bool) async throws {
        try await withTestRequestGate(of: DirectoryEntry.self, returning: ItemMetadata.self) { gate in
            let details = DetailsState(read: { try await gate.request($0) })
            let first = selection("first.txt")
            let second = selection("second.txt")
            let oldRead = Task { await details.load(first) }
            gate.track(oldRead)
            _ = try await gate.waitForRequest(0)
            let newRead = Task { await details.load(second) }
            gate.track(newRead)
            _ = try await gate.waitForRequest(1)
            try gate.finish(1, with: .success(ItemMetadata(type: "File", size: 22)))
            await newRead.value
            try gate.finish(0, with: olderFails ? .failure(CocoaError(.fileReadNoPermission))
                                                       : .success(ItemMetadata(type: "File", size: 11)))
            await oldRead.value
            #expect(details.selection == second)
            #expect(details.metadata?.size == 22)
            #expect(details.errorMessage == nil && !details.isLoading)
        }
    }

    @Test @MainActor func clearingSelectionAndFailedReadsNeverLeaveOldMetadata() async throws {
        try await withTestRequestGate(of: DirectoryEntry.self, returning: ItemMetadata.self) { gate in
            let details = DetailsState(read: { try await gate.request($0) })
            let read = Task { await details.load(selection("first.txt")) }
            gate.track(read)
            _ = try await gate.waitForRequest(0)
            await details.load(nil)
            try gate.finish(0, with: .success(ItemMetadata(type: "File", size: 11)))
            await read.value
            #expect(details.metadata == nil && details.selection == nil && !details.isLoading)

            let good = Task { await details.load(selection("second.txt")) }
            gate.track(good)
            _ = try await gate.waitForRequest(1)
            try gate.finish(1, with: .success(ItemMetadata(type: "File", size: 22)))
            await good.value
            let failing = Task { await details.load(selection("missing.txt")) }
            gate.track(failing)
            _ = try await gate.waitForRequest(2)
            #expect(details.metadata == nil && details.errorMessage == nil && details.isLoading)
            try gate.finish(2, with: .failure(CocoaError(.fileReadNoPermission)))
            await failing.value
            #expect(details.metadata == nil && details.errorMessage != nil && !details.isLoading)
        }
    }

    @Test @MainActor func cancelledReadCannotPublishAndRetryUsesTheSameSelection() async throws {
        try await withTestRequestGate(of: DirectoryEntry.self, returning: ItemMetadata.self) { gate in
            let details = DetailsState(read: { try await gate.request($0) })
            let item = selection("file.txt")
            let cancelled = Task { await details.load(item) }
            gate.track(cancelled)
            _ = try await gate.waitForRequest(0)
            cancelled.cancel()
            try gate.finish(0, with: .success(ItemMetadata(type: "File", size: 11)))
            await cancelled.value
            #expect(details.metadata == nil && details.errorMessage == nil && !details.isLoading)
            let retry = Task { await details.load(item) }
            gate.track(retry)
            _ = try await gate.waitForRequest(1)
            try gate.finish(1, with: .success(ItemMetadata(type: "File", size: 22)))
            await retry.value
            #expect(details.metadata?.size == 22)
        }
    }

    @Test @MainActor func refreshRereadsAnUnchangedPrimaryAndFocusUsesItsOwnPane() async throws {
        let fixture = try MetadataFixture()
        defer { fixture.remove() }
        let file = fixture.root.appendingPathComponent("file.txt")
        try Data("fixture".utf8).write(to: file)
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: fixture.root)
        await browser.right.navigate(to: fixture.root)
        browser.left.setSelection([file])
        browser.right.setSelection([file])
        let details = DetailsState()
        let initial = try #require(browser.detailsSelection)
        await details.load(initial)
        let entries = browser.left.entries
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        await browser.left.refresh()
        let refreshed = try #require(browser.detailsSelection)
        #expect(browser.left.entries == entries)
        #expect(refreshed != initial)
        #expect(refreshed.item.url == initial.item.url)
        await details.load(refreshed)
        #expect(details.metadata?.permissionsDescription == "0600 · rw-------")
        browser.focus(.right)
        #expect(browser.detailsSelection?.item.url == file)
        #expect(browser.detailsSelection != refreshed)
        browser.right.setSelection([])
        #expect(browser.detailsSelection == nil)
    }
}

private func selection(_ name: String) -> DetailsSelection {
    DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/metadata/\(name)"), isDirectory: false),
                     listingRevision: UUID())
}

private struct MetadataFixture {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-metadata-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
