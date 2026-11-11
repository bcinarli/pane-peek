import CoreServices
import Foundation
import Testing
@testable import PanePeekCore

/// Hands raw signals to a watch on demand and records registration lifetime.
final class ControlledChangeSource: ChangeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [ChangeTarget: @Sendable () -> Void] = [:]
    private var cancelled: [ChangeTarget] = []
    let reports: Bool

    init(reports: Bool = true) { self.reports = reports }

    func register(_ target: ChangeTarget, changed: @escaping @Sendable () -> Void) -> ChangeRegistration? {
        guard reports else { return nil }
        lock.withLock { handlers[target] = changed }
        return ChangeRegistration { [weak self] in self?.lock.withLock { self?.cancelled.append(target) } }
    }

    /// Delivers a signal as the platform would, even after cancellation.
    func send(_ target: ChangeTarget) { lock.withLock { handlers[target] }?() }
    func isCancelled(_ target: ChangeTarget) -> Bool { lock.withLock { cancelled.contains(target) } }
}

/// Lets a test release each debounce step explicitly.
@MainActor final class SteppedSleep {
    private(set) var requests: [Duration] = []
    private var waiting: [CheckedContinuation<Void, any Error>] = []

    func sleep(_ duration: Duration) async throws {
        requests.append(duration)
        try await withCheckedThrowingContinuation { waiting.append($0) }
        try Task.checkCancellation()
    }

    var pending: Int { waiting.count }

    func advance() {
        guard !waiting.isEmpty else { return }
        waiting.removeFirst().resume()
    }

    func cancelAll() {
        waiting.forEach { $0.resume(throwing: CancellationError()) }
        waiting.removeAll()
    }
}

@Suite(.timeLimit(.minutes(1))) @MainActor
struct ChangeWatchTests {
    private let folder = ChangeTarget.directory(URL(fileURLWithPath: "/example/folder"))

    /// Lets queued main-actor signal hops and the debounce task run.
    private func settle() async { for _ in 0..<20 { await Task.yield() } }

    private func watch(_ source: ControlledChangeSource, _ clock: SteppedSleep,
                       changes: @escaping @MainActor () -> Void) -> ChangeWatch {
        ChangeWatch(folder, source: source, quiet: .milliseconds(200), limit: .seconds(1),
                    sleep: { try await clock.sleep($0) }, changed: changes)
    }

    @Test func burstWithinQuietPeriodProducesOneChange() async {
        let source = ControlledChangeSource(), clock = SteppedSleep()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        for _ in 0..<50 { source.send(folder) }
        await settle()
        #expect(clock.requests == [.milliseconds(200)])
        clock.advance()
        await settle()
        #expect(changes == 1 && clock.pending == 0)
        withExtendedLifetime(watch) {}
    }

    @Test func signalsDuringQuietPeriodExtendItUntilTheLatencyLimit() async {
        let source = ControlledChangeSource(), clock = SteppedSleep()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        source.send(folder)
        await settle()
        for _ in 0..<4 {
            source.send(folder)
            await settle()
            clock.advance()
            await settle()
            #expect(changes == 0)
        }
        source.send(folder)
        await settle()
        clock.advance()
        await settle()
        // Five 200 ms steps reach the 1 s bound despite continuing signals.
        #expect(changes == 1 && clock.requests.count == 5)
        source.send(folder)
        await settle()
        #expect(clock.pending == 1)
        clock.advance()
        await settle()
        #expect(changes == 2)
        withExtendedLifetime(watch) {}
    }

    @Test func cancellationReleasesTheSourceAndRejectsLateSignals() async {
        let source = ControlledChangeSource(), clock = SteppedSleep()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        #expect(watch.isReporting)
        source.send(folder)
        await settle()
        watch.cancel()
        #expect(source.isCancelled(folder) && !watch.isReporting)
        clock.advance()
        source.send(folder)
        await settle()
        #expect(changes == 0 && clock.pending == 0)
    }

    @Test func releasingTheWatchReleasesItsRegistration() async {
        let source = ControlledChangeSource(), clock = SteppedSleep()
        var changes = 0
        var watch: ChangeWatch? = watch(source, clock) { changes += 1 }
        source.send(folder)
        await settle()
        watch = nil
        #expect(source.isCancelled(folder))
        clock.cancelAll()
        source.send(folder)
        await settle()
        #expect(changes == 0 && watch == nil)
    }

    @Test func locationsThatCannotReportStayUnwatched() {
        let watch = watch(ControlledChangeSource(reports: false), SteppedSleep()) {}
        #expect(!watch.isReporting)
    }
}

@Suite struct FileSystemChangeFilterTests {
    private let root = "/Volumes/Work/Project"
    private func flags(_ values: Int...) -> FSEventStreamEventFlags { FSEventStreamEventFlags(values.reduce(0, |)) }

    @Test func directoryReportsItselfAndImmediateEntriesOnly() {
        let filter = FileSystemChangeSource.Filter(directory: root)
        let modified = flags(kFSEventStreamEventFlagItemModified, kFSEventStreamEventFlagItemIsFile)
        #expect(filter.matches(root, flags: flags(kFSEventStreamEventFlagItemXattrMod)))
        #expect(filter.matches(root + "/notes.md", flags: modified))
        #expect(filter.matches(root + "/.hidden", flags: flags(kFSEventStreamEventFlagItemCreated)))
        #expect(!filter.matches(root + "/src/main.swift", flags: modified))
        #expect(!filter.matches(root + "-other/notes.md", flags: modified))
        #expect(!filter.matches("/Volumes/Work", flags: modified))
    }

    @Test func fileReportsOnlyItsOwnPath() {
        let filter = FileSystemChangeSource.Filter(file: root + "/notes.md")
        let renamed = flags(kFSEventStreamEventFlagItemRenamed, kFSEventStreamEventFlagItemIsFile)
        #expect(filter.matches(root + "/notes.md", flags: renamed))
        #expect(!filter.matches(root + "/notes.md.sb-1234-abcd", flags: renamed))
        #expect(!filter.matches(root + "/other.md", flags: renamed))
        #expect(!filter.matches(root, flags: flags(kFSEventStreamEventFlagItemModified)))
    }

    @Test(arguments: [kFSEventStreamEventFlagMustScanSubDirs, kFSEventStreamEventFlagUserDropped,
                      kFSEventStreamEventFlagKernelDropped, kFSEventStreamEventFlagRootChanged,
                      kFSEventStreamEventFlagUnmount])
    func lostOrRootEventsAlwaysReport(flag: Int) {
        let unrelated = "/Volumes/Elsewhere/file"
        #expect(FileSystemChangeSource.Filter(directory: root).matches(unrelated, flags: flags(flag)))
        #expect(FileSystemChangeSource.Filter(file: root + "/notes.md").matches(unrelated, flags: flags(flag)))
    }
}

/// Real-filesystem checks for the selected source; positive outcomes only, because absence is timing-dependent.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct FileSystemChangeSourceTests {
    private final class Signals: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func add() { lock.withLock { count += 1 } }
        var value: Int { lock.withLock { count } }
        /// Lets events buffered from fixture setup arrive before steps take their baseline.
        func drain() async throws { try await Task.sleep(for: .milliseconds(400)) }
        func wait(beyond previous: Int) async throws {
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while value <= previous {
                try #require(ContinuousClock.now < deadline, "No change signal arrived")
                try await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ChangeSource-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func append(_ text: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    @Test func directoryReportsCreationInPlaceWritesMetadataRenameAndRemoval() async throws {
        let folder = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("notes.md")
        try Data("one".utf8).write(to: file)
        let signals = Signals()
        let registration = try #require(FileSystemChangeSource().register(.directory(folder)) { signals.add() })
        defer { registration.cancel() }
        try await signals.drain()
        let steps: [() throws -> Void] = [
            { try append("two", to: file) },
            { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) },
            { FileManager.default.createFile(atPath: folder.appendingPathComponent("new.txt").path, contents: nil) },
            { try FileManager.default.moveItem(at: file, to: folder.appendingPathComponent("renamed.md")) },
            { try FileManager.default.removeItem(at: folder.appendingPathComponent("new.txt")) },
        ]
        for step in steps {
            let before = signals.value
            try step()
            try await signals.wait(beyond: before)
        }
    }

    @Test func fileKeepsReportingAfterAtomicReplacementAndReportsRemoval() async throws {
        let folder = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Draft.TXT")
        try Data("one".utf8).write(to: file)
        let signals = Signals()
        // Watch through a differently cased, unresolved path to exercise canonicalisation.
        let alias = URL(fileURLWithPath: folder.path).appendingPathComponent("draft.txt")
        let registration = try #require(FileSystemChangeSource().register(.file(alias)) { signals.add() })
        defer { registration.cancel() }
        try await signals.drain()
        let steps: [() throws -> Void] = [
            { try Data("two".utf8).write(to: file, options: .atomic) },
            { try append("three", to: file) },
            { try FileManager.default.removeItem(at: file) },
        ]
        for step in steps {
            let before = signals.value
            try step()
            try await signals.wait(beyond: before)
        }
    }

    @Test func unreadableLocationCannotRegister() {
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/folder")
        #expect(FileSystemChangeSource().register(.directory(missing)) {} == nil)
    }
}
