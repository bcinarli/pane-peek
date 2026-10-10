import Foundation
import Testing
@testable import PanePeekCore

struct MetadataTests {
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
        let gate = MetadataGate()
        let details = DetailsState(read: { try await gate.read($0) })
        let first = selection("first.txt")
        let second = selection("second.txt")
        let oldRead = Task { await details.load(first) }
        try await gate.waitForRequest(0)
        let newRead = Task { await details.load(second) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(ItemMetadata(type: "File", size: 22)))
        await newRead.value
        try await gate.finish(0, result: olderFails ? .failure(CocoaError(.fileReadNoPermission))
                                                   : .success(ItemMetadata(type: "File", size: 11)))
        await oldRead.value
        #expect(details.selection == second)
        #expect(details.metadata?.size == 22)
        #expect(details.errorMessage == nil && !details.isLoading)
    }

    @Test @MainActor func clearingSelectionAndFailedReadsNeverLeaveOldMetadata() async throws {
        let gate = MetadataGate()
        let details = DetailsState(read: { try await gate.read($0) })
        let read = Task { await details.load(selection("first.txt")) }
        try await gate.waitForRequest(0)
        await details.load(nil)
        try await gate.finish(0, result: .success(ItemMetadata(type: "File", size: 11)))
        await read.value
        #expect(details.metadata == nil && details.selection == nil && !details.isLoading)

        let good = Task { await details.load(selection("second.txt")) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(ItemMetadata(type: "File", size: 22)))
        await good.value
        let failing = Task { await details.load(selection("missing.txt")) }
        try await gate.waitForRequest(2)
        #expect(details.metadata == nil && details.errorMessage == nil && details.isLoading)
        try await gate.finish(2, result: .failure(CocoaError(.fileReadNoPermission)))
        await failing.value
        #expect(details.metadata == nil && details.errorMessage != nil && !details.isLoading)
    }

    @Test @MainActor func cancelledReadCannotPublishAndRetryUsesTheSameSelection() async throws {
        let gate = MetadataGate()
        let details = DetailsState(read: { try await gate.read($0) })
        let item = selection("file.txt")
        let cancelled = Task { await details.load(item) }
        try await gate.waitForRequest(0)
        cancelled.cancel()
        try await gate.finish(0, result: .success(ItemMetadata(type: "File", size: 11)))
        await cancelled.value
        #expect(details.metadata == nil && details.errorMessage == nil && !details.isLoading)
        let retry = Task { await details.load(item) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(ItemMetadata(type: "File", size: 22)))
        await retry.value
        #expect(details.metadata?.size == 22)
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

private actor MetadataGate {
    private var nextID = 0
    private var requests: [Int: CheckedContinuation<ItemMetadata, any Error>] = [:]
    private var observers: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var deadline: Task<Void, Never>?
    private var failure: CocoaError?

    deinit { deadline?.cancel() }

    func read(_ item: DirectoryEntry) async throws -> ItemMetadata {
        if let failure { throw failure }
        let id = nextID
        nextID += 1
        startDeadline()
        return try await withCheckedThrowingContinuation {
            requests[id] = $0
            observers.removeValue(forKey: id)?.resume()
        }
    }

    func waitForRequest(_ id: Int) async throws {
        if let failure { throw failure }
        if requests[id] != nil { return }
        startDeadline()
        try await withCheckedThrowingContinuation { observers[id] = $0 }
    }

    func finish(_ id: Int, result: Result<ItemMetadata, any Error>) throws {
        guard let request = requests.removeValue(forKey: id) else { throw CocoaError(.coderValueNotFound) }
        request.resume(with: result)
    }

    private func startDeadline() {
        guard deadline == nil else { return }
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            await self?.expire()
        }
    }

    private func expire() {
        deadline = nil
        guard !requests.isEmpty || !observers.isEmpty else { return }
        let error = CocoaError(.coderValueNotFound)
        failure = error
        Issue.record("Metadata gate timed out: reads \(requests.keys.sorted()), observers \(observers.keys.sorted())")
        for request in requests.values { request.resume(throwing: error) }
        for observer in observers.values { observer.resume(throwing: error) }
        requests.removeAll()
        observers.removeAll()
    }
}
