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

/// A monotonic clock whose sleepers wake only when a test advances past their deadline.
@MainActor final class ManualClock {
    private(set) var now = ContinuousClock.now
    private(set) var deadlines: [ContinuousClock.Instant] = []
    private var sleepers: [(deadline: ContinuousClock.Instant, wake: CheckedContinuation<Void, any Error>)] = []
    let start: ContinuousClock.Instant

    init() { start = now }

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        deadlines.append(deadline)
        try await withCheckedThrowingContinuation { sleepers.append((deadline, $0)) }
        try Task.checkCancellation()
    }

    var pending: Int { sleepers.count }

    /// Wakes sleepers whose deadline has passed; a large step models a late wake-up.
    func advance(by duration: Duration) {
        now = now.advanced(by: duration)
        let due = sleepers.filter { $0.deadline <= now }
        sleepers.removeAll { $0.deadline <= now }
        due.forEach { $0.wake.resume() }
    }

    func cancelAll() {
        sleepers.forEach { $0.wake.resume(throwing: CancellationError()) }
        sleepers.removeAll()
    }
}

@Suite(.timeLimit(.minutes(1))) @MainActor
struct ChangeWatchTests {
    private let folder = ChangeTarget.directory(URL(fileURLWithPath: "/example/folder"))

    /// Lets queued main-actor signal hops and the debounce task run.
    private func settle() async { for _ in 0..<20 { await Task.yield() } }

    private func watch(_ source: ControlledChangeSource, _ clock: ManualClock,
                       changes: @escaping @MainActor () -> Void) -> ChangeWatch {
        ChangeWatch(folder, source: source, quiet: .milliseconds(200), limit: .seconds(1),
                    now: { clock.now }, sleep: { try await clock.sleep(until: $0) }, changed: changes)
    }

    @Test func burstWithinQuietPeriodProducesOneChange() async {
        let source = ControlledChangeSource(), clock = ManualClock()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        for _ in 0..<50 { source.send(folder) }
        await settle()
        #expect(clock.deadlines == [clock.start + .milliseconds(200)])
        clock.advance(by: .milliseconds(200))
        await settle()
        #expect(changes == 1 && clock.pending == 0)
        withExtendedLifetime(watch) {}
    }

    @Test func quietPeriodRunsFromTheLatestSignal() async {
        let source = ControlledChangeSource(), clock = ManualClock()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        source.send(folder)
        await settle()
        clock.advance(by: .milliseconds(35))
        source.send(folder)
        await settle()
        clock.advance(by: .milliseconds(165))
        await settle()
        #expect(changes == 0 && clock.deadlines.last == clock.start + .milliseconds(235))
        clock.advance(by: .milliseconds(35))
        await settle()
        #expect(changes == 1 && clock.pending == 0)
        withExtendedLifetime(watch) {}
    }

    @Test func continuingSignalsAreCappedFromTheFirstSignal() async {
        let source = ControlledChangeSource(), clock = ManualClock()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        source.send(folder)
        await settle()
        for _ in 0..<9 {
            clock.advance(by: .milliseconds(100))
            await settle()
            source.send(folder)
            await settle()
            #expect(changes == 0)
        }
        clock.advance(by: .milliseconds(100))
        await settle()
        #expect(changes == 1)
        #expect(clock.deadlines.allSatisfy { $0 <= clock.start + .seconds(1) })
        source.send(folder)
        await settle()
        #expect(clock.deadlines.last == clock.now + .milliseconds(200))
        withExtendedLifetime(watch) {}
    }

    @Test func lateWakeUpNotifiesAtOnceWithoutExtendingTheCap() async {
        let source = ControlledChangeSource(), clock = ManualClock()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        source.send(folder)
        await settle()
        clock.advance(by: .milliseconds(150))
        source.send(folder)
        await settle()
        let requested = clock.deadlines.count
        clock.advance(by: .milliseconds(1140))
        await settle()
        #expect(changes == 1 && clock.pending == 0 && clock.deadlines.count == requested)
        withExtendedLifetime(watch) {}
    }

    @Test func cancellationReleasesTheSourceAndRejectsLateSignals() async {
        let source = ControlledChangeSource(), clock = ManualClock()
        var changes = 0
        let watch = watch(source, clock) { changes += 1 }
        #expect(watch.isReporting)
        source.send(folder)
        await settle()
        watch.cancel()
        #expect(source.isCancelled(folder) && !watch.isReporting)
        clock.advance(by: .seconds(1))
        source.send(folder)
        await settle()
        #expect(changes == 0 && clock.pending == 0)
    }

    @Test func releasingTheWatchReleasesItsRegistration() async {
        let source = ControlledChangeSource(), clock = ManualClock()
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
        let watch = watch(ControlledChangeSource(reports: false), ManualClock()) {}
        #expect(!watch.isReporting)
    }
}

@Suite struct FileSystemChangeFilterTests {
    private let root = "/Volumes/Work/Project"
    private func flags(_ values: Int...) -> FSEventStreamEventFlags { FSEventStreamEventFlags(values.reduce(0, |)) }

    @Test func directoryReportsItselfAndImmediateEntriesOnly() {
        let filter = FileSystemChangeSource.Filter(directory: root, caseSensitive: true)
        let modified = flags(kFSEventStreamEventFlagItemModified, kFSEventStreamEventFlagItemIsFile)
        #expect(filter.matches(root, flags: flags(kFSEventStreamEventFlagItemXattrMod)))
        #expect(filter.matches(root + "/notes.md", flags: modified))
        #expect(filter.matches(root + "/.hidden", flags: flags(kFSEventStreamEventFlagItemCreated)))
        #expect(!filter.matches(root + "/src/main.swift", flags: modified))
        #expect(!filter.matches(root + "-other/notes.md", flags: modified))
        #expect(!filter.matches("/Volumes/Work", flags: modified))
    }

    @Test func fileReportsOnlyItsOwnPath() {
        let filter = FileSystemChangeSource.Filter(file: root + "/notes.md", caseSensitive: true)
        let renamed = flags(kFSEventStreamEventFlagItemRenamed, kFSEventStreamEventFlagItemIsFile)
        #expect(filter.matches(root + "/notes.md", flags: renamed))
        #expect(!filter.matches(root + "/notes.md.sb-1234-abcd", flags: renamed))
        #expect(!filter.matches(root + "/other.md", flags: renamed))
        #expect(!filter.matches(root, flags: flags(kFSEventStreamEventFlagItemModified)))
    }

    @Test func caseInsensitiveVolumesMatchAnySpelling() {
        let modified = flags(kFSEventStreamEventFlagItemModified)
        let file = FileSystemChangeSource.Filter(file: root + "/Draft.TXT", caseSensitive: false)
        let directory = FileSystemChangeSource.Filter(directory: root, caseSensitive: false)
        #expect(file.matches(root + "/draft.txt", flags: modified))
        #expect(file.matches("/volumes/work/project/DRAFT.txt", flags: modified))
        #expect(!file.matches(root + "/draft.txt.sb-1234-abcd", flags: modified))
        #expect(directory.matches("/volumes/work/PROJECT/notes.md", flags: modified))
        #expect(!directory.matches("/volumes/work/PROJECT/src/notes.md", flags: modified))
    }

    @Test func caseSensitiveVolumesMatchExactSpellingOnly() {
        let modified = flags(kFSEventStreamEventFlagItemModified)
        let file = FileSystemChangeSource.Filter(file: root + "/Draft.TXT", caseSensitive: true)
        #expect(file.matches(root + "/Draft.TXT", flags: modified))
        #expect(!file.matches(root + "/draft.txt", flags: modified))
        #expect(!FileSystemChangeSource.Filter(directory: root, caseSensitive: true)
            .matches("/volumes/work/project/notes.md", flags: modified))
    }

    @Test(arguments: [kFSEventStreamEventFlagMustScanSubDirs, kFSEventStreamEventFlagUserDropped,
                      kFSEventStreamEventFlagKernelDropped, kFSEventStreamEventFlagRootChanged,
                      kFSEventStreamEventFlagUnmount])
    func lostOrRootEventsAlwaysReport(flag: Int) {
        let unrelated = "/Volumes/Elsewhere/file"
        #expect(FileSystemChangeSource.Filter(directory: root, caseSensitive: true).matches(unrelated, flags: flags(flag)))
        #expect(FileSystemChangeSource.Filter(file: root + "/notes.md", caseSensitive: true).matches(unrelated, flags: flags(flag)))
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

    static var temporaryVolumeIgnoresCase: Bool {
        (try? FileManager.default.temporaryDirectory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
            .volumeSupportsCaseSensitiveNames) == false
    }

    @Test(.enabled(if: temporaryVolumeIgnoresCase, "Requires a case-insensitive volume"))
    func fileFollowsCaseOnlyRenameAndCreationUnderAnotherSpelling() async throws {
        let folder = try fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("Draft.TXT"), renamed = folder.appendingPathComponent("draft.txt")
        try Data("one".utf8).write(to: original)
        let signals = Signals()
        let watched = try #require(FileSystemChangeSource().register(.file(original)) { signals.add() })
        defer { watched.cancel() }
        let absent = folder.appendingPathComponent("later.md")
        let created = try #require(FileSystemChangeSource().register(.file(absent)) { signals.add() })
        defer { created.cancel() }
        try await signals.drain()
        let steps: [() throws -> Void] = [
            { try FileManager.default.moveItem(at: original, to: renamed) },
            { try append("two", to: renamed) },
            { FileManager.default.createFile(atPath: folder.appendingPathComponent("LATER.MD").path, contents: nil) },
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
