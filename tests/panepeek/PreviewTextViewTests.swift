import AppKit
import SwiftUI
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PreviewTextViewTests {
    @Test func markdownFindWaitsForRenderingImmediatelyAfterLeavingEdit() async throws {
        let state = await loadedState("# Title", name: "notes.md")
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        fixture.window.makeFirstResponder(editor)
        editor.insertText(" draft", replacementRange: NSRange(location: editor.string.utf16.count, length: 0))
        let browser = BrowserState(preview: state)
        let find = BrowserFind()
        find.window = fixture.window
        find.browser = browser
        find.find(in: fixture.window)
        let scroll = try #require(editor.enclosingScrollView)
        let request = find.folderRequest
        let rendering = try #require(state.setMode(.preview))
        fixture.present()
        #expect(scroll.isHidden && !scroll.isFindBarVisible)
        find.find(in: fixture.window)
        #expect(!find.canFind && find.canSearchFolder && find.folderRequest == request)
        await rendering.value
        fixture.present()
        find.find(in: fixture.window)
        #expect(fixture.rendered?.enclosingScrollView?.isFindBarVisible == true)
        #expect(state.text == "# Title draft" && state.isDirty)
        fixture.rendered?.hideFindBar()
    }

    @Test(arguments: ["md", "html"], [false, true])
    func findFollowsRenderedPreviewAndSourceWithoutLosingTheDraft(format: String, findAlreadyVisible: Bool) async throws {
        let original = format == "md" ? "# Heading\n\nVisible body" : "<h1>Heading</h1><p>Visible body</p>"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-find-modes-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes." + format)
        try Data(original.utf8).write(to: file)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        let browser = BrowserState(preview: state)
        let find = BrowserFind()
        find.window = fixture.window
        find.browser = browser
        fixture.window.makeFirstResponder(editor)
        editor.insertText(format == "md" ? "\n\nDraft needle" : "<p>Draft needle</p>",
                          replacementRange: NSRange(location: original.utf16.count, length: 0))
        let draft = state.text
        let document = state.documentID
        find.refresh(in: fixture.window)
        if findAlreadyVisible {
            find.find(in: fixture.window)
            #expect(editor.enclosingScrollView?.isFindBarVisible == true)
        }
        await state.setMode(.preview)?.value
        fixture.present()
        func renderedScroll(in view: NSView) -> NSScrollView? {
            if let html = view as? HTMLFindView { return html }
            if let text = view as? NSTextView, !(text is EditorTextView), !text.isFieldEditor {
                return text.enclosingScrollView
            }
            return view.subviews.lazy.compactMap { renderedScroll(in: $0) }.first
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while renderedScroll(in: fixture.host) == nil && ContinuousClock.now < deadline {
            await Task.yield()
            fixture.host.layoutSubtreeIfNeeded()
        }
        let rendered = try #require(renderedScroll(in: fixture.host))
        #expect(editor.enclosingScrollView?.isFindBarVisible == false)
        find.find(in: fixture.window)
        #expect(rendered.isFindBarVisible)
        #expect(state.documentID == document && state.text == draft && state.isDirty)
        state.setMode(.edit)
        fixture.present()
        #expect(!rendered.isFindBarVisible)
        find.find(in: fixture.window)
        #expect(editor.enclosingScrollView?.isFindBarVisible == true)
        #expect(try fixture.editor() === editor)
        editor.hideFindBar()
        editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil)
        #expect(state.text == original && !state.isDirty)
        #expect(try String(contentsOf: file, encoding: .utf8) == original)
    }

    @Test func nativeFindBarPreservesTheDraftAndUndoAcrossModes() async throws {
        let state = await loadedState("original")
        let fixture = try NativeEditorFixture(state)
        defer { fixture.view.hideFindBar(); fixture.window.orderOut(nil) }
        fixture.type(" needle")
        let scroll = try #require(fixture.view.enclosingScrollView)
        try #require(fixture.view.usesFindBar)
        let find = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        fixture.view.performTextFinderAction(find)
        #expect(scroll.isFindBarVisible)
        #expect(scroll.documentView === fixture.view && fixture.view.string == "original needle")
        #expect(state.text == "original needle" && state.isDirty)
        state.setMode(.preview)
        fixture.present()
        #expect(!fixture.view.isEditable && scroll.isFindBarVisible)
        state.setMode(.edit)
        fixture.present()
        fixture.undo()
        #expect(state.text == "original" && !state.isDirty)
    }

    @Test func editModeShowsAGutterWithoutReplacingTheDocument() async throws {
        let state = await loadedState("first\n\nlast\n")
        let fixture = try NativeEditorFixture(state)
        let scroll = try #require(fixture.view.enclosingScrollView)
        #expect(scroll.hasVerticalRuler && scroll.rulersVisible)
        let ruler = try #require(scroll.verticalRulerView)
        #expect(!ruler.acceptsFirstResponder && ruler.accessibilityRole() == .staticText)
        #expect(ruler.accessibilityValue() as? String == "4 lines")
        #expect(fixture.view.isAccessibilityElement())
        #expect(scroll.accessibilityContents()?.contains { $0 as AnyObject === fixture.view } == true)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        fixture.view.selectAll(nil)
        #expect(fixture.view.selectedRange() == NSRange(location: 0, length: 12))
        #expect(fixture.view.writeSelection(to: pasteboard, types: fixture.view.writablePasteboardTypes))
        #expect(pasteboard.string(forType: .string) == "first\n\nlast\n")
        fixture.type("draft")
        let selection = fixture.view.selectedRange()
        state.setMode(.preview)
        fixture.present()
        #expect(!scroll.rulersVisible)
        state.setMode(.edit)
        fixture.present()
        #expect(scroll.rulersVisible && scroll.verticalRulerView === ruler)
        #expect(fixture.view.selectedRange() == selection)
        fixture.undo()
        #expect(state.text == "first\n\nlast\n" && !state.isDirty)
    }

    @Test func renderedPreviewDismissesSourceFindWithoutReplacingTheDraft() async throws {
        let state = await loadedState("# Title", name: "notes.md")
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        let scroll = try #require(editor.enclosingScrollView)
        let find = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        editor.performTextFinderAction(find)
        #expect(scroll.isFindBarVisible)
        state.setMode(.preview)
        fixture.present()
        #expect(!scroll.isFindBarVisible && scroll.isHidden)
        #expect(state.text == "# Title" && !state.isDirty)
        state.setMode(.edit)
        fixture.present()
        #expect(try fixture.editor() === editor)
        #expect(!scroll.isFindBarVisible)
    }

    @Test func gutterNumbersEmptyBlankAndTrailingLinesUsingNativeLayout() async throws {
        for text in ["", "one\n\nthree\n", "café 👀\r\n\r\nend\r\n", "one\u{2028}two\u{2029}"] {
            let state = await loadedState(text)
            let fixture = try NativeEditorFixture(state)
            let ruler = try #require(fixture.view.enclosingScrollView?.verticalRulerView as? EditorLineNumberRuler)
            let labels = ruler.labels()
            #expect(labels.map(\.number) == Array(1...EditorLines(text).starts.count))
            for (label, offset) in zip(labels, EditorLines(text).starts) {
                let screen = fixture.view.firstRect(forCharacterRange: NSRange(location: offset, length: 0), actualRange: nil)
                let rect = ruler.convert(fixture.window.convertFromScreen(screen), from: nil)
                #expect(abs(label.baseline - rect.minY - (fixture.view.font?.ascender ?? 0)) < 1,
                        "line \(label.number), baseline \(label.baseline), text rect \(rect)")
            }
            #expect(fixture.view.textLayoutManager != nil)
        }
    }

    @Test func gutterFollowsWrappingScrollingResizingAndEnlargedText() async throws {
        let text = (1...300).map { "line \($0) " + String(repeating: "word 👀 ", count: 12) }.joined(separator: "\n")
        let state = await loadedState(text)
        let fixture = try NativeEditorFixture(state)
        let scroll = try #require(fixture.view.enclosingScrollView)
        let ruler = try #require(scroll.verticalRulerView as? EditorLineNumberRuler)
        let lines = EditorLines(text)
        for width in [260.0, 580.0] {
            fixture.window.setContentSize(NSSize(width: width, height: 250))
            fixture.host.layoutSubtreeIfNeeded()
            fixture.view.scrollRangeToVisible(NSRange(location: lines.starts[150], length: 0))
            fixture.host.layoutSubtreeIfNeeded()
            fixture.view.textLayoutManager?.textViewportLayoutController.layoutViewport()
            let labels = ruler.labels()
            try #require(!labels.isEmpty)
            #expect(labels.count < 20)
            #expect(labels.contains { $0.number == 151 })
            #expect(Set(labels.map(\.number)).count == labels.count)
            let font = try #require(fixture.view.font)
            let fullyVisible = labels.filter { $0.baseline - font.ascender >= ruler.bounds.minY && $0.baseline - font.descender <= ruler.bounds.maxY }
            try #require(!fullyVisible.isEmpty)
            for label in fullyVisible {
                let screen = fixture.view.firstRect(forCharacterRange: NSRange(location: lines.starts[label.number - 1], length: 0), actualRange: nil)
                let rect = ruler.convert(fixture.window.convertFromScreen(screen), from: nil)
                #expect(abs(label.baseline - rect.minY - (fixture.view.font?.ascender ?? 0)) < 1,
                        "line \(label.number), width \(width), baseline \(label.baseline), text rect \(rect), visible \(fixture.view.visibleRect)")
            }
        }
        let oldWidth = ruler.ruleThickness
        fixture.view.font = PreviewFonts.monospaced(size: (fixture.view.font?.pointSize ?? 13) * 2)
        ruler.update(textChanged: false)
        fixture.host.layoutSubtreeIfNeeded()
        fixture.view.textLayoutManager?.textViewportLayoutController.layoutViewport()
        #expect(ruler.ruleThickness > oldWidth)
        #expect(!ruler.labels().isEmpty && fixture.view.textLayoutManager != nil)
        #expect(fixture.view.string == text && !state.isDirty)
    }

    @Test func gutterTracksDigitGrowthAndKeepsNearLimitDrawingLocal() async throws {
        let state = await loadedState(String(repeating: "\n", count: 98))
        let fixture = try NativeEditorFixture(state)
        let ruler = try #require(fixture.view.enclosingScrollView?.verticalRulerView as? EditorLineNumberRuler)
        let twoDigitWidth = ruler.ruleThickness
        fixture.type("\n")
        fixture.present()
        #expect(ruler.ruleThickness > twoDigitWidth)
        fixture.undo()
        fixture.present()
        #expect(ruler.ruleThickness == twoDigitWidth)
        let text = String(repeating: "x\n", count: 500_000)
        let large = await loadedState(text)
        let largeFixture = try NativeEditorFixture(large)
        let largeRuler = try #require(largeFixture.view.enclosingScrollView?.verticalRulerView as? EditorLineNumberRuler)
        let labels = largeRuler.labels()
        #expect(!labels.isEmpty && labels.count < 50)
        #expect(labels.first?.number == 1 && largeFixture.view.textLayoutManager != nil)
    }

    @Test func logicalLineOffsetsRespectUnicodeAndExistingNewlineSequences() {
        #expect(EditorLines("").starts == [0])
        let lines = EditorLines("👀\r\n\rnext\n\u{2028}\u{2029}")
        #expect(lines.starts == [0, 4, 5, 10, 11, 12])
        #expect([0, 2, 3, 4, 5, 9, 10, 12].map { lines.number(at: $0) } == [1, 1, 1, 2, 3, 3, 4, 6])
    }

    @Test(arguments: ["notes.md", "notes.swift", "notes.txt"])
    func typingAndSavingDeepInAWrappedDocumentKeepsTheViewport(name: String) async throws {
        let text = (1...300).map {
            "// Heading \($0)\nlet value\($0) = \""
                + String(repeating: "Some wrapped text with **emphasis** and `code`. ", count: 5) + "\""
        }.joined(separator: "\n")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-scroll-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        let (writes, requests) = AsyncStream<CheckedContinuation<Void, Never>>.makeStream()
        defer { requests.finish() }
        var iterator = writes.makeAsyncIterator()
        let state = PreviewState(write: { snapshot, draft, destination in
            await withCheckedContinuation { requests.yield($0) }
            return try await snapshot.save(draft, to: destination)
        })
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        let scroll = try #require(fixture.view.enclosingScrollView)
        let ruler = try #require(scroll.verticalRulerView as? EditorLineNumberRuler)
        let location = EditorLines(text).starts[431] + 5
        fixture.view.setSelectedRange(NSRange(location: location, length: 0))
        fixture.view.scrollRangeToVisible(fixture.view.selectedRange())
        fixture.host.layoutSubtreeIfNeeded()
        fixture.view.textLayoutManager?.textViewportLayoutController.layoutViewport()
        let anchor = try #require(ruler.labels().first)
        try #require(anchor.number > 400)
        let insertion = "/*draft*/"
        for character in insertion {
            fixture.view.insertText(String(character), replacementRange: fixture.view.selectedRange())
            await fixture.gate.editTask?.value
            fixture.present()
            fixture.view.textLayoutManager?.textViewportLayoutController.layoutViewport()
            let current = try #require(ruler.labels().first { $0.number == anchor.number })
            #expect(abs(current.baseline - anchor.baseline) < 1)
        }
        let selection = NSRange(location: location + insertion.utf16.count, length: 0)
        #expect(fixture.view.selectedRange() == selection)
        let saving = Task { await state.save() }
        let write = try #require(await iterator.next())
        fixture.present()
        #expect(!fixture.view.isEditable)
        #expect(ruler.labels().contains { $0.number == anchor.number && abs($0.baseline - anchor.baseline) < 1 })
        write.resume()
        #expect(await saving.value)
        fixture.present()
        fixture.view.textLayoutManager?.textViewportLayoutController.layoutViewport()
        let saved = try #require(ruler.labels().first { $0.number == anchor.number })
        #expect(abs(saved.baseline - anchor.baseline) < 1)
        #expect(fixture.view.selectedRange() == selection && !state.isDirty)
        #expect(try String(contentsOf: url, encoding: .utf8) == fixture.view.string)
        fixture.undo()
        await fixture.gate.editTask?.value
        fixture.present()
        #expect(state.text == text && state.isDirty)
    }

    @Test func pendingHighlightingRetainsColoursAndRefreshesUnchangedTokens() async throws {
        let original = "let"
        let tokens = [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)]
        let (requests, source) = AsyncStream<CheckedContinuation<[SyntaxToken], any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = PreviewState(read: { _ in .text(original) }, highlight: { text, _ in
            if text == original { return tokens }
            return try await withCheckedThrowingContinuation { source.yield($0) }
        })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/native-editor/sample.swift"), isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        fixture.view.typingAttributes[.foregroundColor] = PreviewColours.keyword
        fixture.type(" value")
        let result = try #require(await iterator.next())
        fixture.present()
        #expect(fixture.colour(at: 0) == PreviewColours.keyword)
        result.resume(returning: tokens)
        await fixture.gate.editTask?.value
        fixture.present()
        #expect(fixture.colour(at: 0) == PreviewColours.keyword)
        #expect(fixture.colour(at: 4) == NSColor.textColor)
        #expect(fixture.view.selectedRange() == NSRange(location: 9, length: 0))
        fixture.undo()
        #expect(state.text == original && fixture.view.string == original)
    }

    @Test func aNewEditCannotApplyUnpresentedRangesFromThePreviousDraft() async throws {
        let tokens = [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)]
        let (requests, source) = AsyncStream<CheckedContinuation<[SyntaxToken], any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = PreviewState(read: { _ in .text("let") }, highlight: { text, _ in
            if text == "let" { return tokens }
            return try await withCheckedThrowingContinuation { source.yield($0) }
        })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/native-editor/sample.swift"), isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        fixture.type(" // note")
        let earlier = try #require(await iterator.next())
        earlier.resume(returning: tokens + [SyntaxToken(range: NSRange(location: 4, length: 7), kind: .comment)])
        await fixture.gate.editTask?.value
        fixture.view.setSelectedRange(NSRange(location: 0, length: 0))
        fixture.view.insertText("xx ", replacementRange: fixture.view.selectedRange())
        let latest = try #require(await iterator.next())
        fixture.present()
        #expect(fixture.colour(at: 3) == PreviewColours.keyword)
        latest.resume(returning: [SyntaxToken(range: NSRange(location: 3, length: 3), kind: .keyword),
                                  SyntaxToken(range: NSRange(location: 7, length: 7), kind: .comment)])
        await fixture.gate.editTask?.value
        fixture.present()
        #expect(fixture.colour(at: 3) == PreviewColours.keyword)
        #expect(fixture.colour(at: 7) == PreviewColours.comment)
    }

    @Test func completedHighlightingWaitsForMarkedTextToEnd() async throws {
        let tokens = [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)]
        let (requests, source) = AsyncStream<CheckedContinuation<[SyntaxToken], any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = PreviewState(read: { _ in .text("let") }, highlight: { text, _ in
            if text == "let" { return tokens }
            return try await withCheckedThrowingContinuation { source.yield($0) }
        })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/native-editor/sample.swift"), isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        fixture.view.setMarkedText("// café\n👀", selectedRange: NSRange(location: 10, length: 0),
                                   replacementRange: NSRange(location: 0, length: 3))
        fixture.view.didChangeText()
        try #require(fixture.view.hasMarkedText() && state.text == "// café\n👀")
        let result = try #require(await iterator.next())
        let marked = fixture.view.markedRange()
        let selection = fixture.view.selectedRange()
        let colour = fixture.colour(at: 0)
        result.resume(returning: [SyntaxToken(range: NSRange(location: 0, length: 7), kind: .comment)])
        await fixture.gate.editTask?.value
        fixture.present()
        #expect(fixture.view.markedRange() == marked && fixture.view.selectedRange() == selection)
        let ruler = try #require(fixture.view.enclosingScrollView?.verticalRulerView as? EditorLineNumberRuler)
        #expect(ruler.labels().map(\.number) == [1, 2])
        #expect(fixture.colour(at: 0) == colour)
        fixture.view.unmarkText()
        fixture.present()
        #expect(fixture.colour(at: 0) == PreviewColours.comment)
        #expect(state.text == "// café\n👀")
    }

    @Test func sandboxPreviewCannotTypeOrEnterEditMode() async throws {
        let state = PreviewState(readOnly: true, read: { _ in .text("original") })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/selected/notes.txt"), isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        #expect(state.mode == .preview && !fixture.view.isEditable)
        fixture.type(" changed")
        #expect(fixture.view.string == "original" && state.text == "original" && !state.isDirty)
    }

    @Test func nativeTypingCanUndoAndRedoAfterPresentationUpdates() async throws {
        let original = "let count = 1\n"
        let state = await loadedState(original, name: "sample.swift")
        let fixture = try NativeEditorFixture(state)
        fixture.type("// café 👀\n")
        let edited = try #require(state.text)
        #expect(state.isDirty)
        let selection = fixture.view.selectedRange()
        await fixture.gate.editTask?.value
        #expect(!state.tokens.isEmpty)
        fixture.present()
        #expect(fixture.view.selectedRange() == selection)
        #expect(fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == original && state.text == original && !state.isDirty)
        #expect(fixture.redoEnabled)
        fixture.redo()
        #expect(fixture.view.string == edited && state.text == edited && state.isDirty)
    }

    @Test func undoAndRedoRespectModesAndTheLiveEditGateWithoutLosingHistory() async throws {
        let state = await loadedState("original")
        let fixture = try NativeEditorFixture(state)
        fixture.type(" edited")
        fixture.gate.isOpen = false
        #expect(!fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == "original edited" && state.text == "original edited")
        fixture.gate.isOpen = true
        fixture.undo()
        #expect(fixture.view.string == "original" && !state.isDirty)
        fixture.gate.isOpen = false
        #expect(!fixture.redoEnabled)
        fixture.redo()
        #expect(fixture.view.string == "original" && !state.isDirty)
        fixture.gate.isOpen = true
        fixture.redo()
        #expect(fixture.view.string == "original edited" && state.isDirty)
        state.setMode(.preview)
        fixture.present()
        #expect(!fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == "original edited" && state.isDirty)
        state.setMode(.edit)
        fixture.present()
        fixture.undo()
        #expect(fixture.view.string == "original" && !state.isDirty)
    }

    @Test func typingAfterSaveUndoesToTheSavedBaselineAndDiscardClearsHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-native-undo-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("sample.txt")
        try Data("original".utf8).write(to: url)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        fixture.type(" saved")
        #expect(await state.save())
        fixture.present()
        fixture.type(" later")
        fixture.undo()
        #expect(fixture.view.string == "original saved" && state.text == "original saved" && !state.isDirty)
        fixture.redo()
        #expect(fixture.view.string == "original saved later" && state.isDirty)
        state.discardChanges()
        fixture.present()
        #expect(fixture.view.string == "original saved" && !state.isDirty && !fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == "original saved" && !state.isDirty)
        #expect(try Data(contentsOf: url) == Data("original saved".utf8))
    }

    @Test func listingRefreshKeepsTheSidebarEditorAndUndoAfterSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-sidebar-save-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("notes.txt")
        try Data("original".utf8).write(to: url)
        let item = DirectoryEntry(url: url, isDirectory: false)
        let initial = DetailsSelection(item: item, listingRevision: UUID())
        let state = PreviewState()
        let sizing = DetailsSizing()
        let host = NSHostingView(rootView: DetailsSidebar(selection: initial, preview: state, sizing: sizing, notifications: OperationNotifications()))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (state.text == nil || state.isLoading) && ContinuousClock.now < deadline { await Task.yield() }
        try #require(state.text == "original" && !state.isLoading)
        state.setMode(.edit)
        host.layoutSubtreeIfNeeded()
        let editor = try #require(descendants(of: EditorTextView.self, in: host).first)
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 8, length: 0))
        editor.insertText(" saved", replacementRange: editor.selectedRange())
        try #require(state.isDirty && state.text == "original saved")
        #expect(await state.save())
        let refreshed = DetailsSelection(item: item, listingRevision: UUID())
        host.rootView = DetailsSidebar(selection: refreshed, preview: state, sizing: sizing, notifications: OperationNotifications())
        host.layoutSubtreeIfNeeded()
        #expect(descendants(of: EditorTextView.self, in: host).first === editor)
        await state.load(refreshed)
        host.rootView = DetailsSidebar(selection: refreshed, preview: state, sizing: sizing, notifications: OperationNotifications())
        host.layoutSubtreeIfNeeded()
        let retained = try #require(descendants(of: EditorTextView.self, in: host).first)
        #expect(retained === editor)
        window.makeFirstResponder(retained)
        #expect(retained.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(retained.string == "original" && state.text == "original" && state.isDirty)
        #expect(try Data(contentsOf: url) == Data("original saved".utf8))
    }

    @Test func renderedMarkdownKeepsTheHiddenEditorAndItsUndoHistoryAcrossModes() async throws {
        let state = await loadedState("# Title", name: "notes.md")
        state.setMode(.preview)
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        #expect(fixture.rendered?.string == "Title" && editor.enclosingScrollView?.isHidden == true)
        state.setMode(.edit)
        fixture.present()
        #expect(fixture.rendered == nil && editor.enclosingScrollView?.isHidden == false)
        #expect(editor.enclosingScrollView?.rulersVisible == true)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText(" draft", replacementRange: editor.selectedRange())
        await state.setMode(.preview)?.value
        fixture.present()
        #expect(fixture.rendered?.string == "Title draft" && state.isDirty)
        #expect(editor.enclosingScrollView?.rulersVisible == false)
        state.setMode(.edit)
        fixture.present()
        #expect(try fixture.editor() === editor)
        #expect(editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(editor.string == "# Title" && state.text == "# Title" && !state.isDirty)
    }

    @Test(arguments: ["svg", "html"])
    func renderedDocumentsKeepTheSourceEditorAndUndoHistoryAcrossModes(fileExtension: String) async throws {
        let original = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"50\"><rect width=\"100\" height=\"50\" fill=\"red\"/></svg>"
        let state = await loadedState(original, name: "art." + fileExtension)
        state.setMode(.preview)
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        #expect(editor.enclosingScrollView?.isHidden == true)
        state.setMode(.edit)
        fixture.present()
        #expect(editor.enclosingScrollView?.isHidden == false)
        #expect(editor.enclosingScrollView?.rulersVisible == true)
        editor.setSelectedRange((editor.string as NSString).range(of: "red"))
        editor.insertText("blue", replacementRange: editor.selectedRange())
        state.setMode(.preview)
        fixture.present()
        #expect(editor.enclosingScrollView?.isHidden == true && state.isDirty && state.text?.contains("blue") == true)
        #expect(editor.enclosingScrollView?.rulersVisible == false)
        state.setMode(.edit)
        fixture.present()
        #expect(try fixture.editor() === editor)
        #expect(editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(editor.string == original && state.text == original && !state.isDirty)
    }

    @Test(arguments: ["notes.md", "art.svg", "page.html"])
    func saveMetadataEchoKeepsTheNativeEditorAndUndo(name: String) async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-save-editor-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(name)
        try Data("original".utf8).write(to: file)
        let browser = BrowserState(homeDirectory: root)
        browser.operations.register(browser)
        defer { browser.operations.unregister(browser) }
        await browser.left.navigate(to: root)
        browser.select([file], in: .left)
        let preview = browser.preview
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("seed")?.value
        let document = preview.documentID
        let host = NSHostingView(rootView: SidebarFixture(browser: browser))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded()
        let editor = try #require(descendants(of: EditorTextView.self, in: host).first)
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        editor.insertText(" changed", replacementRange: editor.selectedRange())
        try #require(editor.undoManager?.canUndo == true)
        try #require(await preview.save())
        await preview.load(browser.detailsSelection)
        host.layoutSubtreeIfNeeded()
        let retained = try #require(descendants(of: EditorTextView.self, in: host).first)
        #expect(preview.documentID == document && preview.mode == .edit)
        #expect(retained === editor && retained.undoManager?.canUndo == true)
        #expect(retained.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(preview.text == "seed" && preview.isDirty)
    }

    @Test func documentEditorLocksDuringRenameWithoutLosingItsUndoHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-document-rename-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("notes.md")
        try Data("# Title".utf8).write(to: url)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        fixture.window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText(" draft", replacementRange: editor.selectedRange())
        state.setChangingLocation(try await ItemRename.capture(url))
        fixture.present()
        #expect(state.isChangingLocation && !editor.isEditable)
        #expect(editor.enclosingScrollView?.rulersVisible == true)
        #expect(state.text == "# Title draft" && state.isDirty)
        state.setChangingLocation(nil)
        fixture.present()
        #expect(try fixture.editor() === editor && editor.isEditable)
        #expect(editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(editor.string == "# Title" && state.text == "# Title" && !state.isDirty)
    }

    @Test func copyingTheWholeDraftPreservesNativeSelectionScrollAndUndo() async throws {
        let original = (1...100).map { "Line \($0)\n" }.joined()
        let state = await loadedState(original)
        let fixture = try NativeEditorFixture(state)
        fixture.type("Unsaved draft\n")
        try #require(state.isDirty && fixture.view.undoManager?.canUndo == true)
        let selection = NSRange(location: 20, length: 5)
        fixture.view.setSelectedRange(selection)
        let scroll = try #require(fixture.view.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 120))
        scroll.reflectScrolledClipView(scroll.contentView)
        let origin = scroll.contentView.bounds.origin
        let document = state.documentID
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let sidebar = DetailsSidebar(selection: state.selection, preview: state, sizing: DetailsSizing(), notifications: OperationNotifications())
        sidebar.copyFileContent(to: board)
        #expect(board.string(forType: .string) == original + "Unsaved draft\n")
        #expect(state.documentID == document && state.isDirty && state.mode == .edit)
        #expect(fixture.view.selectedRange() == selection && scroll.contentView.bounds.origin == origin)
        #expect(fixture.window.firstResponder === fixture.view)
        fixture.undo()
        #expect(state.text == original && !state.isDirty)
    }

    private func loadedState(_ text: String, name: String = "sample.txt") async -> PreviewState {
        let state = PreviewState(read: { _ in .text(text) })
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/native-editor/\(name)"), isDirectory: false)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        state.setMode(.edit)
        return state
    }
}

@MainActor private final class NativeEditGate {
    var isOpen = true
    var editTask: Task<Void, Never>?
}

@MainActor private final class NativeEditorFixture {
    let state: PreviewState
    let gate: NativeEditGate
    let host: NSHostingView<PreviewTextView>
    let window: NSWindow
    let view: EditorTextView
    private let undoItem = NSMenuItem(title: "Undo", action: #selector(EditorTextView.undo(_:)), keyEquivalent: "z")
    private let redoItem = NSMenuItem(title: "Redo", action: #selector(EditorTextView.redo(_:)), keyEquivalent: "Z")

    init(_ state: PreviewState) throws {
        _ = NSApplication.shared
        self.state = state
        let gate = NativeEditGate()
        self.gate = gate
        host = NSHostingView(rootView: Self.preview(state, gate: gate))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        view = try #require(descendants(of: EditorTextView.self, in: host).first)
        window.makeFirstResponder(view)
    }

    var undoEnabled: Bool { view.validateUserInterfaceItem(undoItem) }
    var redoEnabled: Bool { view.validateUserInterfaceItem(redoItem) }

    func colour(at location: Int) -> NSColor? {
        view.textStorage?.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
    }

    func present() {
        host.rootView = Self.preview(state, gate: gate)
        host.layoutSubtreeIfNeeded()
    }

    func type(_ text: String) {
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        view.insertText(text, replacementRange: view.selectedRange())
    }

    func undo() { #expect(view.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil)) }
    func redo() { #expect(view.tryToPerform(#selector(EditorTextView.redo(_:)), with: nil)) }

    private static func preview(_ state: PreviewState, gate: NativeEditGate) -> PreviewTextView {
        PreviewTextView(text: state.text ?? "", documentID: state.documentID, saveRevision: state.saveRevision, mode: state.mode,
                        tokens: state.tokens, highlightRevision: state.highlightRevision,
                        editingLocked: state.isSaving || state.isChangingLocation,
                        canChange: { gate.isOpen && state.canEdit && state.mode == .edit },
                        changed: { gate.editTask = state.updateText($0) })
    }
}

@MainActor private struct SidebarFixture: View {
    let browser: BrowserState
    let sizing = DetailsSizing()
    var body: some View { DetailsSidebar(selection: browser.detailsSelection, preview: browser.preview, sizing: sizing, notifications: OperationNotifications()) }
}

@MainActor private final class DocumentFixture {
    let state: PreviewState
    let host: NSHostingView<PreviewDocument>
    let window: NSWindow

    init(_ state: PreviewState) throws {
        _ = NSApplication.shared
        self.state = state
        host = NSHostingView(rootView: PreviewDocument(preview: state, text: state.text ?? ""))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
    }

    func editor() throws -> EditorTextView { try #require(descendants(of: EditorTextView.self, in: host).first) }
    var rendered: NSTextView? { descendants(of: NSTextView.self, in: host).first { !($0 is EditorTextView) } }

    func present() {
        host.rootView = PreviewDocument(preview: state, text: state.text ?? "")
        host.layoutSubtreeIfNeeded()
    }
}

@MainActor private func descendants<View: NSView>(of type: View.Type, in view: NSView) -> [View] {
    view.subviews.flatMap { child in [child as? View].compactMap { $0 } + descendants(of: type, in: child) }
}
