import AppKit
import AVFoundation
import AVKit
import Darwin
import Testing
import Synchronization
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct VideoPreviewTests {
    @Test func sandboxPreparationRejectsListedAndReplacedLinks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-video-link-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("linked.mov")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: try fixture().url)
        for listedAsLink in [false, true] {
            let item = DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: listedAsLink)
            await #expect(throws: VideoPreview.Failure.symbolicLink) { try await VideoPreview.prepare(selection(item), followingLinks: false) }
        }
    }

    @Test func sandboxSourceReadsBoundedOriginalBytesAfterPathReplacement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-video-source-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("selected.mov")
        let original = Data((0..<(ScopedVideoSource.chunkSize * 2 + 5)).map { UInt8($0 % 251) })
        try original.write(to: url)
        let source = try ScopedVideoSource(item: DirectoryEntry(url: url, isDirectory: false), access: nil)
        try FileManager.default.moveItem(at: url, to: root.appendingPathComponent("original.mov"))
        let replacement = root.appendingPathComponent("replacement.mov")
        try Data("replacement must stay unread".utf8).write(to: replacement)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: replacement)
        #expect(try source.read(offset: 0, maximumLength: Int.max) == original.prefix(ScopedVideoSource.chunkSize))
        let offset = ScopedVideoSource.chunkSize + 3
        #expect(try source.read(offset: Int64(offset), maximumLength: Int.max) == original[offset..<(offset + ScopedVideoSource.chunkSize)])
        #expect(try source.read(offset: Int64(original.count), maximumLength: Int.max).isEmpty)
        #expect(try source.read(offset: Int64.max, maximumLength: Int.max).isEmpty)
        #expect(throws: POSIXError(.EINVAL)) { try source.read(offset: -1, maximumLength: 1) }
        #expect(throws: POSIXError(.EINVAL)) { try source.read(offset: 0, maximumLength: -1) }
    }

    @Test func sandboxPlaybackRetainsAccessUntilItsOwningWindowCloses() async throws {
        _ = NSApplication.shared
        let (releases, release) = AsyncStream<Void>.makeStream()
        let released = Mutex(0)
        let state = VideoPreviewState()
        let item = try fixture()
        await state.load(DetailsSelection(item: item, listingRevision: UUID(), access: DirectoryAccess(root: item.url.deletingLastPathComponent()) {
            released.withLock { $0 += 1 }
            release.yield(())
            release.finish()
        }), followingLinks: false)
        let player = try #require(state.player, Comment(rawValue: state.errorMessage ?? "No sandbox player"))
        #expect(player.rate == 0 && released.withLock { $0 } == 0)
        #expect(!player.allowsExternalPlayback)
        let current = try #require(player.currentItem)
        let (statuses, status) = AsyncStream<AVPlayerItem.Status>.makeStream()
        let observation = current.observe(\.status, options: [.initial, .new]) { item, _ in
            if item.status != .unknown { status.yield(item.status); status.finish() }
        }
        defer { observation.invalidate() }
        let readinessTimeout = Task {
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            Issue.record("Sandbox video did not become ready for playback")
            status.finish()
        }
        defer { readinessTimeout.cancel() }
        var statusIterator = statuses.makeAsyncIterator()
        #expect(await statusIterator.next() == .readyToPlay)
        let owner = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let other = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        other.isReleasedWhenClosed = false
        defer { owner.close(); other.close(); state.stop() }
        let view = VideoPlayerView(frame: .zero)
        view.show(player, name: item.name, stopped: { stopped in
            if state.player === stopped { state.stop() }
        })
        owner.contentView = view
        other.close()
        #expect(state.player === player && released.withLock { $0 } == 0)
        owner.close()
        #expect(state.player == nil && state.selection == nil && player.currentItem == nil)
        let timeout = Task {
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            Issue.record("Video access was not released after window teardown")
            release.finish()
        }
        defer { timeout.cancel() }
        var iterator = releases.makeAsyncIterator()
        _ = await iterator.next()
        #expect(released.withLock { $0 } == 1)
    }

    @Test func stoppedPreparationRetainsAccessUntilItsPendingReaderFinishes() async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<AVPlayerItem, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let released = Mutex(0)
        let state = VideoPreviewState(prepare: { _ in try await withCheckedThrowingContinuation { source.yield($0) } })
        let item = try fixture()
        let pending = Task {
            await state.load(DetailsSelection(item: item, listingRevision: UUID(), access: DirectoryAccess(root: item.url.deletingLastPathComponent()) {
                released.withLock { $0 += 1 }
            }), followingLinks: false)
        }
        let read = try #require(await iterator.next())
        pending.cancel()
        state.stop()
        #expect(released.withLock { $0 } == 0)
        read.resume(returning: AVPlayerItem(url: item.url))
        await pending.value
        #expect(released.withLock { $0 } == 1 && state.player == nil && state.errorMessage == nil)
    }

    @Test func sandboxCorruptAndAudioOnlyMediaNeverCreatePlayers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-video-corrupt-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("corrupt.mov")
        try Data("not a movie".utf8).write(to: url)
        let state = VideoPreviewState()
        await state.load(selection(DirectoryEntry(url: url, isDirectory: false)), followingLinks: false)
        #expect(state.player == nil && state.errorMessage != nil && !state.isLoading)
        let audio = try #require(Bundle.module.url(forResource: "audio-only", withExtension: "mp4", subdirectory: "fixtures"))
        await #expect(throws: VideoPreview.Failure.noVideoTrack) {
            try await VideoPreview.prepare(selection(DirectoryEntry(url: audio, isDirectory: false)), followingLinks: false)
        }
    }

    @Test(arguments: ["ts", "TS", "mts", "MTS", "mjs", "MJS"])
    func scriptFilesOpenAsEditableHighlightedText(fileExtension: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-typescript-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("example." + fileExtension)
        let text = "export const title = \"PanePeek\";\n"
        try Data(text.utf8).write(to: url)
        let item = DirectoryEntry(url: url, isDirectory: false)
        try #require(!VideoPreview.supports(item))

        let preview = PreviewState()
        await preview.load(selection(item))
        #expect(preview.preview == .text(text))
        #expect(preview.canEdit)
        #expect(preview.tokens.contains { $0.range == NSRange(location: 0, length: 6) && $0.kind == .keyword })
    }

    @Test(arguments: ["mp4", "MOV", "m2ts"])
    func videoFormatsRetainMediaClassification(fileExtension: String) {
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/preview/movie." + fileExtension), isDirectory: false)
        #expect(VideoPreview.supports(item))
    }

    @Test func realVideoStartsPausedAndSelectionReplacementReleasesItsItem() async throws {
        let item = try fixture()
        let state = VideoPreviewState()
        await state.load(selection(item))
        let player = try #require(state.player)
        #expect(player.rate == 0 && player.currentItem != nil)
        #expect(!player.allowsExternalPlayback && player.actionAtItemEnd == .pause)
        await state.load(selection(item))
        let refreshed = try #require(state.player)
        #expect(refreshed !== player && refreshed.rate == 0 && player.currentItem == nil)
        await state.load(selection(DirectoryEntry(url: item.url.deletingPathExtension().appendingPathExtension("png"), isDirectory: false)))
        #expect(refreshed.rate == 0 && refreshed.currentItem == nil)
        #expect(state.selection == nil && state.player == nil && state.errorMessage == nil)
    }

    @Test func corruptMissingNonLocalAndSpecialFilesNeverCreatePlayers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-video-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bad = root.appendingPathComponent("corrupt.mov")
        try Data("not a movie".utf8).write(to: bad)
        let state = VideoPreviewState()
        for url in [bad, root.appendingPathComponent("missing.mov")] {
            await state.load(selection(DirectoryEntry(url: url, isDirectory: false)))
            #expect(state.player == nil && state.errorMessage != nil && !state.isLoading)
        }
        let fifo = root.appendingPathComponent("pipe.mov")
        try #require(mkfifo(fifo.path, 0o600) == 0)
        await #expect(throws: VideoPreview.Failure.nonRegularFile) {
            try await VideoPreview.prepare(DirectoryEntry(url: fifo, isDirectory: false))
        }
        await #expect(throws: VideoPreview.Failure.nonLocal) {
            try await VideoPreview.prepare(DirectoryEntry(url: URL(string: "https://example.invalid/movie.mov")!, isDirectory: false))
        }
        let audio = try #require(Bundle.module.url(forResource: "audio-only", withExtension: "mp4", subdirectory: "fixtures"))
        await #expect(throws: VideoPreview.Failure.noVideoTrack) {
            try await VideoPreview.prepare(DirectoryEntry(url: audio, isDirectory: false))
        }
        let link = root.appendingPathComponent("linked.mov")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: try fixture().url)
        _ = try await VideoPreview.prepare(DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: true))
        #expect(VideoPreview.supports(DirectoryEntry(url: root.appendingPathComponent("UPPER.MP4"), isDirectory: false)))
        #expect(!VideoPreview.supports(DirectoryEntry(url: bad, isDirectory: true)))
        #expect(!VideoPreview.supports(DirectoryEntry(url: bad, isDirectory: false, isPackage: true)))
    }

    @Test(arguments: [false, true], [false, true])
    func staleSuccessOrFailureCannotReplaceNewSelectionOrStoppedPreview(olderFails: Bool, stopped: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<AVPlayerItem, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = VideoPreviewState(prepare: { _ in try await withCheckedThrowingContinuation { source.yield($0) } })
        let item = try fixture()
        let older = Task { await state.load(selection(item)) }
        let oldRead = try #require(await iterator.next())
        let latestSelection = selection(item)
        let latest = Task { await state.load(latestSelection) }
        let latestRead = try #require(await iterator.next())
        let latestItem = AVPlayerItem(url: item.url)
        latestRead.resume(returning: latestItem)
        await latest.value
        if stopped { state.stop() }
        if olderFails { oldRead.resume(throwing: CocoaError(.fileReadNoPermission)) }
        else { oldRead.resume(returning: AVPlayerItem(url: item.url)) }
        await older.value
        #expect(state.selection == (stopped ? nil : latestSelection))
        #expect(stopped ? state.player == nil : state.player?.currentItem === latestItem)
        #expect(!state.isLoading && state.errorMessage == nil)
        state.stop()
    }

    @Test func cancelledPreparationCannotPublishAPlayer() async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<AVPlayerItem, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = VideoPreviewState(prepare: { _ in try await withCheckedThrowingContinuation { source.yield($0) } })
        let item = try fixture()
        let pending = Task { await state.load(selection(item)) }
        let read = try #require(await iterator.next())
        pending.cancel()
        read.resume(returning: AVPlayerItem(url: item.url))
        await pending.value
        #expect(state.player == nil && state.errorMessage == nil && !state.isLoading)
    }

    @Test func nativeViewRetainsSamePlayerAcrossUpdatesAndReleasesReplacedPlayer() throws {
        _ = NSApplication.shared
        let item = try fixture()
        let first = AVPlayer(playerItem: AVPlayerItem(url: item.url))
        let second = AVPlayer(playerItem: AVPlayerItem(url: item.url))
        let view = VideoPlayerView(frame: .zero)
        view.show(first, name: item.name)
        let original = first.currentItem
        view.show(first, name: item.name)
        #expect(first.currentItem === original)
        view.show(second, name: item.name)
        #expect(first.currentItem == nil && first.rate == 0 && view.player === second)
        view.detach()
        #expect(second.currentItem == nil && view.player == nil)
    }

    @Test func onlyClosingTheOwningWindowReleasesPlayback() throws {
        _ = NSApplication.shared
        let owner = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let other = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        other.isReleasedWhenClosed = false
        defer { owner.close(); other.close() }
        let view = VideoPlayerView(frame: .zero)
        let player = AVPlayer(playerItem: AVPlayerItem(url: try fixture().url))
        view.show(player, name: "movie")
        owner.contentView = view
        other.close()
        #expect(view.player === player && player.currentItem != nil)
        owner.close()
        #expect(view.player == nil && player.currentItem == nil && player.rate == 0)
    }

    @Test func latePlaybackFailureReleasesPlayerAndRetainsTheSelectedItem() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-late-video-" + UUID().uuidString + ".mov")
        try Data("corrupt media".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let state = VideoPreviewState(prepare: { AVPlayerItem(url: $0.url) })
        let selected = selection(DirectoryEntry(url: url, isDirectory: false))
        await state.load(selected)
        let player = state.player
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while state.errorMessage == nil && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(state.errorMessage != nil && state.player == nil && state.selection == selected)
        #expect(player?.currentItem == nil && !state.isLoading)
        state.stop()
    }

    private func fixture() throws -> DirectoryEntry {
        DirectoryEntry(url: try #require(Bundle.module.url(forResource: "preview", withExtension: "mov", subdirectory: "fixtures")), isDirectory: false)
    }
    private func selection(_ item: DirectoryEntry) -> DetailsSelection {
        DetailsSelection(item: item, listingRevision: UUID())
    }
}
