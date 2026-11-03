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
    }

    private enum Phase { case idle, rendering, complete([MarkdownBlock]?) }
    private var source: Source?
    private var phase = Phase.idle
    private let render: @Sendable (Source) async throws -> [MarkdownBlock]
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var work: Task<Void, Never>?

    init(render: (@MainActor @Sendable (Source) async throws -> [MarkdownBlock])? = nil) {
        if let render { self.render = { try await render($0) } }
        else { self.render = { try await MarkdownRendering.blocks(in: $0.text, baseURL: $0.baseURL) } }
    }

    var isRendering: Bool { if case .rendering = phase { true } else { false } }

    func blocks(for source: Source?) -> [MarkdownBlock]? {
        guard self.source == source, case .complete(let blocks) = phase else { return nil }
        return blocks
    }

    func isPending(_ source: Source?) -> Bool {
        guard let source else { return false }
        guard self.source == source, case .complete = phase else { return true }
        return false
    }

    func load(_ source: Source?, presenting: Bool) async {
        guard let task = begin(source, presenting: presenting) else { return }
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    @discardableResult func begin(_ source: Source?, presenting: Bool) -> Task<Void, Never>? {
        guard !Task.isCancelled else { return nil }
        guard let source else { stop(); return nil }
        if self.source != source { stop(); self.source = source }
        guard presenting else { cancelRendering(); return nil }
        if case .complete(let blocks) = phase, blocks != nil { return nil }
        if let work, !work.isCancelled { return work }
        cancelRendering()
        let request = requestID
        phase = .rendering
        // Parsing starts independently of native layout; results return to this owner.
        let task = Task.detached(priority: .userInitiated) { [weak self, render] in
            let blocks = try? await render(source)
            await self?.finish(blocks, request: request)
        }
        work = task
        return task
    }

    private func finish(_ blocks: [MarkdownBlock]?, request: UUID) {
        guard requestID == request else { return }
        // Unrenderable Markdown falls back to the highlighted source.
        phase = Task.isCancelled ? .idle : .complete(blocks)
        work = nil
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
        if case .rendering = phase { phase = .idle }
    }
}
