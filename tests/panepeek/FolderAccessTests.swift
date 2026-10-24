import Foundation
import Synchronization
import Testing
import PanePeekCore
@testable import PanePeek

@MainActor struct FolderAccessTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-access-" + UUID().uuidString, isDirectory: true).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root.resolvingSymlinksInPath()
    }

    @Test func historyRejectsAnUnrelatedGrantWithoutReplacingTheUsableLocation() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a", isDirectory: true)
        let b = root.appendingPathComponent("b", isDirectory: true)
        let unrelated = root.appendingPathComponent("unrelated", isDirectory: true)
        for folder in [a, b, unrelated] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false) }
        let stopped = Mutex(0)
        let access = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
        let pane = DirectoryPane(directory: root, resolveBeforeLoading: false,
                                 load: { try await access.read($0) { _ in unrelated } },
                                 loadHistory: { try await access.read($0, exact: true) { _ in unrelated } })
        await pane.navigate(to: a, using: { .init(directory: $0, entries: []) })
        await pane.navigate(to: b, using: { .init(directory: $0, entries: []) })
        await pane.goBack()
        #expect(pane.directory == b && pane.canGoBack && !pane.canGoForward)
        #expect(pane.errorMessage != nil && !pane.isLoading)
        #expect(stopped.withLock { $0 } == 1)
        pane.releaseAccess()
    }

    @Test func historyReacquiresADescendantFromAnAncestorGrantAndReleasesIt() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a", isDirectory: true)
        let b = root.appendingPathComponent("b", isDirectory: true)
        for folder in [a, b] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false) }
        let stopped = Mutex(0)
        let access = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
        let pane = DirectoryPane(directory: root, resolveBeforeLoading: false,
                                 load: { try await access.read($0) { _ in root } },
                                 loadHistory: { try await access.read($0, exact: true) { _ in root } })
        for directory in [a, b] { await pane.navigate(to: directory, using: { .init(directory: $0, entries: []) }) }
        await pane.goBack()
        #expect(pane.directory == a && pane.canGoForward && pane.directoryAccess != nil)
        await pane.goForward()
        #expect(pane.directory == b && !pane.canGoForward)
        pane.releaseAccess()
        #expect(stopped.withLock { $0 } == 1)
    }

    @Test func productionSandboxModeDoesNotDependOnReviewIdentity() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("PanePeek.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "com.bcinarli.PanePeek", "CFBundlePackageType": "APPL",
                                   "CFBundleExecutable": "PanePeek", "PanePeekSandboxed": true]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: app))
        #expect(FolderAccess.isSandboxed(in: bundle))
        #expect(bundle.object(forInfoDictionaryKey: "PanePeekSandboxReview") == nil)
        #expect(!FolderAccess.isSandboxed(in: .main))
    }

    @Test func operationReadsReuseOnlyTheCapturedGrantedFolder() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let access = FolderAccess(stop: { _ in })
        let grant = try #require(try await access.select(initial: root, mode: .readOnly) { _ in root })
        #expect(try await access.readAccess(for: root) === grant)
        await #expect(throws: (any Error).self) {
            _ = try await access.readAccess(for: URL(fileURLWithPath: root.path + "-ungranted"))
        }
        #expect(grant.mode == .readOnly)
    }

    @Test func incomingSourceParentNeedsAnExplicitReadChoiceAndNeverAnUnrelatedFolder() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let unrelated = try fixture()
        defer { try? FileManager.default.removeItem(at: unrelated) }
        let access = FolderAccess(stop: { _ in })
        await #expect(throws: CancellationError.self) { _ = try await access.readAccess(for: root) { _ in nil } }
        await #expect(throws: (any Error).self) { _ = try await access.readAccess(for: root) { _ in unrelated } }
        let grant = try await access.readAccess(for: root) { initial in
            #expect(initial == root)
            return root
        }
        #expect(grant.mode == .readOnly && grant.root == root)
        #expect(try await access.readAccess(for: root) { _ in Issue.record("Repeated read choice"); return nil } === grant)
    }

    @Test func legacyBookmarksStayReadOnlyUntilAnExplicitUpgradeAndWriteAccessPersists() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let domain = "panepeek-write-access-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let bookmarking = FolderAccess.Bookmarking(
            create: { url, _ in Data(url.path.utf8) },
            resolve: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale: false) },
            start: { _ in true })
        let first = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        var original: DirectoryListing? = try await first.read(root) { _ in root }
        #expect(original?.access?.mode == .readOnly)
        original = nil
        let data = try #require(preferences.data(forKey: "sandboxFolderBookmarks"))
        let records = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let legacy = records.map { record in record.filter { $0.key != "mode" } }
        preferences.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "sandboxFolderBookmarks")
        let next = FolderAccess(preferences: preferences, selectionMode: .readWrite, bookmarking: bookmarking, stop: { _ in })
        let readonly = try await next.readSaved(root, location: nil)
        #expect(readonly.access?.mode == .readOnly)
        var choices = 0
        #expect(try await next.writeAccess(for: root) { _ in choices += 1; return nil } == nil)
        let writable = try await next.writeAccess(for: root) { _ in choices += 1; return root }
        #expect(writable?.mode == .readWrite && choices == 2)
        #expect(readonly.access?.mode == .readOnly)
        let reopened = FolderAccess(preferences: preferences, selectionMode: .readWrite, bookmarking: bookmarking, stop: { _ in })
        let restored = try await reopened.writeAccess(for: root) { _ in Issue.record("Writable access was not remembered"); return nil }
        #expect(restored?.mode == .readWrite)
    }

    @Test func anExistingWritableAncestorCoversAReadOnlyChildWithoutAnotherChooser() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        let access = FolderAccess(stop: { _ in })
        let parent = try #require(try await access.select(initial: root, mode: .readWrite) { _ in root })
        let narrower = try #require(try await access.select(initial: child, mode: .readOnly) { _ in child })
        let writable = try await access.writeAccess(for: child) { _ in Issue.record("Unnecessary write prompt"); return nil }
        #expect(writable === parent && narrower.mode == .readOnly)
        withExtendedLifetime(narrower) {}
    }

    @Test func anUnrelatedEditingChoiceIsReleasedWithoutGrantingTheRequestedFolder() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let sibling = URL(fileURLWithPath: root.path + "-other", isDirectory: true)
        let stops = Mutex(0)
        let access = FolderAccess(stop: { _ in stops.withLock { $0 += 1 } })
        await #expect(throws: (any Error).self) {
            _ = try await access.writeAccess(for: root) { _ in sibling }
        }
        #expect(stops.withLock { $0 } == 1)
        var asked = false
        _ = try await access.writeAccess(for: root) { _ in asked = true; return nil }
        #expect(asked)
    }

    @Test func savedGrantReopensWithoutAChooserAndBalancesEachConsumer() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let domain = "panepeek-bookmarks-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let counts = Mutex((starts: 0, stops: 0))
        let bookmarking = FolderAccess.Bookmarking(
            create: { url, _ in Data(url.path.utf8) },
            resolve: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale: false) },
            start: { _ in counts.withLock { $0.starts += 1 }; return true })
        var first: DirectoryListing? = try await FolderAccess(preferences: preferences, bookmarking: bookmarking,
            stop: { _ in counts.withLock { $0.stops += 1 } }).read(root) { _ in root }
        #expect(first?.directory == root)
        first = nil
        let next = FolderAccess(preferences: preferences, bookmarking: bookmarking,
                                stop: { _ in counts.withLock { $0.stops += 1 } })
        var restored: DirectoryListing? = try await next.read(root) { _ in
            Issue.record("Saved folder access was lost across launches")
            return nil
        }
        #expect(restored?.directory == root)
        #expect(counts.withLock { $0.starts } == 1)
        restored = nil
        #expect(counts.withLock { $0.stops } == 2)
    }

    @Test(arguments: [DirectoryAccess.Mode.readOnly, .readWrite])
    func exactGrantedFolderSurvivesBookmarkRecreationFailureAndRelaunch(mode: DirectoryAccess.Mode) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let domain = "panepeek-original-bookmark-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let creations = Mutex(0)
        let bookmarking = FolderAccess.Bookmarking(
            create: { url, _ in
                let count = creations.withLock { $0 += 1; return $0 }
                guard count == 1 else { throw CocoaError(.fileReadUnknown) }
                return Data(url.path.utf8)
            },
            resolve: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale: false) },
            start: { _ in true })
        let first = FolderAccess(preferences: preferences, selectionMode: mode, bookmarking: bookmarking, stop: { _ in })
        let grant = try #require(try await first.select(initial: root) { _ in root })
        let initial = try await first.read(root) { _ in Issue.record("An active grant requested access again"); return nil }
        #expect(initial.directory == root && initial.access?.mode == mode)
        let saved = try #require(first.location(for: root))
        #expect(saved.data == Data(root.path.utf8) && saved.mode == mode)

        let next = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        let reopened = try await next.read(root) { _ in Issue.record("A valid saved grant requested access again"); return nil }
        #expect(reopened.directory == root && reopened.access?.mode == mode)
        let restored = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        let listing = try await restored.readSaved(root, location: saved)
        #expect(listing.directory == root && listing.access?.mode == mode)
        #expect(creations.withLock { $0 } == 1)
        withExtendedLifetime(grant) {}
    }

    @Test func descendantKeepsItsOwnBookmarkAndRestoresItsOwnDirectory() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        let domain = "panepeek-child-bookmark-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let created = Mutex(Set<String>())
        let bookmarking = FolderAccess.Bookmarking(
            create: { url, _ in
                guard created.withLock({ $0.insert(url.path).inserted }) else { throw CocoaError(.fileReadUnknown) }
                return Data(url.path.utf8)
            },
            resolve: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale: false) },
            start: { _ in true })
        let access = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        let grant = try #require(try await access.select(initial: root) { _ in root })
        let listing = try await access.read(child) { _ in Issue.record("A granted child requested access"); return nil }
        #expect(listing.directory == child)
        let location = try #require(access.location(for: child))
        #expect(location.data == Data(child.path.utf8))
        let reopened = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        let restored = try await reopened.readSaved(child, location: location)
        #expect(restored.directory == child)
        #expect(created.withLock { $0 } == Set([root.path, child.path]))
        withExtendedLifetime(grant) {}
    }

    @Test func aReplacedGrantedFolderCannotReuseTheOriginalBookmark() async throws {
        let base = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("granted", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let domain = "panepeek-replaced-bookmark-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let bookmarking = FolderAccess.Bookmarking(create: { url, _ in Data(url.path.utf8) })
        let access = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        let grant = try #require(try await access.select(initial: root) { _ in root })
        try FileManager.default.moveItem(at: root, to: base.appendingPathComponent("original", isDirectory: true))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        await #expect(throws: CocoaError(.fileReadNoPermission)) {
            _ = try await access.read(root) { _ in Issue.record("A replaced identity must not silently reconnect"); return nil }
        }
        #expect(access.location(for: root) == nil)
        withExtendedLifetime(grant) {}
    }

    @Test func staleLocationBookmarkIsRefreshedOnceBeforeReuse() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let domain = "panepeek-stale-source-bookmark-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let stale = Data("stale".utf8)
        let refreshed = Data("refreshed".utf8)
        let creations = Mutex(0)
        let bookmarking = FolderAccess.Bookmarking(
            create: { _, _ in
                guard creations.withLock({ $0 += 1; return $0 }) == 1 else { throw CocoaError(.fileReadUnknown) }
                return refreshed
            },
            resolve: { .init(url: root, stale: $0 == stale) }, start: { _ in true })
        let access = FolderAccess(preferences: preferences, bookmarking: bookmarking, stop: { _ in })
        let location = FolderAccess.Location(id: UUID(), data: stale, identity: try FolderAccess.Identity.read(root), mode: .readWrite)
        let first = try await access.readSaved(root, location: location)
        let saved = try #require(access.location(for: root))
        #expect(saved.data == refreshed)
        let again = try await access.readSaved(root, location: saved)
        #expect(first.directory == root && again.directory == root)
        #expect(creations.withLock { $0 } == 1)
    }

    @Test func panesShareAChosenRootUntilTheLastListingCloses() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        let stopped = Mutex(0)
        var choices = 0
        let access = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
        var first: DirectoryListing? = try await access.read(root) { _ in choices += 1; return root }
        var second: DirectoryListing? = try await access.read(child) { _ in Issue.record("Repeated folder prompt"); return nil }
        #expect(first?.directory == root && second?.directory == child)
        #expect(first?.access === second?.access)
        #expect(choices == 1)
        first = nil
        #expect(stopped.withLock { $0 } == 0)
        second = nil
        #expect(stopped.withLock { $0 } == 1)
    }

    @Test func siblingPrefixAndExternalLinksNeedTheirOwnGrant() async throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        let root = fixture.appendingPathComponent("one", isDirectory: true)
        let sibling = fixture.appendingPathComponent("one-other", isDirectory: true)
        for url in [root, sibling] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false) }
        let link = root.appendingPathComponent("outside")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: sibling)
        let access = FolderAccess(stop: { _ in })
        let listing = try await access.read(root) { _ in root }
        let entry = try #require(listing.entries.first)
        #expect(entry.isSymbolicLink && !entry.isDirectory && !entry.isPackage)
        for target in [sibling, link] {
            var requested: URL?
            await #expect(throws: CancellationError.self) {
                _ = try await access.read(target) { initial in requested = initial; return nil }
            }
            #expect(requested == sibling)
        }
        _ = listing.access
    }

    @Test func choosingAnotherFolderUsesOnlyTheSelection() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let access = FolderAccess(stop: { _ in })
        let listing = try await access.read(URL(fileURLWithPath: "/not-selected")) { _ in root }
        #expect(listing.directory == root)
    }

    @Test func cancellationAndFailedListingReleaseOnlyGrantedScopes() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let stopped = Mutex(0)
        let cancelled = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
        await #expect(throws: CancellationError.self) { _ = try await cancelled.read(root) { _ in nil } }
        #expect(stopped.withLock { $0 } == 0)
        let file = root.appendingPathComponent("file")
        try Data().write(to: file)
        let granted = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
        await #expect(throws: (any Error).self) { _ = try await granted.read(file) { _ in file } }
        #expect(stopped.withLock { $0 } == 1)
    }


    @Test func cancelledRequesterReleasesACompletedNativeGrant() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let stopped = Mutex(0)
        let access = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
        let task = Task {
            try await access.read(root) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return root
            }
        }
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        #expect(stopped.withLock { $0 } == 1)
    }

    @Test(.timeLimit(.minutes(1))) func delayedChoiceCannotReplaceANewerNavigationOrDetachedPane() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let other = root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        for closing in [false, true] {
            let stopped = Mutex(0)
            let access = FolderAccess(stop: { _ in stopped.withLock { $0 += 1 } })
            var answer: CheckedContinuation<URL?, Never>?
            var requested: CheckedContinuation<Void, Never>?
            let pane = DirectoryPane(directory: root, resolveBeforeLoading: false, load: { url in
                try await access.read(url) { initial in
                    if initial == other { return other }
                    return await withCheckedContinuation { continuation in
                        answer = continuation
                        requested?.resume()
                    }
                }
            })
            var navigation: Task<Void, Never>?
            await withCheckedContinuation { continuation in
                requested = continuation
                navigation = Task { await pane.navigate(to: root) }
            }
            if closing { pane.releaseAccess() }
            else { await pane.navigate(to: other) }
            answer?.resume(returning: root)
            await navigation?.value
            #expect(pane.hasLoaded == !closing)
            #expect(closing || pane.directory == other)
            #expect(stopped.withLock { $0 } == 1)
            pane.releaseAccess()
            #expect(stopped.withLock { $0 } == (closing ? 1 : 2))
        }
    }
}
