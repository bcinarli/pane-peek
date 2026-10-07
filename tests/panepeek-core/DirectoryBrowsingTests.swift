import Foundation
import Testing
@testable import PanePeekCore

struct DirectoryBrowsingTests {
    @Test @MainActor func newerSortWinsWhenOlderSortFinishesLast() async {
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
        let first = await gate.waitForRequest(0)
        #expect(first.field == .lastModified)
        #expect(first.direction == .descending)
        #expect(pane.entries == entries)
        pane.showHiddenFiles = true
        let newer = Task { await pane.sort(by: .name) }
        _ = await gate.waitForRequest(1)
        await gate.finish(1)
        await newer.value
        await gate.finish(0)
        await older.value

        #expect(pane.sortField == .name)
        #expect(pane.sortDirection == .ascending)
        #expect(pane.entries == entries)
        #expect(pane.showHiddenFiles)
    }

    @Test @MainActor func navigationPublishesCurrentSortAndRejectsOldListingSorts() async {
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
        _ = await gate.waitForRequest(0)
        let navigation = Task { await pane.navigate(to: destination) }
        let pending = await gate.waitForRequest(1)
        #expect(pending.entries.allSatisfy { $0.url.deletingLastPathComponent() == destination })
        #expect(pane.directory == original)
        #expect(pane.entries == retained)
        let latestSort = Task { await pane.sort(by: .lastModified) }
        _ = await gate.waitForRequest(2)
        await gate.finish(2)
        await latestSort.value
        await gate.open()
        await gate.finish(1)
        await navigation.value
        await gate.finish(0)
        await older.value

        #expect(pane.directory == destination)
        #expect(pane.entries.map(\.url) == [destination.appendingPathComponent("file2.txt"),
                                          destination.appendingPathComponent("file10.txt")])
        #expect(pane.sortField == .lastModified)
        #expect(pane.sortDirection == .descending)
        #expect(!pane.isLoading)
        #expect(pane.errorMessage == nil)
    }

    @Test @MainActor func supersededNavigationSortCannotEndTheCurrentLoadingState() async {
        let original = URL(fileURLWithPath: "/original", isDirectory: true)
        let destination = URL(fileURLWithPath: "/destination", isDirectory: true)
        let gate = SortGate()
        let pane = DirectoryPane(directory: original, load: { directory in
            DirectoryListing(directory: directory, entries: [
                DirectoryEntry(url: directory.appendingPathComponent("kept.txt"), isDirectory: false)
            ])
        }, sortEntries: { await gate.sort($0, field: $1, direction: $2) })
        let older = Task { await pane.navigate(to: original) }
        _ = await gate.waitForRequest(0)
        let newer = Task { await pane.navigate(to: destination) }
        _ = await gate.waitForRequest(1)
        await gate.finish(0)
        await older.value
        #expect(pane.isLoading)
        #expect(pane.entries.isEmpty)
        await gate.finish(1)
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

    @Test @MainActor func pendingRefreshKeepsItsPaneAndAppliesCurrentViewSettings() async {
        let directory = URL(fileURLWithPath: "/refresh", isDirectory: true)
        let visible = DirectoryEntry(url: directory.appendingPathComponent("file2.txt"), isDirectory: false,
                                     modifiedDate: Date(timeIntervalSince1970: 100))
        let hidden = DirectoryEntry(url: directory.appendingPathComponent(".file10.txt"), isDirectory: false,
                                    isHidden: true, modifiedDate: Date(timeIntervalSince1970: 200))
        let gate = ListingGate()
        let browser = BrowserState(homeDirectory: directory, load: { try await gate.read($0) })
        let initial = Task { await browser.right.navigate(to: directory) }
        await gate.waitForRequest(directory)
        await gate.finish(directory, entries: [visible])
        await initial.value
        browser.focus(.right)
        let target = browser.pane(browser.focusedPane)
        let refresh = Task { await target.refresh() }
        await gate.waitForRequest(directory)
        #expect(target.isLoading)
        browser.focus(.left)
        target.showHiddenFiles = true
        await target.sort(by: .lastModified)
        await gate.finish(directory, entries: [visible, hidden])
        await refresh.value
        #expect(browser.right.entries.map(\.url) == [hidden.url, visible.url])
        #expect(browser.right.directory == directory)
        #expect(browser.focusedPane == .left)
        #expect(browser.left.entries.isEmpty)
        #expect(!browser.left.showHiddenFiles)
        #expect(browser.left.sortField == .name)
        #expect(!target.isLoading)
    }

    @Test @MainActor func failedRefreshRetainsRowsAndLaterRefreshClearsTheError() async {
        let directory = URL(fileURLWithPath: "/refresh", isDirectory: true)
        let entry = DirectoryEntry(url: directory.appendingPathComponent("kept.txt"), isDirectory: false)
        let gate = ListingGate()
        let pane = DirectoryPane(directory: directory, load: { try await gate.read($0) })
        let initial = Task { await pane.navigate(to: directory) }
        await gate.waitForRequest(directory)
        await gate.finish(directory, entries: [entry])
        await initial.value
        pane.showHiddenFiles = true
        await pane.sort(by: .lastModified)
        let failed = Task { await pane.refresh() }
        await gate.waitForRequest(directory)
        await gate.fail(directory)
        await failed.value
        #expect(pane.directory == directory)
        #expect(pane.entries == [entry])
        #expect(pane.showHiddenFiles)
        #expect(pane.sortField == .lastModified)
        #expect(pane.sortDirection == .descending)
        #expect(pane.errorMessage != nil)
        #expect(!pane.isLoading)
        let retry = Task { await pane.refresh() }
        await gate.waitForRequest(directory)
        await gate.finish(directory, entries: [])
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

    @Test @MainActor func independentSortSettingsApplyAfterPendingNavigation() async {
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
        await gate.waitForRequest(directory)
        await gate.finish(directory, entries: entries)
        await right.value
        let rightEntries = browser.right.entries
        let left = Task { await browser.left.navigate(to: directory) }
        await gate.waitForRequest(directory)
        await browser.left.sort(by: .lastModified, direction: .descending)
        await gate.finish(directory, entries: entries)
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

    @Test func realListingDistinguishesDirectoriesAndUsesNaturalOrder() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        try fixture.folder("folder10")
        try fixture.folder("folder2")
        try fixture.file("file10.txt")
        try fixture.file("file2.txt")

        let entries = try await DirectoryListing.read(fixture.root).entries
        #expect(entries.map(\.name) == ["folder2", "folder10", "file2.txt", "file10.txt"])
        #expect(entries.map(\.isDirectory) == [true, true, false, false])
        #expect(try await DirectoryListing.read(fixture.folder("empty")).entries.isEmpty)
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
        await gate.waitForRequest(older)
        #expect(pane.isLoading)
        #expect(pane.directory == fixture.root)
        let newRequest = Task { await pane.navigate(to: newer) }
        await gate.waitForRequest(newer)
        await gate.finish(newer, entries: try await DirectoryListing.read(newer).entries)
        await newRequest.value
        let selected = newer.appendingPathComponent("current.txt")
        pane.setSelection([selected])
        if olderFails {
            await gate.fail(older)
        } else {
            await gate.finish(older, entries: [])
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
        await gate.waitForRequest(destination)
        browser.focus(.left)
        #expect(browser.focusedPane == .left)
        await gate.finish(destination, entries: [])
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

private actor ListingGate {
    private var requests: [URL: CheckedContinuation<DirectoryListing, any Error>] = [:]
    private var observers: [URL: CheckedContinuation<Void, Never>] = [:]

    func read(_ directory: URL) async throws -> DirectoryListing {
        try await withCheckedThrowingContinuation { continuation in
            requests[directory] = continuation
            observers.removeValue(forKey: directory)?.resume()
        }
    }

    func waitForRequest(_ directory: URL) async {
        if requests[directory] != nil { return }
        await withCheckedContinuation { observers[directory] = $0 }
    }

    func finish(_ directory: URL, entries: [DirectoryEntry]) {
        requests.removeValue(forKey: directory)?.resume(returning: DirectoryListing(directory: directory, entries: entries))
    }

    func fail(_ directory: URL) {
        requests.removeValue(forKey: directory)?.resume(throwing: CocoaError(.fileReadNoPermission))
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

    private var isOpen = false
    private var nextID = 0
    private var requests: [Int: Request] = [:]
    private var completions: [Int: CheckedContinuation<[DirectoryEntry], Never>] = [:]
    private var observers: [Int: CheckedContinuation<Request, Never>] = [:]

    func open() { isOpen = true }
    func close() { isOpen = false }

    func sort(_ entries: [DirectoryEntry], field: DirectorySortField,
              direction: DirectorySortDirection) async -> [DirectoryEntry] {
        let request = Request(entries: entries, field: field, direction: direction)
        if isOpen { return request.result }
        let id = nextID
        nextID += 1
        return await withCheckedContinuation { continuation in
            requests[id] = request
            completions[id] = continuation
            observers.removeValue(forKey: id)?.resume(returning: request)
        }
    }

    func waitForRequest(_ id: Int) async -> Request {
        if let request = requests[id] { return request }
        return await withCheckedContinuation { observers[id] = $0 }
    }

    func finish(_ id: Int) {
        guard let request = requests.removeValue(forKey: id) else { return }
        completions.removeValue(forKey: id)?.resume(returning: request.result)
    }
}
