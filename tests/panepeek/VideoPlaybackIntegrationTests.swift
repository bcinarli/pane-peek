import AppKit
import AVFoundation
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct VideoPlaybackIntegrationTests {
    @Test func scopedVideoDisplaysPausedPlaysAndReleasesReplacedAndClosedItems() async throws {
        _ = NSApplication.shared
        let url = try #require(Bundle.module.url(forResource: "preview", withExtension: "mov", subdirectory: "fixtures"))
        let item = DirectoryEntry(url: url, isDirectory: false)
        let state = VideoPreviewState()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Video preview integration"
        defer { window.orderOut(nil); window.close(); state.stop() }

        await state.load(DetailsSelection(item: item, listingRevision: UUID()), followingLinks: false)
        let player = try #require(state.player, Comment(rawValue: state.errorMessage ?? "No scoped video player"))
        let host = NSHostingView(rootView: preview(player, state: state, name: item.name))
        window.contentView = host
        window.orderFront(nil)
        try await ready(player, in: host)
        #expect(player.rate == 0)

        let initialTime = player.currentTime().seconds
        try #require(initialTime.isFinite)
        player.play()
        try await wait("Scoped video did not advance after Play") { player.currentTime().seconds > initialTime }
        player.pause()
        #expect(player.rate == 0)

        await state.load(DetailsSelection(item: item, listingRevision: UUID()), followingLinks: false)
        let replacement = try #require(state.player)
        #expect(replacement !== player && player.currentItem == nil)
        host.rootView = preview(replacement, state: state, name: item.name)
        try await ready(replacement, in: host)
        #expect(replacement.rate == 0)
        window.close()
        #expect(state.player == nil && state.selection == nil && replacement.currentItem == nil)
    }

    private func preview(_ player: AVPlayer, state: VideoPreviewState, name: String) -> VideoPreviewView {
        VideoPreviewView(player: player, name: name, stopped: { stopped in
            if state.player === stopped { state.stop() }
        })
    }

    private func ready(_ player: AVPlayer, in host: NSView) async throws {
        try await wait("Scoped video did not become ready with a displayable first frame") {
            host.layoutSubtreeIfNeeded()
            guard let view = playerView(in: host), view.player === player else { return false }
            return player.status == .readyToPlay && player.currentItem?.status == .readyToPlay && view.isReadyForDisplay
        }
    }

    private func wait(_ message: String, until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), Comment(rawValue: message))
    }

    private func playerView(in view: NSView) -> VideoPlayerView? {
        if let player = view as? VideoPlayerView { return player }
        return view.subviews.lazy.compactMap { playerView(in: $0) }.first
    }
}
