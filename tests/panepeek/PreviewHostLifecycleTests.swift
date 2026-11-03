import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PreviewHostLifecycleTests {
    @Test func anUnselectedHostConstructsNoRendererState() {
        var constructed = [BuiltInPreviewCatalogue.ID]()
        let presentations = BuiltInPreviewState { registration in
            constructed.append(registration.id)
            return registration.makePresentation()
        }
        _ = BuiltInPreviewHost(selection: nil, preview: PreviewState(), presentations: presentations,
            notifications: OperationNotifications())
        #expect(constructed.isEmpty)
    }

    @Test func listingRefreshKeepsTheDirtyMarkdownPresentationAndEditor() async throws {
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/preview-host/notes.md"), isDirectory: false)
        let state = PreviewState(read: { _ in .text("# Saved") })
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        state.setMode(.edit)
        await state.updateText("# Draft")?.value
        state.setMode(.preview)
        var reads = 0
        let markdown = MarkdownPreviewState(render: { source in
            reads += 1
            return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
        })
        let fixture = MarkdownHostFixture(state, markdown: markdown)
        defer { fixture.close() }
        try await fixture.ready { fixture.rendered?.string == "Draft" }
        let rendered = try #require(fixture.rendered)
        let editor = try #require(fixture.editor)
        let document = state.documentID
        let refreshed = DetailsSelection(item: item, listingRevision: UUID())
        fixture.host.rootView = AnyView(BuiltInPreviewHost(selection: refreshed, preview: state,
            presentations: BuiltInPreviewState(markdown: markdown), notifications: OperationNotifications()).onAppear {})
        fixture.host.layoutSubtreeIfNeeded()
        #expect(fixture.rendered === rendered && fixture.editor === editor)
        try await fixture.ready { state.selection == refreshed && fixture.rendered?.string == "Draft" }
        #expect(reads == 1)
        #expect(fixture.rendered === rendered && fixture.editor === editor)
        #expect(state.documentID == document && state.text == "# Draft" && state.isDirty)
    }

    @Test func previewControlActivatesItsMarkdownOwnerBeforeAnotherLayout() async throws {
        try await withNativeTestScope { scope in
            let parse: NativeTestRequest<Void> = scope.request("requested Markdown parse")
            let appeared: NativeTestEvent<Void> = scope.event("Markdown host appearance")
            var reads = [String]()
            let markdown = MarkdownPreviewState(render: { source in
                reads.append(source.text)
                try await parse.value()
                return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
            })
            let state = PreviewState(read: { _ in .text("# Saved") })
            await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview-host/notes.md"), isDirectory: false), listingRevision: UUID()))
            state.setMode(.edit)
            await state.updateText("# Draft")?.value
            let fixture = MarkdownHostFixture(state, markdown: markdown, appeared: { appeared.signal(()) })
            defer { parse.result.signal(()); fixture.close() }
            try await appeared.wait()
            let editor = try #require(fixture.editor)
            let document = state.documentID
            try fixture.selectMode(.preview)
            try #require(markdown.isRendering)
            try await parse.started.wait()
            #expect(reads == ["# Draft"] && state.isDirty)
            parse.result.signal(())
            try await fixture.ready { fixture.rendered?.string == "Draft" }
            #expect(fixture.editor === editor && state.documentID == document && state.text == "# Draft")
        }
    }

    @Test func programmaticDiscardRendersTheRestoredSourceInTheRetainedEditor() async throws {
        let state = PreviewState(read: { _ in .text("# Saved") })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview-host/notes.md"), isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        await state.updateText("# Draft")?.value
        state.setMode(.preview)
        var reads = [String]()
        let markdown = MarkdownPreviewState(render: { source in
            reads.append(source.text)
            return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
        })
        let fixture = MarkdownHostFixture(state, markdown: markdown)
        defer { fixture.close() }
        try await fixture.ready { fixture.rendered?.string == "Draft" }
        let editor = try #require(fixture.editor)
        let document = state.documentID
        await state.discardChanges()?.value
        try await fixture.ready { fixture.rendered?.string == "Saved" }
        #expect(reads == ["# Draft", "# Saved"])
        #expect(fixture.editor === editor && state.documentID != document && state.text == "# Saved" && !state.isDirty)
    }

    @Test func anAsynchronousEditGrantDeactivatesThePendingMarkdownPresentation() async throws {
        try await withNativeTestScope { scope in
            let parse: NativeTestRequest<Void> = scope.request("Markdown parse before edit access")
            let access: NativeTestRequest<DirectoryAccess?> = scope.request("edit access")
            let finished: NativeTestEvent<Void> = scope.event("cancelled Markdown parse completion")
            let state = PreviewState(acquireWriteAccess: { _ in try await access.value() }, read: { _ in .text("# Saved") })
            await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview-host/notes.md"), isDirectory: false), listingRevision: UUID()))
            let markdown = MarkdownPreviewState(render: { source in
                defer { finished.signal(()) }
                try await parse.value()
                return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
            })
            let fixture = MarkdownHostFixture(state, markdown: markdown)
            defer { parse.result.signal(()); access.result.signal(nil); fixture.close() }
            try await parse.started.wait()
            try fixture.selectMode(.edit)
            try await access.started.wait()
            #expect(state.mode == .preview && state.isRequestingWriteAccess && markdown.isRendering)
            access.result.signal(DirectoryAccess(root: URL(fileURLWithPath: "/preview-host/"), mode: .readWrite, release: {}))
            try await fixture.ready { state.mode == .edit && !markdown.isRendering }
            parse.result.signal(())
            try await finished.wait()
            let source = MarkdownPreviewState.Source(documentID: state.documentID, text: "# Saved", baseURL: URL(fileURLWithPath: "/preview-host/"))
            #expect(state.canEdit && markdown.blocks(for: source) == nil && fixture.editor?.isEditable == true)
        }
    }

    @Test func disappearingHostClearsAnImageOwnerBeforeItsLateReadCompletes() async throws {
        try await withNativeTestScope { scope in
            let request: NativeTestRequest<Void> = scope.request("image read")
            let disappeared: NativeTestEvent<Void> = scope.event("preview host disappearance")
            let released: NativeTestEvent<Void> = scope.event("finished image read access release")
            weak var retainedAccess: DirectoryAccess?
            let image = ImagePreviewState(read: { _ in
                try await request.value()
                return try Self.image()
            })
            let preview = PreviewState()
            var selection: DetailsSelection?
            do {
                let access = DirectoryAccess(root: URL(fileURLWithPath: "/preview-host/")) {
                    Task { @MainActor in released.signal(()) }
                }
                retainedAccess = access
                selection = DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview-host/image.png"), isDirectory: false),
                                             listingRevision: UUID(), access: access)
            }
            let host = NSHostingView(rootView: AnyView(BuiltInPreviewHost(selection: selection, preview: preview,
                presentations: BuiltInPreviewState(image: image),
                notifications: OperationNotifications()).onDisappear { disappeared.signal(()) }))
            selection = nil
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            defer { window.orderOut(nil); window.contentView = nil; window.close() }
            try await request.started.wait()
            host.rootView = AnyView(EmptyView())
            host.layoutSubtreeIfNeeded()
            try await disappeared.wait()
            #expect(image.selection == nil && image.image == nil && !image.isLoading)
            #expect(retainedAccess != nil)
            request.result.signal(())
            try await released.wait()
            #expect(retainedAccess == nil && image.image == nil && image.selection == nil)
        }
    }

    nonisolated private static func image() throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try #require(context.makeImage())
    }
}

@MainActor private final class MarkdownHostFixture {
    let host: NSHostingView<AnyView>
    let window: NSWindow

    init(_ state: PreviewState, markdown: MarkdownPreviewState, appeared: @escaping () -> Void = {}) {
        host = NSHostingView(rootView: AnyView(BuiltInPreviewHost(selection: state.selection, preview: state,
            presentations: BuiltInPreviewState(markdown: markdown), notifications: OperationNotifications()).onAppear(perform: appeared)))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
    }

    var editor: EditorTextView? { descendants(EditorTextView.self, in: host).first }
    var rendered: NSTextView? { descendants(NSTextView.self, in: host).first { !($0 is EditorTextView) && !$0.isFieldEditor } }

    func selectMode(_ mode: PreviewState.Mode) throws {
        let toggle = try #require(descendants(NSSegmentedControl.self, in: host).first { $0.label(forSegment: 0) == "Preview" })
        try #require(toggle.isEnabled)
        toggle.selectedSegment = mode == .preview ? 0 : 1
        try #require(toggle.sendAction(toggle.action, to: toggle.target))
    }

    func ready(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            host.layoutSubtreeIfNeeded()
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(condition())
    }

    func close() {
        host.rootView = AnyView(EmptyView())
        host.layoutSubtreeIfNeeded()
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        view.subviews.flatMap { child in [child as? T].compactMap { $0 } + descendants(type, in: child) }
    }
}
