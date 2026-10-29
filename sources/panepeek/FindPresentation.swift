import AppKit
import SwiftUI

struct FindPresentation: Equatable, Sendable {
    enum Readiness: Equatable, Sendable { case unavailable, waiting, ready }
    struct Identity: Equatable, Sendable {
        let document: UUID
        let editing: Bool
    }

    let readiness: Readiness
    let identity: Identity?

    static let unavailable = Self(readiness: .unavailable, identity: nil)
    static func waiting(_ identity: Identity) -> Self { Self(readiness: .waiting, identity: identity) }
    static func ready(_ identity: Identity) -> Self { Self(readiness: .ready, identity: identity) }

    private init(readiness: Readiness, identity: Identity?) {
        self.readiness = readiness
        self.identity = identity
    }
}

/// Keeps readiness beside the presentation that owns it, including a renderer's terminal failure.
struct FindPresentationView: NSViewRepresentable {
    static let didChange = Notification.Name("PanePeekFindPresentationDidChange")
    let presentation: FindPresentation

    func makeNSView(context: Context) -> Marker { Marker(presentation) }
    func updateNSView(_ view: Marker, context: Context) { view.presentation = presentation }

    final class Marker: NSView {
        var presentation: FindPresentation {
            didSet { if presentation != oldValue { changed() } }
        }

        init(_ presentation: FindPresentation) {
            self.presentation = presentation
            super.init(frame: .zero)
            setAccessibilityElement(false)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); changed() }
        private func changed() {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: FindPresentationView.didChange, object: nil)
            }
        }
    }
}
