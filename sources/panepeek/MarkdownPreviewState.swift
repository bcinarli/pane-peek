import AppKit
import Darwin
import Foundation
import Observation
import PanePeekCore

@MainActor @Observable final class MarkdownPreviewState {
    struct Source: Equatable, Sendable {
        let documentID: UUID
        let text: String
        let baseURL: URL?

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            guard lhs.documentID == rhs.documentID, lhs.baseURL == rhs.baseURL else { return false }
            var left = lhs.text
            var right = rhs.text
            // Keep byte identity without a Swift iteration for each view update.
            return left.withUTF8 { left in
                right.withUTF8 { right in
                    left.count == right.count && (left.isEmpty || memcmp(left.baseAddress!, right.baseAddress!, left.count) == 0)
                }
            }
        }
    }

    struct Request: Equatable {
        let source: Source?
        let presenting: Bool
        let fontSize: CGFloat
    }

    private struct Presentation {
        let blocks: [MarkdownBlock]
        let text: NSAttributedString
        let fontSize: CGFloat
    }

    private enum Phase {
        case idle, rendering(fontSize: CGFloat, previous: Presentation?), complete(Presentation?)

        var presentation: Presentation? {
            switch self {
            case .idle: nil
            case .rendering(_, let previous): previous
            case .complete(let presentation): presentation
            }
        }
    }

    private var source: Source?
    private var phase = Phase.idle
    private let render: @Sendable (Source) async throws -> [MarkdownBlock]
    private let format: @MainActor ([MarkdownBlock], MarkdownText.Style) async throws -> NSAttributedString
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var work: Task<Void, Never>?

    init(render: (@MainActor @Sendable (Source) async throws -> [MarkdownBlock])? = nil,
         format: (@MainActor ([MarkdownBlock], MarkdownText.Style) async throws -> NSAttributedString)? = nil) {
        if let render { self.render = { try await render($0) } }
        else { self.render = { try await MarkdownRendering.blocks(in: $0.text, baseURL: $0.baseURL) } }
        self.format = format ?? { try await MarkdownText.attributedString($0, style: $1) }
    }

    var isRendering: Bool { if case .rendering = phase { true } else { false } }

    func text(for source: Source?) -> NSAttributedString? {
        guard self.source == source else { return nil }
        return phase.presentation?.text
    }

    func isPending(_ source: Source?) -> Bool {
        guard let source else { return false }
        guard self.source == source else { return true }
        if case .complete = phase { return false }
        return phase.presentation == nil
    }

    func load(_ source: Source?, presenting: Bool, fontSize: CGFloat = MarkdownText.defaultFontSize) async {
        guard let task = begin(source, presenting: presenting, fontSize: fontSize) else { return }
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    @discardableResult func begin(_ source: Source?, presenting: Bool,
                                  fontSize: CGFloat = MarkdownText.defaultFontSize) -> Task<Void, Never>? {
        guard !Task.isCancelled else { return nil }
        guard let source else { stop(); return nil }
        if self.source != source { stop(); self.source = source }
        guard presenting else { cancelRendering(); return nil }
        if case .rendering(let size, _) = phase, size == fontSize, let work, !work.isCancelled { return work }
        cancelRendering()
        let previous = phase.presentation
        guard previous?.fontSize != fontSize else { return nil }
        let request = requestID
        let style = MarkdownText.Style(fontSize: fontSize)
        phase = .rendering(fontSize: fontSize, previous: previous)
        let task = Task { [weak self, render, format] in
            do {
                let blocks = if let previous { previous.blocks } else { try await render(source) }
                try Task.checkCancellation()
                let text = try await format(blocks, style)
                self?.finish(Presentation(blocks: blocks, text: text, fontSize: fontSize), request: request)
            } catch {
                self?.finish(nil, request: request)
            }
        }
        work = task
        return task
    }

    private func finish(_ presentation: Presentation?, request: UUID) {
        guard requestID == request else { return }
        if Task.isCancelled {
            cancelRendering()
        } else {
            // Keep the current text through enlargement. A failed initial render falls back to source.
            phase = .complete(presentation ?? phase.presentation)
            work = nil
        }
    }

    func stop() {
        cancelRendering()
        source = nil
        phase = .idle
    }

    private func cancelRendering() {
        requestID = UUID()
        work?.cancel()
        work = nil
        if case .rendering(_, let previous) = phase {
            phase = previous.map { .complete($0) } ?? .idle
        }
    }
}
