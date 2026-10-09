import Foundation
import Testing
@testable import PanePeekCore

struct DirectoryBrowsingTests {
    @Test func listingGateRejectsUnexpectedCompletions() async throws {
        let directory = URL(fileURLWithPath: "/gate", isDirectory: true)
        let gate = ListingGate()
        await #expect(throws: GateFailure("No pending listing for /gate")) {
            try await ListingGate().finish(directory, entries: [])
        }
        await #expect(throws: GateFailure("No pending listing for /gate")) {
            try await ListingGate().fail(directory)
        }
        let request = Task { try await gate.read(directory) }
        try await gate.waitForRequest(directory)
        try await gate.finish(directory, entries: [])
        _ = try await request.value
        await #expect(throws: GateFailure("No pending listing for /gate")) {
            try await gate.finish(directory, entries: [])
        }
    }

    @Test func sortGateRejectsUnexpectedCompletions() async throws {
        let gate = SortGate()
        await #expect(throws: GateFailure("No pending sort for 99")) {
            try await SortGate().finish(99)
        }
        let request = Task { await gate.sort([], field: .name, direction: .ascending) }
        _ = try await gate.waitForRequest(0)
        try await gate.finish(0)
        _ = await request.value
        await #expect(throws: GateFailure("No pending sort for 0")) {
            try await gate.finish(0)
        }
    }

    @Test(arguments: [false, true])
    func listingGateBoundsMissingRequestsAndCompletions(missingRequest: Bool) async {
        let directory = URL(fileURLWithPath: "/unfinished", isDirectory: true)
        let expected = GateFailure(missingRequest
            ? "Listing gate timed out; reads: []; waiting for: [\"/unfinished\"]"
            : "Listing gate timed out; reads: [\"/unfinished\"]; waiting for: []")
        await withKnownIssue {
            let gate = ListingGate(timeout: .zero)
            await #expect(throws: expected) {
                if missingRequest {
                    try await gate.waitForRequest(directory)
                } else {
                    _ = try await gate.read(directory)
                }
            }
            await #expect(throws: GateFailure("No pending listing for /unfinished")) {
                try await gate.finish(directory, entries: [])
            }
        } matching: { $0.error as? GateFailure == expected }
    }

    @Test(arguments: [false, true])
    func sortGateBoundsMissingRequestsAndCompletions(missingRequest: Bool) async {
        let entries = ["file10.txt", "file2.txt"].map {
            DirectoryEntry(url: URL(fileURLWithPath: "/sorting/\($0)"), isDirectory: false)
        }
        let expected = GateFailure(missingRequest
            ? "Sort gate timed out; sorts: []; waiting for: [7]"
            : "Sort gate timed out; sorts: [0]; waiting for: []")
        await withKnownIssue {
            let gate = SortGate(timeout: .zero)
            if missingRequest {
                await #expect(throws: expected) { _ = try await gate.waitForRequest(7) }
            } else {
                let result = await gate.sort(entries, field: .name, direction: .ascending)
                #expect(result.map(\.name) == ["file2.txt", "file10.txt"])
            }
            let id = missingRequest ? 7 : 0
            await #expect(throws: GateFailure("No pending sort for \(id)")) { try await gate.finish(id) }
        } matching: { $0.error as? GateFailure == expected }
    }

    @Test func listingGateFailureReleasesAllPendingReaders() async throws {
        let first = URL(fileURLWithPath: "/first", isDirectory: true)
        let second = URL(fileURLWithPath: "/second", isDirectory: true)
        let gate = ListingGate()
        let firstRead = Task { try await gate.read(first) }
        try await gate.waitForRequest(first)
        let secondRead = Task { try await gate.read(second) }
        try await gate.waitForRequest(second)
        let waiting = Task { try await gate.waitForRequest(URL(fileURLWithPath: "/missing")) }
        let expected = GateFailure("No pending listing for /missing")
        await #expect(throws: expected) {
            try await gate.finish(URL(fileURLWithPath: "/missing"), entries: [])
        }
        await #expect(throws: expected) { _ = try await firstRead.value }
        await #expect(throws: expected) { _ = try await secondRead.value }
        await #expect(throws: expected) { try await waiting.value }
    }

    @Test func sortGateFailureReleasesAllPendingSorts() async throws {
        let entries = [DirectoryEntry(url: URL(fileURLWithPath: "/sorting/file2.txt"), isDirectory: false)]
        let gate = SortGate()
        let first = Task { await gate.sort(entries, field: .name, direction: .ascending) }
        _ = try await gate.waitForRequest(0)
        let second = Task { await gate.sort(entries, field: .lastModified, direction: .descending) }
        _ = try await gate.waitForRequest(1)
        let waiting = Task { try await gate.waitForRequest(99) }
        let expected = GateFailure("No pending sort for 99")
        await #expect(throws: expected) { try await gate.finish(99) }
        #expect(await first.value == entries)
        #expect(await second.value == entries)
        await #expect(throws: expected) { _ = try await waiting.value }
    }

    @Test func gatesRejectDuplicateRegistrationsWithoutLosingContinuations() async throws {
        let directory = URL(fileURLWithPath: "/duplicate", isDirectory: true)
        let listings = ListingGate()
        let read = Task { try await listings.read(directory) }
        try await listings.waitForRequest(directory)
        let duplicateRead = GateFailure("Duplicate listing request for /duplicate")
        await #expect(throws: duplicateRead) { _ = try await listings.read(directory) }
        await #expect(throws: duplicateRead) { _ = try await read.value }

        let observers = ListingGate()
        let firstObserver = Task { try await observers.waitForRequest(directory) }
        let secondObserver = Task { try await observers.waitForRequest(directory) }
        let duplicateObserver = GateFailure("Duplicate listing observer for /duplicate")
        await #expect(throws: duplicateObserver) { try await firstObserver.value }
        await #expect(throws: duplicateObserver) { try await secondObserver.value }

        let sorts = SortGate()
        let firstSortObserver = Task { try await sorts.waitForRequest(7) }
        let secondSortObserver = Task { try await sorts.waitForRequest(7) }
        let duplicateSortObserver = GateFailure("Duplicate sort observer for 7")
        await #expect(throws: duplicateSortObserver) { _ = try await firstSortObserver.value }
        await #expect(throws: duplicateSortObserver) { _ = try await secondSortObserver.value }
    }

    @Test @MainActor func newerSortWinsWhenOlderSortFinishesLast() async throws {
        let directory = URL(fileURLWithPath: "/sorting", isDirectory: true)
        let entries = [
            DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false,
                           modifiedDate: Date(timeIntervalSince1970: 100)),
            DirectoryEntry(url: directory.appendingPathComponent("file10.txt"), isDirectory: false,
                           modifiedDate: Date(timeIntervalSince1970: 200))
        ]
        let gate = SortGate()
        let pane = DirectoryPane(directory: directory,
                                 load: { DirectoryListing(directory: $0, entries: entries) },
                                 sortEntries: { await gate.sort($0, field: $1, direction: $2) })
        await gate.open()
        await pane.navigate(to: directory)
        await gate.close()

        let older = Task { await pane.sort(by: .lastModified) }
        let first = try await gate.waitForRequest(0)
        #expect(first.field == .lastModified)
        #expect(first.direction == .descending)
        #expect(pane.entries == entries)
        pane.showHiddenFiles = true
        let newer = Task { await pane.sort(by: .name) }
        _ = try await gate.waitForRequest(1)
        try await gate.finish(1)
        await newer.value
        try await gate.finish(0)
        await older.value

        #expect(pane.sortField == .name)
        #expect(pane.sortDirection == .ascending)
        #expect(pane.entries == entries)
        #expect(pane.showHiddenFiles)
    }

    @Test @MainActor func navigationPublishesCurrentSortAndRejectsOldListingSorts() async throws {
        let original = URL(fileURLWithPath: "/original", isDirectory: true)
        let destination = URL(fileURLWithPath: "/destination", isDirectory: true)
        let gate = SortGate()
        let pane = DirectoryPane(directory: original, load: { directory in
            DirectoryListing(directory: directory, entries: [
                DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false,
                               modifiedDate: Date(timeIntervalSince1970: 200)),
                DirectoryEntry(url: directory.appendingPathComponent("file10.txt"), isDirectory: false,
                               modifiedDate: Date(timeIntervalSince1970: 100))
            ])
        }, sortEntries: { await gate.sort($0, field: $1, direction: $2) })
        await gate.open()
        await pane.navigate(to: original)
        let retained = pane.entries
        await gate.close()

        let older = Task { await pane.sort(by: .name) }
        _ = try await gate.waitForRequest(0)
        let navigation = Task { await pane.navigate(to: destination) }
        let pending = try await gate.waitForRequest(1)
        #expect(pending.entries.allSatisfy { $0.url.deletingLastPathComponent() == destination })
        #expect(pane.directory == original)
        #expect(pane.entries == retained)
        let latestSort = Task { await pane.sort(by: .lastModified) }
        _ = try await gate.waitForRequest(2)
        try await gate.finish(2)
        await latestSort.value
        await gate.open()
        try await gate.finish(1)
        await navigation.value
        try await gate.finish(0)
        await older.value

        #expect(pane.directory == destination)
        #expect(pane.entries.map(\.url) == [destination.appendingPathComponent("file2.txt"),
                                          destination.appendingPathComponent("file10.txt")])
        #expect(pane.sortField == .lastModified)
        #expect(pane.sortDirection == .descending)
        #expect(!pane.isLoading)
        #expect(pane.errorMessage == nil)
    }

    @Test @MainActor func supersededNavigationSortCannotEndTheCurrentLoadingState() async throws {
        let original = URL(fileURLWithPath: "/original", isDirectory: true)
        let destination = URL(fileURLWithPath: "/destination", isDirectory: true)
        let gate = SortGate()
        let pane = DirectoryPane(directory: original, load: { directory in
            DirectoryListing(directory: directory, entries: [
                DirectoryEntry(url: directory.appendingPathComponent("kept.txt"), isDirectory: false)
            ])
        }, sortEntries: { await gate.sort($0, field: $1, direction: $2) })
        let older = Task { await pane.navigate(to: original) }
        _ = try await gate.waitForRequest(0)
        let newer = Task { await pane.navigate(to: destination) }
        _ = try await gate.waitForRequest(1)
        try await gate.finish(0)
        await older.value
        #expect(pane.isLoading)
        #expect(pane.entries.isEmpty)
        try await gate.finish(1)
        await newer.value
        #expect(pane.directory == destination)
        #expect(pane.entries.map(\.url) == [destination.appendingPathComponent("kept.txt")])
        #expect(!pane.isLoading)
    }

    @Test @MainActor func hiddenMetadataAndDotNamesFollowIndependentPaneVisibility() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let folder = try fixture.folder("folder2")
        let hiddenFolder = try fixture.folder(".folder10")
        let file = try fixture.file("file2.txt")
        let dotFile = try fixture.file(".file10.txt")
        var flaggedFile = try fixture.file("flag3.txt")
        var values = URLResourceValues()
        values.isHidden = true
        try flaggedFile.setResourceValues(values)
        #expect(try flaggedFile.resourceValues(forKeys: [.isHiddenKey]).isHidden == true)
        for (url, seconds) in [(folder, 50.0), (file, 100.0), (dotFile, 200.0),
                               (flaggedFile, 300.0), (hiddenFolder, 400.0)] {
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: seconds)],
                                                  ofItemAtPath: url.path)
        }
        let listing = try await DirectoryListing.read(fixture.root)
        #expect(Set(listing.entries.filter(\.isHidden).map(\.name)) == [".folder10", ".file10.txt", "flag3.txt"])
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: fixture.root)
        await browser.right.navigate(to: fixture.root)
        #expect(!browser.left.showHiddenFiles)
        #expect(!browser.right.showHiddenFiles)
        #expect(browser.left.entries.map(\.name) == ["folder2", "file2.txt"])
        let rightEntries = browser.right.entries

        await browser.left.sort(by: .lastModified)
        browser.left.showHiddenFiles = true
        #expect(browser.left.entries.map(\.name) == [".folder10", "flag3.txt", ".file10.txt", "file2.txt", "folder2"])
        browser.left.showHiddenFiles = false
        #expect(browser.left.entries.map(\.name) == ["file2.txt", "folder2"])
        #expect(browser.left.directory == fixture.root)
        #expect(browser.left.sortField == .lastModified)
        #expect(browser.left.sortDirection == .descending)
        browser.left.showHiddenFiles = true
        let destination = try fixture.folder("destination")
        try fixture.file("destination/.inside.txt")
        await browser.left.navigate(to: destination)
        #expect(browser.left.showHiddenFiles)
        #expect(browser.left.entries.map(\.name) == [".inside.txt"])
        #expect(browser.left.sortField == .lastModified)
        #expect(browser.left.sortDirection == .descending)
        #expect(browser.right.directory == fixture.root)
        #expect(browser.right.entries == rightEntries)
        #expect(!browser.right.showHiddenFiles)
        #expect(browser.right.sortField == .name)
    }

    @Test @MainActor func manualRefreshReadsNewItemsOnlyIntoItsPaneAndRetainsSettings() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let first = try fixture.file("file2.txt")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: first.path)
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: fixture.root)
        await browser.right.navigate(to: fixture.root)
        let rightEntries = browser.right.entries
        await browser.left.sort(by: .lastModified)
        browser.left.showHiddenFiles = true
        for (name, seconds) in [("file10.txt", 200.0), (".new.txt", 300.0)] {
            let url = try fixture.file(name)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: seconds)], ofItemAtPath: url.path)
        }
        #expect(browser.left.entries.map(\.name) == ["file2.txt"])
        await browser.left.refresh()
        #expect(browser.left.entries.map(\.name) == [".new.txt", "file10.txt", "file2.txt"])
        #expect(browser.left.directory == fixture.root)
        #expect(browser.left.showHiddenFiles)
        #expect(browser.left.sortField == .lastModified)
        #expect(browser.left.sortDirection == .descending)
        #expect(browser.left.errorMessage == nil)
        #expect(browser.right.entries == rightEntries)
        #expect(!browser.right.showHiddenFiles)
        #expect(browser.right.sortField == .name)
    }

    @Test @MainActor func pendingRefreshKeepsItsPaneAndAppliesCurrentViewSettings() async throws {
        let directory = URL(fileURLWithPath: "/refresh", isDirectory: true)
        let visible = DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false,
                                     modifiedDate: Date(timeIntervalSince1970: 100))
        let hidden = DirectoryEntry(url: directory.appendingPathComponent(".file10.txt"), isDirectory: false,
                                    isHidden: true, modifiedDate: Date(timeIntervalSince1970: 200))
        let gate = ListingGate()
        let browser = BrowserState(homeDirectory: directory, load: { try await gate.read($0) })
        let initial = Task { await browser.right.navigate(to: directory) }
        try await gate.waitForRequest(directory)
        try await gate.finish(directory, entries: [visible])
        await initial.value
        browser.focus(.right)
        let target = browser.pane(browser.focusedPane)
        let refresh = Task { await target.refresh() }
        try await gate.waitForRequest(directory)
        #expect(target.isLoading)
        browser.focus(.left)
        target.showHiddenFiles = true
        await target.sort(by: .lastModified)
        try await gate.finish(directory, entries: [visible, hidden])
        await refresh.value
        #expect(browser.right.entries.map(\.url) == [hidden.url, visible.url])
        #expect(browser.right.directory == directory)
        #expect(browser.focusedPane == .left)
        #expect(browser.left.entries.isEmpty)
        #expect(!browser.left.showHiddenFiles)
        #expect(browser.left.sortField == .name)
        #expect(!target.isLoading)
    }

    @Test @MainActor func failedRefreshRetainsRowsAndLaterRefreshClearsTheError() async throws {
        let directory = URL(fileURLWithPath: "/refresh", isDirectory: true)
        let entry = DirectoryEntry(url: directory.appendingPathComponent("kept.txt"), isDirectory: false)
        let gate = ListingGate()
        let pane = DirectoryPane(directory: directory, load: { try await gate.read($0) })
        let initial = Task { await pane.navigate(to: directory) }
        try await gate.waitForRequest(directory)
        try await gate.finish(directory, entries: [entry])
        await initial.value
        pane.showHiddenFiles = true
        await pane.sort(by: .lastModified)
        let failed = Task { await pane.refresh() }
        try await gate.waitForRequest(directory)
        try await gate.fail(directory)
        await failed.value
        #expect(pane.directory == directory)
        #expect(pane.entries == [entry])
        #expect(pane.showHiddenFiles)
        #expect(pane.sortField == .lastModified)
        #expect(pane.sortDirection == .descending)
        #expect(pane.errorMessage != nil)
        #expect(!pane.isLoading)
        let retry = Task { await pane.refresh() }
        try await gate.waitForRequest(directory)
        try await gate.finish(directory, entries: [])
        await retry.value
        #expect(pane.entries.isEmpty)
        #expect(pane.errorMessage == nil)
        #expect(pane.showHiddenFiles)
        #expect(pane.sortField == .lastModified)
        #expect(!pane.isLoading)
    }

    @Test @MainActor func columnClicksChooseUsefulDefaultsAndReverseOnlyTheirPane() async {
        let directory = URL(fileURLWithPath: "/sorting", isDirectory: true)
        let entries = [
            DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false,
                           modifiedDate: Date(timeIntervalSince1970: 100)),
            DirectoryEntry(url: directory.appendingPathComponent("file10.txt"), isDirectory: false,
                           modifiedDate: Date(timeIntervalSince1970: 200))
        ]
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await browser.left.navigate(to: directory)
        await browser.right.navigate(to: directory)

        await browser.left.sort(by: .name)
        #expect(browser.left.sortDirection == .descending)
        #expect(browser.left.entries.map(\.name) == ["file10.txt", "file2.txt"])
        await browser.left.sort(by: .lastModified)
        #expect(browser.left.sortField == .lastModified)
        #expect(browser.left.sortDirection == .descending)
        #expect(browser.left.entries.map(\.name) == ["file10.txt", "file2.txt"])
        await browser.left.sort(by: .lastModified)
        #expect(browser.left.sortDirection == .ascending)
        #expect(browser.left.entries.map(\.name) == ["file2.txt", "file10.txt"])
        await browser.left.sort(by: .lastModified)
        #expect(browser.left.sortDirection == .descending)
        await browser.left.sort(by: .name)
        #expect(browser.left.sortDirection == .ascending)
        #expect(browser.left.entries.map(\.name) == ["file2.txt", "file10.txt"])
        #expect(browser.right.sortField == .name)
        #expect(browser.right.sortDirection == .ascending)
        #expect(browser.right.entries.map(\.name) == ["file2.txt", "file10.txt"])
    }

    @Test func realListingReadsModifiedValuesAndIdentifiesPackagesAndLinks() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let file = try fixture.file("file2.txt")
        let folder = try fixture.folder("folder2")
        let package = try fixture.folder("Sample.app")
        let files = FileManager.default
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        for url in [file, folder, package] {
            try files.setAttributes([.modificationDate: timestamp], ofItemAtPath: url.path)
        }
        for (name, target) in [("file-link", file), ("folder-link", folder), ("package-link", package),
                               ("broken-link", fixture.root.appendingPathComponent("missing"))] {
            try files.createSymbolicLink(at: fixture.root.appendingPathComponent(name), withDestinationURL: target)
        }
        let entries = try await DirectoryListing.read(fixture.root).entries
        for name in ["file2.txt", "folder2", "Sample.app"] {
            #expect(entries.first { $0.name == name }?.modifiedDate == timestamp)
        }
        #expect(entries.first { $0.name == "Sample.app" }?.isPackage == true)
        #expect(entries.first { $0.name == "Sample.app" }?.isDirectory == false)
        for name in ["file-link", "folder-link", "package-link", "broken-link"] {
            let entry = try #require(entries.first { $0.name == name })
            #expect(entry.isSymbolicLink)
            let linkDate = try files.attributesOfItem(atPath: entry.url.path)[.modificationDate] as? Date
            #expect(entry.modifiedDate == linkDate)
            #expect(entry.modifiedDate != timestamp)
        }
        #expect(entries.first { $0.name == "folder-link" }?.isDirectory == true)
        #expect(entries.first { $0.name == "package-link" }?.isPackage == true)
        #expect(entries.first { $0.name == "package-link" }?.isDirectory == false)
        #expect(entries.first { $0.name == "broken-link" }?.isDirectory == false)
    }

    @Test(arguments: [DirectorySortField.name, .lastModified], [DirectorySortDirection.ascending, .descending])
    @MainActor func sortingUsesFolderGroupsForNamesAndGlobalDates(field: DirectorySortField,
                                                                 direction: DirectorySortDirection) async {
        let directory = URL(fileURLWithPath: "/sorting", isDirectory: true)
        let early = Date(timeIntervalSince1970: 100)
        let late = Date(timeIntervalSince1970: 200)
        let entries = [
            DirectoryEntry(url: directory.appendingPathComponent("file10.txt"), isDirectory: false, modifiedDate: late),
            DirectoryEntry(url: directory.appendingPathComponent("folder2"), isDirectory: true, modifiedDate: late),
            DirectoryEntry(url: directory.appendingPathComponent("unknown.txt"), isDirectory: false),
            DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false, modifiedDate: late),
            DirectoryEntry(url: directory.appendingPathComponent("folder10"), isDirectory: true, modifiedDate: early),
            DirectoryEntry(url: directory.appendingPathComponent("older.txt"), isDirectory: false, modifiedDate: early),
            DirectoryEntry(url: directory.appendingPathComponent("unknown-folder"), isDirectory: true)
        ]
        let pane = DirectoryPane(directory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await pane.navigate(to: directory)
        #expect(pane.sortField == .name)
        #expect(pane.sortDirection == .ascending)
        await pane.sort(by: field, direction: direction)
        let expected: [String]
        switch (field, direction) {
        case (.name, .ascending):
            expected = ["folder2", "folder10", "unknown-folder", "file2.txt", "file10.txt", "older.txt", "unknown.txt"]
        case (.name, .descending):
            expected = ["unknown-folder", "folder10", "folder2", "unknown.txt", "older.txt", "file10.txt", "file2.txt"]
        case (.lastModified, .ascending):
            expected = ["folder10", "older.txt", "file2.txt", "file10.txt", "folder2", "unknown-folder", "unknown.txt"]
        case (.lastModified, .descending):
            expected = ["file2.txt", "file10.txt", "folder2", "folder10", "older.txt", "unknown-folder", "unknown.txt"]
        }
        #expect(pane.entries.map(\.name) == expected)
    }

    @Test @MainActor func equalNamesUseAStablePathInBothDirections() async {
        let first = DirectoryEntry(url: URL(fileURLWithPath: "/sorting/a/file2.txt"), isDirectory: false,
                                   modifiedDate: Date(timeIntervalSince1970: 100))
        let second = DirectoryEntry(url: URL(fileURLWithPath: "/sorting/b/file2.txt"), isDirectory: false,
                                    modifiedDate: first.modifiedDate)
        let directory = URL(fileURLWithPath: "/sorting", isDirectory: true)
        let pane = DirectoryPane(directory: directory, load: { DirectoryListing(directory: $0, entries: [second, first]) })
        await pane.navigate(to: directory)
        for field in DirectorySortField.allCases {
            for direction in [DirectorySortDirection.ascending, .descending] {
                await pane.sort(by: field, direction: direction)
                #expect(pane.entries.map(\.url) == [first.url, second.url])
            }
        }
    }

    @Test @MainActor func independentSortSettingsApplyAfterPendingNavigation() async throws {
        let directory = URL(fileURLWithPath: "/sorting", isDirectory: true)
        let entries = [
            DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false,
                           modifiedDate: Date(timeIntervalSince1970: 100)),
            DirectoryEntry(url: directory.appendingPathComponent("file10.txt"), isDirectory: false,
                           modifiedDate: Date(timeIntervalSince1970: 200))
        ]
        let gate = ListingGate()
        let browser = BrowserState(homeDirectory: directory, load: { try await gate.read($0) })
        let right = Task { await browser.right.navigate(to: directory) }
        try await gate.waitForRequest(directory)
        try await gate.finish(directory, entries: entries)
        await right.value
        let rightEntries = browser.right.entries
        let left = Task { await browser.left.navigate(to: directory) }
        try await gate.waitForRequest(directory)
        await browser.left.sort(by: .lastModified, direction: .descending)
        try await gate.finish(directory, entries: entries)
        await left.value
        #expect(browser.left.entries.map(\.name) == ["file10.txt", "file2.txt"])
        #expect(browser.right.sortField == .name)
        #expect(browser.right.sortDirection == .ascending)
        #expect(browser.right.entries == rightEntries)
        #expect(browser.left.sortField == .lastModified)
        #expect(browser.left.sortDirection == .descending)
    }

    @Test @MainActor func breadcrumbsKeepRootAndLiteralAncestorPaths() {
        let root = DirectoryPane(directory: URL(fileURLWithPath: "/", isDirectory: true))
        #expect(root.breadcrumbDirectories.map(\.path) == ["/"])

        let pane = DirectoryPane(directory: URL(fileURLWithPath: "/workspace/project space/notes ü#%", isDirectory: true))
        #expect(pane.breadcrumbDirectories.map(\.path) == [
            "/", "/workspace", "/workspace/project space", "/workspace/project space/notes ü#%"
        ])
    }

    @Test @MainActor func realListingDistinguishesDirectoriesAndPaneUsesNaturalOrder() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        try fixture.folder("folder10")
        try fixture.folder("folder2")
        try fixture.file("file10.txt")
        try fixture.file("file2.txt")

        let entries = try await DirectoryListing.read(fixture.root).entries
        #expect(Set(entries.map(\.name)) == ["folder2", "folder10", "file2.txt", "file10.txt"])
        #expect(Set(entries.filter(\.isDirectory).map(\.name)) == ["folder2", "folder10"])

        let pane = DirectoryPane(directory: fixture.root)
        await pane.navigate(to: fixture.root)
        #expect(pane.entries.map(\.name) == ["folder2", "folder10", "file2.txt", "file10.txt"])
        await pane.navigate(to: try fixture.folder("empty"))
        #expect(pane.entries.isEmpty)
    }

    @Test @MainActor func invalidNavigationRetainsTheSuccessfulDirectoryAndListing() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let valid = try fixture.folder("valid")
        try fixture.file("valid/kept.txt")
        let regularFile = try fixture.file("regular.txt")
        let deleted = try fixture.folder("deleted")
        try FileManager.default.removeItem(at: deleted)
        let pane = DirectoryPane(directory: fixture.root)
        await pane.navigate(to: valid)
        let entries = pane.entries
        let selected = valid.appendingPathComponent("kept.txt")
        pane.setSelection([selected])

        for path in [fixture.root.appendingPathComponent("missing").path, regularFile.path, deleted.path, "relative", ""] {
            await pane.navigate(toPath: path)
            #expect(pane.directory == valid)
            #expect(pane.entries == entries)
            #expect(pane.selectedItems == [selected])
            #expect(pane.primaryItemURL == selected)
            #expect(pane.errorMessage != nil)
            #expect(!pane.isLoading)
        }
        #expect(entries.map(\.name) == ["kept.txt"])
        await pane.navigate(to: fixture.root)
        #expect(pane.errorMessage == nil)
        #expect(pane.directory == fixture.root)
    }

    @Test @MainActor func sharedActionsTargetFocusAndLeaveTheOtherPaneAlone() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let first = try fixture.folder("first")
        let second = try fixture.folder("second")
        try fixture.file("first/one.txt")
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: first)
        let leftEntries = browser.left.entries
        browser.focus(.right)
        await browser.pane(browser.focusedPane).navigate(toPath: second.path)

        #expect(browser.focusedPane == .right)
        #expect(browser.right.directory == second)
        #expect(browser.left.directory == first)
        #expect(browser.left.entries == leftEntries)
    }

    @Test @MainActor func directoryLinksFollowFinderLocationAndPackagesAreNotBrowsable() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let target = try fixture.folder("storage/destination")
        try fixture.file("storage/destination/inside.txt")
        let aliases = try fixture.folder("aliases")
        let link = aliases.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try fixture.folder("Sample.app")

        let entries = try await DirectoryListing.read(fixture.root).entries
        #expect(entries.first { $0.name == "Sample.app" }?.isDirectory == false)
        let aliasesEntries = try await DirectoryListing.read(aliases).entries
        #expect(aliasesEntries.first?.url.path == link.path)
        #expect(aliasesEntries.first?.isDirectory == true)

        let pane = DirectoryPane(directory: fixture.root)
        await pane.navigate(toPath: link.path)
        #expect(pane.directory.path == target.path)
        #expect(pane.entries.first?.url.path == target.appendingPathComponent("inside.txt").path)
        #expect(pane.breadcrumbDirectories.suffix(2).map(\.lastPathComponent) == ["storage", "destination"])
        await pane.navigate(to: pane.directory.deletingLastPathComponent())
        #expect(pane.directory.path == target.deletingLastPathComponent().path)
        await pane.navigate(to: link)
        #expect(pane.directory.path == target.path)

        let retainedEntries = pane.entries
        let broken = aliases.appendingPathComponent("broken")
        try FileManager.default.createSymbolicLink(at: broken, withDestinationURL: fixture.root.appendingPathComponent("missing"))
        await pane.navigate(to: broken)
        #expect(pane.directory.path == target.path)
        #expect(pane.entries == retainedEntries)
        #expect(pane.errorMessage != nil)
    }

    @Test(arguments: [false, true]) @MainActor
    func olderSuccessOrErrorCannotReplaceNewerNavigation(olderFails: Bool) async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let older = try fixture.folder("older")
        let newer = try fixture.folder("newer")
        try fixture.file("newer/current.txt")
        let gate = ListingGate()
        let pane = DirectoryPane(directory: fixture.root, load: { try await gate.read($0) })

        let oldRequest = Task { await pane.navigate(to: older) }
        try await gate.waitForRequest(older)
        #expect(pane.isLoading)
        #expect(pane.directory == fixture.root)
        let newRequest = Task { await pane.navigate(to: newer) }
        try await gate.waitForRequest(newer)
        try await gate.finish(newer, entries: try await DirectoryListing.read(newer).entries)
        await newRequest.value
        let selected = newer.appendingPathComponent("current.txt")
        pane.setSelection([selected])
        if olderFails {
            try await gate.fail(older)
        } else {
            try await gate.finish(older, entries: [])
        }
        await oldRequest.value

        #expect(pane.directory == newer)
        #expect(pane.entries.map(\.name) == ["current.txt"])
        #expect(pane.selectedItems == [selected])
        #expect(pane.primaryItemURL == selected)
        #expect(pane.errorMessage == nil)
        #expect(!pane.isLoading)
    }

    @Test @MainActor func pendingSharedNavigationKeepsItsTargetWhileFocusChanges() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let destination = try fixture.folder("destination")
        let gate = ListingGate()
        let browser = BrowserState(homeDirectory: fixture.root, load: { try await gate.read($0) })
        browser.focus(.right)
        let target = browser.pane(browser.focusedPane)
        let request = Task { await target.navigate(toPath: destination.path) }
        try await gate.waitForRequest(destination)
        browser.focus(.left)
        #expect(browser.focusedPane == .left)
        try await gate.finish(destination, entries: [])
        await request.value

        #expect(browser.left.directory == fixture.root)
        #expect(browser.right.directory == destination)
    }
}

private struct DirectoryFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-tests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult func folder(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult func file(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path)
        try Data("fixture".utf8).write(to: url)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private struct GateFailure: Error, Equatable, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}

private actor ListingGate {
    private let timeout: Duration
    private var deadline: Task<Void, Never>?
    private var failure: GateFailure?
    private var requests: [URL: CheckedContinuation<DirectoryListing, any Error>] = [:]
    private var observers: [URL: CheckedContinuation<Void, any Error>] = [:]

    init(timeout: Duration = .seconds(10)) { self.timeout = timeout }
    deinit { deadline?.cancel() }

    func read(_ directory: URL) async throws -> DirectoryListing {
        if let failure { throw failure }
        guard requests[directory] == nil else {
            let error = GateFailure("Duplicate listing request for \(directory.path)")
            abort(error)
            throw error
        }
        startDeadline()
        return try await withCheckedThrowingContinuation { continuation in
            requests[directory] = continuation
            observers.removeValue(forKey: directory)?.resume()
        }
    }

    func waitForRequest(_ directory: URL) async throws {
        if let failure { throw failure }
        if requests[directory] != nil { return }
        guard observers[directory] == nil else {
            let error = GateFailure("Duplicate listing observer for \(directory.path)")
            abort(error)
            throw error
        }
        startDeadline()
        try await withCheckedThrowingContinuation { observers[directory] = $0 }
    }

    func finish(_ directory: URL, entries: [DirectoryEntry]) throws {
        guard let continuation = requests.removeValue(forKey: directory) else {
            let error = GateFailure("No pending listing for \(directory.path)")
            abort(error)
            throw error
        }
        continuation.resume(returning: DirectoryListing(directory: directory, entries: entries))
    }

    func fail(_ directory: URL) throws {
        guard let continuation = requests.removeValue(forKey: directory) else {
            let error = GateFailure("No pending listing for \(directory.path)")
            abort(error)
            throw error
        }
        continuation.resume(throwing: CocoaError(.fileReadNoPermission))
    }

    // Bound the test gate lifetime without using delays to order product operations.
    private func startDeadline() {
        guard deadline == nil else { return }
        let timeout = timeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            await self?.expire()
        }
    }

    private func expire() {
        deadline = nil
        guard !requests.isEmpty || !observers.isEmpty else { return }
        let error = GateFailure(
            "Listing gate timed out; reads: \(requests.keys.map(\.path).sorted()); " +
            "waiting for: \(observers.keys.map(\.path).sorted())"
        )
        Issue.record(error)
        abort(error)
    }

    private func abort(_ error: GateFailure) {
        failure = error
        deadline?.cancel()
        for continuation in requests.values { continuation.resume(throwing: error) }
        for continuation in observers.values { continuation.resume(throwing: error) }
        requests.removeAll()
        observers.removeAll()
    }
}

private actor SortGate {
    struct Request: Sendable {
        let entries: [DirectoryEntry]
        let field: DirectorySortField
        let direction: DirectorySortDirection

        var result: [DirectoryEntry] {
            entries.sorted { $0.precedes($1, field: field, direction: direction) }
        }
    }

    private let timeout: Duration
    private var deadline: Task<Void, Never>?
    private var failure: GateFailure?
    private var isOpen = false
    private var nextID = 0
    private var requests: [Int: (request: Request, continuation: CheckedContinuation<[DirectoryEntry], Never>)] = [:]
    private var observers: [Int: CheckedContinuation<Request, any Error>] = [:]

    init(timeout: Duration = .seconds(10)) { self.timeout = timeout }
    deinit { deadline?.cancel() }

    func open() { isOpen = true }
    func close() { isOpen = false }

    func sort(_ entries: [DirectoryEntry], field: DirectorySortField,
              direction: DirectorySortDirection) async -> [DirectoryEntry] {
        let request = Request(entries: entries, field: field, direction: direction)
        if isOpen || failure != nil { return request.result }
        let id = nextID
        nextID += 1
        startDeadline()
        return await withCheckedContinuation { continuation in
            requests[id] = (request, continuation)
            observers.removeValue(forKey: id)?.resume(returning: request)
        }
    }

    func waitForRequest(_ id: Int) async throws -> Request {
        if let failure { throw failure }
        if let pending = requests[id] { return pending.request }
        guard observers[id] == nil else {
            let error = GateFailure("Duplicate sort observer for \(id)")
            abort(error)
            throw error
        }
        startDeadline()
        return try await withCheckedThrowingContinuation { observers[id] = $0 }
    }

    func finish(_ id: Int) throws {
        guard let pending = requests.removeValue(forKey: id) else {
            let error = GateFailure("No pending sort for \(id)")
            abort(error)
            throw error
        }
        pending.continuation.resume(returning: pending.request.result)
    }

    // Bound the test gate lifetime without using delays to order product operations.
    private func startDeadline() {
        guard deadline == nil else { return }
        let timeout = timeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            await self?.expire()
        }
    }

    private func expire() {
        deadline = nil
        guard !requests.isEmpty || !observers.isEmpty else { return }
        let error = GateFailure(
            "Sort gate timed out; sorts: \(requests.keys.sorted()); waiting for: \(observers.keys.sorted())"
        )
        Issue.record(error)
        abort(error)
    }

    private func abort(_ error: GateFailure) {
        failure = error
        deadline?.cancel()
        // The production sorter is non-throwing; release it after reporting the gate failure.
        for pending in requests.values { pending.continuation.resume(returning: pending.request.result) }
        for continuation in observers.values { continuation.resume(throwing: error) }
        requests.removeAll()
        observers.removeAll()
    }
}
