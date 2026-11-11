import CoreServices
import Foundation
import Synchronization

/// A location whose external changes its consumer rereads.
public enum ChangeTarget: Hashable, Sendable {
    /// The directory itself and its immediate entries, including their metadata; nested folders are excluded.
    case directory(URL)
    /// One file by path, so atomic replacement, rename and removal keep reporting.
    case file(URL)
}

/// Keeps a platform change registration alive until cancelled or released.
public final class ChangeRegistration: Sendable {
    private let action: Mutex<(@Sendable () -> Void)?>

    public init(cancel: @escaping @Sendable () -> Void) { action = Mutex(cancel) }

    public func cancel() { action.withLock { $0.take() }?() }

    deinit { cancel() }
}

/// Reports raw, uncoalesced change signals on an arbitrary queue.
public protocol ChangeSource: Sendable {
    /// Returns nil when the location cannot report changes; callers keep manual Refresh.
    func register(_ target: ChangeTarget, changed: @escaping @Sendable () -> Void) -> ChangeRegistration?
}

/// Coalesces one target's raw signals into bounded, debounced change notifications on the main actor.
@MainActor public final class ChangeWatch {
    public let target: ChangeTarget
    public var isReporting: Bool { registration != nil }
    private let quiet: Duration
    private let limit: Duration
    private let now: @MainActor () -> ContinuousClock.Instant
    private let sleep: @MainActor (ContinuousClock.Instant) async throws -> Void
    private let changed: @MainActor () -> Void
    private var registration: ChangeRegistration?
    private var first: ContinuousClock.Instant?
    private var latest: ContinuousClock.Instant?
    private var pending: Task<Void, Never>?

    /// The earlier of the quiet deadline after the latest signal and the cap after the first.
    private var deadline: ContinuousClock.Instant? {
        guard let first, let latest else { return nil }
        return min(latest + quiet, first + limit)
    }

    /// Notifies once signals have been quiet for `quiet`, and no later than `limit` after the first unreported
    /// signal, measured on a monotonic clock.
    public init(_ target: ChangeTarget, source: any ChangeSource = FileSystemChangeSource(),
                quiet: Duration = .milliseconds(200), limit: Duration = .seconds(1),
                now: (@MainActor () -> ContinuousClock.Instant)? = nil,
                sleep: (@MainActor (ContinuousClock.Instant) async throws -> Void)? = nil,
                changed: @escaping @MainActor () -> Void) {
        self.target = target
        self.quiet = quiet
        self.limit = limit
        self.now = now ?? { .now }
        self.sleep = sleep ?? { try await Task.sleep(until: $0, clock: .continuous) }
        self.changed = changed
        registration = source.register(target) { [weak self] in
            Task { @MainActor in self?.signal() }
        }
    }

    deinit {
        pending?.cancel()
        registration?.cancel()
    }

    /// Stops reporting; signals already queued from the platform are rejected.
    public func cancel() {
        registration?.cancel()
        registration = nil
        pending?.cancel()
        pending = nil
        first = nil
        latest = nil
    }

    private func signal() {
        guard registration != nil else { return }
        let time = now()
        latest = time
        if first == nil { first = time }
        guard pending == nil else { return }
        let sleep = sleep, now = now
        pending = Task { [weak self] in
            while let deadline = self?.deadline {
                do { try await sleep(deadline) } catch { return }
                guard let self, !Task.isCancelled, self.registration != nil, let current = self.deadline else { return }
                // A late wake-up notifies at once; a signal during the sleep moves the quiet deadline.
                if now() >= current {
                    self.pending = nil
                    self.first = nil
                    self.latest = nil
                    self.changed()
                    return
                }
            }
        }
    }
}

/// FSEvents with file-level events: path-based, so it follows atomic replacement and reports in-place
/// writes and metadata changes that a directory file descriptor source misses.
public struct FileSystemChangeSource: ChangeSource {
    /// Platform latency before FSEvents delivers a batch; ChangeWatch applies the user-facing debounce.
    private static let latency: CFTimeInterval = 0.1
    private static let queue = DispatchQueue(label: "PanePeek.FileSystemChangeSource", qos: .utility)
    private static let onQueue: DispatchSpecificKey<Bool> = {
        let key = DispatchSpecificKey<Bool>()
        queue.setSpecific(key: key, value: true)
        return key
    }()

    struct Filter: Sendable {
        private let directory: String?
        private let file: String?
        private let caseSensitive: Bool
        private static let lost = FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs
            | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
            | kFSEventStreamEventFlagRootChanged | kFSEventStreamEventFlagUnmount)

        init(directory: String, caseSensitive: Bool) { (self.directory, file, self.caseSensitive) = (directory, nil, caseSensitive) }
        init(file: String, caseSensitive: Bool) { (directory, self.file, self.caseSensitive) = (nil, file, caseSensitive) }

        func matches(_ path: String, flags: FSEventStreamEventFlags) -> Bool {
            if flags & Self.lost != 0 { return true }
            if let file { return same(path, file) }
            guard let directory else { return false }
            return same(path, directory) || same((path as NSString).deletingLastPathComponent, directory)
        }

        /// Events carry the current on-disk spelling, which a case-only rename or creation can change.
        private func same(_ path: String, _ target: String) -> Bool {
            caseSensitive ? path == target : path.caseInsensitiveCompare(target) == .orderedSame
        }
    }

    private final class Context: @unchecked Sendable {
        let filter: Filter
        let changed: @Sendable () -> Void
        init(_ filter: Filter, _ changed: @escaping @Sendable () -> Void) { self.filter = filter; self.changed = changed }
    }

    private final class Stream: @unchecked Sendable {
        let reference: FSEventStreamRef
        init(_ reference: FSEventStreamRef) { self.reference = reference }
    }

    public init() {}

    public func register(_ target: ChangeTarget, changed: @escaping @Sendable () -> Void) -> ChangeRegistration? {
        let root: String, filter: Filter
        switch target {
        case .directory(let url):
            guard let path = Self.canonicalPath(url) else { return nil }
            (root, filter) = (path, Filter(directory: path, caseSensitive: Self.isCaseSensitive(path)))
        case .file(let url):
            // An existing file resolves fully; a missing one keeps its name under the resolved parent.
            guard let parent = Self.canonicalPath(url.deletingLastPathComponent()) else { return nil }
            let path = Self.canonicalPath(url) ?? (parent as NSString).appendingPathComponent(url.lastPathComponent)
            root = (path as NSString).deletingLastPathComponent
            filter = Filter(file: path, caseSensitive: Self.isCaseSensitive(root))
        }
        let info = Unmanaged.passRetained(Context(filter, changed)).toOpaque()
        var context = FSEventStreamContext(version: 0, info: info, retain: nil,
                                           release: { Unmanaged<Context>.fromOpaque($0!).release() },
                                           copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagWatchRoot)
        guard let reference = FSEventStreamCreate(kCFAllocatorDefault, Self.callback, &context, [root] as CFArray,
                                                  FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                                  Self.latency, flags) else {
            Unmanaged<Context>.fromOpaque(info).release()
            return nil
        }
        let stream = Stream(reference)
        FSEventStreamSetDispatchQueue(reference, Self.queue)
        guard FSEventStreamStart(reference) else {
            FSEventStreamInvalidate(reference)
            FSEventStreamRelease(reference)
            return nil
        }
        return ChangeRegistration {
            // Tear down on the delivery queue so no callback is mid-flight once this returns.
            let teardown = {
                FSEventStreamStop(stream.reference)
                FSEventStreamInvalidate(stream.reference)
                FSEventStreamRelease(stream.reference)
            }
            if DispatchQueue.getSpecific(key: Self.onQueue) == true { teardown() } else { Self.queue.sync(execute: teardown) }
        }
    }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        guard let info else { return }
        let context = Unmanaged<Context>.fromOpaque(info).takeUnretainedValue()
        let paths = unsafeBitCast(paths, to: NSArray.self)
        for index in 0..<count {
            guard let path = paths[index] as? String else { continue }
            if context.filter.matches(path, flags: flags[index]) { context.changed(); return }
        }
    }

    /// An unknown volume matches case-insensitively, which can over-report but never misses a change.
    private static func isCaseSensitive(_ path: String) -> Bool {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
        return values?.volumeSupportsCaseSensitiveNames == true
    }

    /// FSEvents reports resolved, on-disk paths, for example `/private/var` rather than `/var`.
    static func canonicalPath(_ url: URL) -> String? {
        guard let resolved = realpath(url.path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
