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
