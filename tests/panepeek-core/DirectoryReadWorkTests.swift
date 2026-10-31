import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1)))
struct DirectoryReadWorkTests {
    private func fixture(count: Int = 16) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-read-work-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for index in 0..<count { try Data().write(to: root.appendingPathComponent("item-\(index).txt")) }
        return root
    }

    @Test(arguments: [0, 15, 16, 17])
    func reportsOnlyActualTruncationAndLeavesNormalListingComplete(budget: Int) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let reads = Mutex(0)
        let listing = try await DirectoryListing.read(root, followingLinks: false, maximumEntries: budget, readAttributes: { url in
            reads.withLock { $0 += 1 }
            return try FileManager.default.attributesOfItem(atPath: url.path)
        })
        #expect(listing.entries.count == min(16, budget))
        #expect(listing.hasMoreEntries == (budget < 16))
        #expect(reads.withLock { $0 } == min(16, budget))
        let complete = try await DirectoryListing.read(root)
        #expect(complete.entries.count == 16 && !complete.hasMoreEntries)
    }

    @Test func emptyRootWithZeroBudgetIsCompleteButInvalidRootsStillFail() async throws {
        let root = try fixture(count: 0)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try await DirectorySearch.read(root, query: "absent", showHidden: false, maximumEntries: 0)
        #expect(result.entries.isEmpty && !result.reachedLimit)
        await #expect(throws: CocoaError.self) {
            try await DirectorySearch.read(root.appendingPathComponent("missing"), query: "absent", showHidden: false, maximumEntries: 0)
        }
    }

    @Test(arguments: [17, 20])
    func nestedReadsReceiveOnlyTheRemainingBudget(budget: Int) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let child = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        for index in 0..<16 { try Data().write(to: child.appendingPathComponent("item-\(index).txt")) }
        let reads = Mutex(0)
        let budgets = Mutex<[Int]>([])
        let result = try await DirectorySearch.read(root, query: "absent", showHidden: false, load: { directory, remaining in
            budgets.withLock { $0.append(remaining) }
            return try await DirectoryListing.read(directory, followingLinks: false, maximumEntries: remaining, readAttributes: { url in
                reads.withLock { $0 += 1 }
                return try FileManager.default.attributesOfItem(atPath: url.path)
            })
        }, maximumEntries: budget)
        #expect(result.entries.isEmpty && result.reachedLimit)
        #expect(reads.withLock { $0 } == budget)
        #expect(budgets.withLock { $0 } == (budget == 17 ? [17] : [20, 3]))
    }

    @Test func searchBudgetStopsMetadataWorkInAWideDirectory() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let reads = Mutex(0)
        let result = try await DirectorySearch.read(root, query: "absent", showHidden: false, load: { directory, budget in
            try await DirectoryListing.read(directory, followingLinks: false, maximumEntries: budget, readAttributes: { url in
                reads.withLock { $0 += 1 }
                return try FileManager.default.attributesOfItem(atPath: url.path)
            })
        }, maximumEntries: 2)
        #expect(result.entries.isEmpty && result.reachedLimit)
        #expect(reads.withLock { $0 } == 2)
    }

    @Test func cancellingAnActiveReadStopsMetadataAndRetainsAccessUntilItFinishes() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let reads = Mutex(0)
        let released = Mutex(false)
        var access: DirectoryAccess? = DirectoryAccess(root: root) { released.withLock { $0 = true } }
        let read = Task { [access] in
            defer { withExtendedLifetime(access) {} }
            return try await DirectoryListing.read(root, followingLinks: false, readAttributes: { url in
                reads.withLock { $0 += 1 }
                entered.signal()
                guard resume.wait(timeout: .now() + 5) == .success else { throw CocoaError(.fileReadUnknown) }
                return try FileManager.default.attributesOfItem(atPath: url.path)
            })
        }
        access = nil
        defer {
            for _ in 0..<16 { resume.signal() }
            read.cancel()
        }
        let waitForRead: @Sendable () -> Bool = { entered.wait(timeout: .now() + 5) == .success }
        let started = await Task.detached { waitForRead() }.value
        try #require(started)
        read.cancel()
        #expect(!released.withLock { $0 })
        // Unblock every possible read so a missing cancellation check fails without hanging teardown.
        for _ in 0..<16 { resume.signal() }
        await #expect(throws: CancellationError.self) { try await read.value }
        #expect(reads.withLock { $0 } == 1)
        #expect(released.withLock { $0 })
    }

    @Test func aPreCancelledReadPerformsNoEntryMetadataWork() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let reads = Mutex(0)
        let read = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await DirectoryListing.read(root, followingLinks: false, readAttributes: { url in
                reads.withLock { $0 += 1 }
                return try FileManager.default.attributesOfItem(atPath: url.path)
            })
        }
        await #expect(throws: CancellationError.self) { try await read.value }
        #expect(reads.withLock { $0 } == 0)
    }
}
