import Darwin
import AppKit
import AVFoundation
import AVKit
import Observation
import SwiftUI
import UniformTypeIdentifiers
import PanePeekCore

enum VideoPreview {
    enum Failure: LocalizedError, Equatable {
        case unsupported, noVideoTrack, nonRegularFile, nonLocal, symbolicLink
        var errorDescription: String? {
            switch self {
            case .symbolicLink: "Link previews are unavailable in this review build."
            case .unsupported: "This video is damaged or its format is not supported."
            case .noVideoTrack: "This file has no video track."
            case .nonRegularFile: "No video preview for this file type."
            case .nonLocal: "Video previews require a local file."
            }
        }
    }

    static func supports(_ item: DirectoryEntry?) -> Bool {
        // Prefer TypeScript text for extensions macOS also assigns to transport-stream video.
        guard let item, !item.isDirectory, !item.isPackage,
              !["ts", "mts"].contains(item.url.pathExtension.lowercased()),
              let type = UTType(filenameExtension: item.url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    struct Prepared {
        let item: AVPlayerItem
        var source: ScopedVideoSource? = nil
    }

    @MainActor static func prepare(_ selection: DetailsSelection, followingLinks: Bool) async throws -> Prepared {
        guard !followingLinks else { return Prepared(item: try await prepare(selection.item)) }
        guard supports(selection.item) else { throw Failure.unsupported }
        let open = Task.detached(priority: .userInitiated) {
            try ScopedVideoSource(item: selection.item, access: selection.access)
        }
        let source = try await withTaskCancellationHandler { try await open.value } onCancel: { open.cancel() }
        defer { withExtendedLifetime(source) {} }
        try Task.checkCancellation()
        let asset = AVURLAsset(url: source.url, options: [AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue])
        asset.resourceLoader.setDelegate(source, queue: source.queue)
        return Prepared(item: try await playerItem(for: asset), source: source)
    }

    @MainActor static func prepare(_ item: DirectoryEntry) async throws -> AVPlayerItem {
        guard item.url.isFileURL else { throw Failure.nonLocal }
        guard supports(item) else { throw Failure.unsupported }
        let check = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let descriptor = Darwin.open(item.url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
            guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            defer { Darwin.close(descriptor) }
            var attributes = stat()
            guard fstat(descriptor, &attributes) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw Failure.nonRegularFile }
        }
        try await withTaskCancellationHandler { try await check.value } onCancel: { check.cancel() }
        try Task.checkCancellation()
        let asset = AVURLAsset(url: item.url, options: [AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue])
        return try await playerItem(for: asset)
    }

    @MainActor private static func playerItem(for asset: AVURLAsset) async throws -> AVPlayerItem {
        return try await withTaskCancellationHandler {
            guard try await asset.load(.isPlayable), !(try await asset.load(.hasProtectedContent)) else { throw Failure.unsupported }
            guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else { throw Failure.noVideoTrack }
            try Task.checkCancellation()
            return AVPlayerItem(asset: asset)
        } onCancel: { asset.cancelLoading() }
    }
}

@MainActor @Observable final class VideoPreviewState {
    private(set) var selection: DetailsSelection?
    private(set) var player: AVPlayer?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var requestID = UUID()
    private var statusObservation: NSKeyValueObservation?
    private let prepare: @MainActor (DetailsSelection, Bool) async throws -> VideoPreview.Prepared
    private var source: ScopedVideoSource?

    init(prepare: (@MainActor (DirectoryEntry) async throws -> AVPlayerItem)? = nil) {
        if let prepare {
            self.prepare = { selection, _ in VideoPreview.Prepared(item: try await prepare(selection.item)) }
        } else {
            self.prepare = { try await VideoPreview.prepare($0, followingLinks: $1) }
        }
    }

    func load(_ selection: DetailsSelection?, followingLinks: Bool = true) async {
        defer { withExtendedLifetime(selection) {} }
        guard !Task.isCancelled else { return }
        stop()
        let request = requestID
        self.selection = VideoPreview.supports(selection?.item) ? selection : nil
        isLoading = self.selection != nil
        defer { if requestID == request { isLoading = false } }
        guard let selection = self.selection else { return }
        do {
            if !followingLinks && selection.item.isSymbolicLink { throw VideoPreview.Failure.symbolicLink }
            let prepared = try await prepare(selection, followingLinks)
            let item = prepared.item
            guard requestID == request, !Task.isCancelled else { return }
            let player = AVPlayer(playerItem: item)
            player.allowsExternalPlayback = false
            player.actionAtItemEnd = .pause
            player.pause()
            self.source = prepared.source
            self.player = player
            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                Task { @MainActor [weak self, weak item] in
                    guard let self, let item, self.player?.currentItem === item, item.status == .failed else { return }
                    let message = item.error?.localizedDescription ?? VideoPreview.Failure.unsupported.localizedDescription
                    self.releasePlayer()
                    self.errorMessage = "Couldn’t play this video. \(message)"
                }
            }
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t preview this video. \(error.localizedDescription)"
        }
    }

    func stop() {
        requestID = UUID()
        releasePlayer()
        selection = nil
        isLoading = false
        errorMessage = nil
    }

    private func releasePlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        source = nil
    }
}

struct VideoPreviewView: NSViewRepresentable {
    let player: AVPlayer
    let name: String
    var stopped: @MainActor (AVPlayer) -> Void = { _ in }

    func makeNSView(context: Context) -> VideoPlayerView {
        let view = VideoPlayerView(frame: .zero)
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        view.allowsPictureInPicturePlayback = false
        view.updatesNowPlayingInfoCenter = false
        return view
    }

    func updateNSView(_ view: VideoPlayerView, context: Context) { view.show(player, name: name, stopped: stopped) }
    static func dismantleNSView(_ view: VideoPlayerView, coordinator: ()) { view.detach() }
}

final class VideoPlayerView: AVPlayerView {
    private var stopped: ((AVPlayer) -> Void)?

    func show(_ player: AVPlayer, name: String, stopped: @escaping (AVPlayer) -> Void = { _ in }) {
        if self.player !== player {
            detach()
            self.player = player
        }
        self.stopped = stopped
        setAccessibilityLabel("Read-only video preview of \(name)")
    }

    func detach() {
        let previous = player
        player = nil
        previous?.pause()
        previous?.replaceCurrentItem(with: nil)
        let notify = stopped
        stopped = nil
        if let previous { notify?(previous) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
                                                   name: NSWindow.willCloseNotification, object: window)
        } else { detach() }
    }

    @objc private func windowWillClose(_ notification: Notification) { detach() }
}
