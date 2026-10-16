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
        case unsupported, noVideoTrack, nonRegularFile, nonLocal
        var errorDescription: String? {
            switch self {
            case .unsupported: "This video is damaged or its format is not supported."
            case .noVideoTrack: "This file has no video track."
            case .nonRegularFile: "No video preview for this file type."
            case .nonLocal: "Video previews require a local file."
            }
        }
    }

    static func supports(_ item: DirectoryEntry?) -> Bool {
        guard let item, !item.isDirectory, !item.isPackage,
              let type = UTType(filenameExtension: item.url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
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
    private let prepare: @MainActor (DirectoryEntry) async throws -> AVPlayerItem

    init(prepare: @escaping @MainActor (DirectoryEntry) async throws -> AVPlayerItem = VideoPreview.prepare) {
        self.prepare = prepare
    }

    func load(_ selection: DetailsSelection?) async {
        guard !Task.isCancelled else { return }
        stop()
        let request = requestID
        self.selection = VideoPreview.supports(selection?.item) ? selection : nil
        isLoading = self.selection != nil
        defer { if requestID == request { isLoading = false } }
        guard let selection = self.selection else { return }
        do {
            let item = try await prepare(selection.item)
            guard requestID == request, !Task.isCancelled else { return }
            let player = AVPlayer(playerItem: item)
            player.allowsExternalPlayback = false
            player.actionAtItemEnd = .pause
            player.pause()
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
    }
}

struct VideoPreviewView: NSViewRepresentable {
    let player: AVPlayer
    let name: String

    func makeNSView(context: Context) -> VideoPlayerView {
        let view = VideoPlayerView(frame: .zero)
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        view.allowsPictureInPicturePlayback = false
        view.updatesNowPlayingInfoCenter = false
        return view
    }

    func updateNSView(_ view: VideoPlayerView, context: Context) { view.show(player, name: name) }
    static func dismantleNSView(_ view: VideoPlayerView, coordinator: ()) { view.detach() }
}

final class VideoPlayerView: AVPlayerView {
    func show(_ player: AVPlayer, name: String) {
        if self.player !== player {
            detach()
            self.player = player
        }
        setAccessibilityLabel("Read-only video preview of \(name)")
    }

    func detach() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
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
