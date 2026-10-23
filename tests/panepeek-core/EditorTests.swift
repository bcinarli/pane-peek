import Foundation
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1)))
struct EditorTests {
    @Test @MainActor func heldEditorWorkWaitsForItsController() async throws {
        try await withTestRequestGate(of: String.self, returning: [SyntaxToken].self) { gate in
            let state = PreviewState(read: { _ in .text("original") }, highlight: { text, _ in
                if text == "original" { return [] }
                return try await gate.request(text)
            })
            await state.load(editorSelection("file.swift"))
            state.setMode(.edit)
            let pending = state.updateText("held edit")
            gate.track(pending)
            #expect(try await gate.waitForRequest(0) == "held edit")
            // Exercise a slow controller without using elapsed time to infer completion.
            try await Task.sleep(for: .seconds(6))
            let token = SyntaxToken(range: NSRange(location: 0, length: 4), kind: .keyword)
            try gate.finish(0, with: .success([token]))
            await pending?.value
            #expect(state.tokens == [token] && state.text == "held edit" && state.isDirty)
        }
    }

    @Test @MainActor func modesRetainDraftAndRevertingExactBytesClearsDirtyState() async {
        let original = "let café = \"👀\"\r\nnext\nlast\r"
        let state = PreviewState(read: { _ in .text(original) })
        await state.load(editorSelection("sample.swift"))
        let document = state.documentID
        #expect(state.canEdit && !state.isDirty && state.mode == .preview)
        state.setMode(.edit)
        await state.updateText(original + "// changed")?.value
        #expect(state.isDirty && state.text == original + "// changed")
        state.setMode(.preview)
        #expect(state.text == original + "// changed" && state.isDirty)
        state.setMode(.edit)
        #expect(state.documentID == document)
        await state.updateText(original)?.value
        #expect(!state.isDirty && state.text?.utf8.elementsEqual(original.utf8) == true)
        // Swift's canonical String equality must not hide an actual byte change.
        await state.updateText(original.replacingOccurrences(of: "é", with: "e\u{301}"))?.value
        #expect(state.isDirty)
        state.discardChanges()
        #expect(!state.isDirty && state.text?.utf8.elementsEqual(original.utf8) == true)
        #expect(state.documentID != document)
    }

    @Test @MainActor func emptyTextEditsButUnavailableAndLinkContentDoNot() async {
        for (preview, link, editable): (TextPreview, Bool, Bool) in [
            (.text(""), false, true), (.text("linked", editable: false), false, false),
            (.text("linked"), true, false), (.unavailable(.binary), false, false),
            (.unavailable(.tooLarge), false, false), (.unavailable(.folder), false, false)
        ] {
            let state = PreviewState(read: { _ in preview })
            let item = DirectoryEntry(url: URL(fileURLWithPath: "/editor/file.txt"), isDirectory: false, isSymbolicLink: link)
            await state.load(DetailsSelection(item: item, listingRevision: UUID()))
            #expect(state.canEdit == editable)
            state.setMode(.edit)
            #expect(state.mode == (editable ? .edit : .preview))
            await state.updateText("changed")?.value
            #expect(state.isDirty == editable)
            if !editable { #expect(state.preview == preview) }
        }
    }

    @Test @MainActor func dirtyLoadsCannotEraseDraftAndSameFileFocusRetainsItsIdentity() async {
        let state = PreviewState(read: { .text($0.name) })
        let first = editorSelection("first.txt")
        await state.load(first)
        state.setMode(.edit)
        await state.updateText("draft")?.value
        let document = state.documentID
        await state.load(editorSelection("second.txt"))
        await state.load(nil)
        #expect(state.selection == first && state.text == "draft" && state.isDirty)
        let sameFile = editorSelection("first.txt")
        await state.load(sameFile)
        #expect(state.selection == sameFile && state.documentID == document && state.text == "draft")
    }

    @Test @MainActor func editedHighlightingRejectsOldRangesAndPlainFallbackIsReadable() async throws {
        try await withTestRequestGate(of: String.self, returning: [SyntaxToken].self) { gate in
            let initial = [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)]
            let state = PreviewState(read: { _ in .text("let a") }, highlight: { text, name in
                if text == "let a" { return initial }
                return try await gate.request(text)
            })
            await state.load(editorSelection("file.swift"))
            state.setMode(.edit)
            let old = state.updateText("let longer = true")
            gate.track(old)
            _ = try await gate.waitForRequest(0)
            let latest = state.updateText("var b")
            gate.track(latest)
            _ = try await gate.waitForRequest(1)
            #expect(state.tokens == initial && state.text == "var b")
            try gate.finish(1, with: .success([SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)]))
            await latest?.value
            try gate.finish(0, with: .success([SyntaxToken(range: NSRange(location: 13, length: 4), kind: .literal)]))
            await old?.value
            #expect(state.tokens == [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)])
            #expect(state.text == "var b" && state.isDirty)

            let plain = PreviewState(read: { _ in .text("let value") })
            await plain.load(editorSelection("plain.txt"))
            plain.setMode(.edit)
            await plain.updateText("return value")?.value
            #expect(plain.text == "return value" && plain.tokens.isEmpty && plain.isDirty)
        }
    }

    @Test @MainActor func discardingAfterSaveDuringHighlightingRecoloursTheSavedDraft() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-highlight-save-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("sample.swift")
        try Data("let a".utf8).write(to: file)
        try await withTestRequestGate(of: String.self, returning: [SyntaxToken].self) { gate in
            let initial = [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)]
            let state = PreviewState(highlight: { text, _ in
                if text == "let a" { return initial }
                return try await gate.request(text)
            })
            await state.load(DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID()))
            state.setMode(.edit)
            let saved = state.updateText("\nlet a")
            gate.track(saved)
            _ = try await gate.waitForRequest(0)
            #expect(await state.save())
            let edited = state.updateText("// draft")
            gate.track(edited)
            _ = try await gate.waitForRequest(1)
            let discarded = state.discardChanges()
            gate.track(discarded)
            _ = try await gate.waitForRequest(2)
            try gate.finish(0, with: .success(initial))
            try gate.finish(1, with: .success([SyntaxToken(range: NSRange(location: 0, length: 8), kind: .comment)]))
            await saved?.value
            await edited?.value
            let expected = [SyntaxToken(range: NSRange(location: 1, length: 3), kind: .keyword)]
            try gate.finish(2, with: .success(expected))
            await discarded?.value
            #expect(state.text == "\nlet a" && !state.isDirty && state.tokens == expected)
            #expect(try String(contentsOf: file, encoding: .utf8) == "\nlet a")
        }
    }

    @Test(arguments: [false, true]) @MainActor
    func cancelledOrDiscardedTransitionsCoverSelectionFocusContextNavigationAndReload(discard: Bool) async {
        let root = URL(fileURLWithPath: "/editor", isDirectory: true)
        let entries = ["one.txt", "two.txt", ".hidden.txt"].map {
            DirectoryEntry(url: root.appendingPathComponent($0), isDirectory: false, isHidden: $0.hasPrefix("."))
        }
        for action in EditorTransition.allCases {
            let state = PreviewState(read: { _ in .text("original") })
            var prompts = 0
            let browser = BrowserState(homeDirectory: root,
                load: { DirectoryListing(directory: $0, entries: $0 == root ? entries : []) },
                preview: state, confirmChanges: { _, completion in prompts += 1; completion(discard ? .discard : .cancel) })
            await browser.left.navigate(to: root)
            await browser.right.navigate(to: root)
            browser.left.setSelection([entries[0].url])
            browser.right.setSelection([entries[1].url])
            await state.load(browser.detailsSelection)
            state.setMode(.edit)
            await state.updateText("draft")?.value
            let revision = browser.left.listingRevision
            var closed = 0
            switch action {
            case .selection: browser.left.setSelection([entries[1].url])
            case .focus: browser.focus(.right)
            case .context: browser.targetContextItem(entries[1].url, in: .left)
            case .navigation: await browser.left.navigate(to: root.deletingLastPathComponent())
            case .refresh: await browser.left.refresh()
            case .close: _ = browser.resolveChangesIfNeeded(resume: { closed += 1 })
            case .clear: browser.left.setSelection([])
            }
            let reload = discard && (action == .navigation || action == .refresh)
            if reload {
                let deadline = ContinuousClock.now.advanced(by: .seconds(5))
                while browser.left.listingRevision == revision && ContinuousClock.now < deadline { await Task.yield() }
            }
            #expect(prompts == 1)
            #expect(state.isDirty == !discard)
            #expect(state.text == (discard ? "original" : "draft"))
            #expect(browser.focusedPane == (discard && action == .focus ? .right : .left))
            #expect(browser.left.directory == (discard && action == .navigation ? root.deletingLastPathComponent() : root))
            #expect(!browser.left.isLoading)
            #expect(reload ? browser.left.listingRevision != revision : browser.left.listingRevision == revision,
                    "Unexpected listing publication after \(discard ? "Discard" : "Cancel") for \(action)")
            #expect(closed == (discard && action == .close ? 1 : 0))
            if discard && (action == .selection || action == .context) {
                #expect(browser.left.selectedItems == [entries[1].url])
                #expect(browser.left.primaryItemURL == entries[1].url)
            } else if discard && (action == .navigation || action == .clear) {
                #expect(browser.left.selectedItems.isEmpty && browser.left.primaryItemURL == nil)
            } else {
                #expect(browser.left.selectedItems == [entries[0].url])
                #expect(browser.left.primaryItemURL == entries[0].url)
            }
            #expect(browser.right.directory == root && browser.right.selectedItems == [entries[1].url])
            #expect(browser.right.primaryItemURL == entries[1].url)
        }
    }

    @Test(arguments: [false, true], [false, true]) @MainActor
    func deferredDecisionRetainsDraftUntilAnsweredAndResumesCapturedSelectionOrFocus(discard: Bool, focusing: Bool) async throws {
        let root = URL(fileURLWithPath: "/editor", isDirectory: true)
        let entries = ["one.txt", "two.txt"].map { DirectoryEntry(url: root.appendingPathComponent($0), isDirectory: false) }
        let preview = PreviewState(read: { _ in .text("original") })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        var prompts = 0
        var targeted = 0
        let browser = BrowserState(homeDirectory: root, load: { DirectoryListing(directory: $0, entries: entries) },
            preview: preview, confirmChanges: { _, completion in prompts += 1; answer = completion })
        await browser.left.navigate(to: root)
        await browser.right.navigate(to: root)
        browser.left.setSelection([entries[0].url])
        if focusing { browser.right.setSelection([entries[1].url]) }
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let completed: @MainActor () -> Void = {
            #expect(browser.focusedPane == .right)
            targeted += 1
        }
        let accepted = focusing ? browser.focus(.right, then: completed)
            : browser.targetContextItem(entries[1].url, in: .right, then: completed)
        #expect(!accepted)
        #expect(preview.isDirty && preview.text == "draft" && browser.focusedPane == .left)
        #expect(browser.left.selectedItems == [entries[0].url])
        #expect(browser.right.selectedItems == (focusing ? [entries[1].url] : []))
        #expect(!browser.focus(.right))
        #expect(prompts == 1)
        let completion = try #require(answer)
        completion(discard ? .discard : .cancel)
        #expect(preview.isDirty == !discard)
        #expect(targeted == (discard ? 1 : 0))
        #expect(browser.focusedPane == (discard ? .right : .left))
        #expect(browser.right.selectedItems == (focusing || discard ? [entries[1].url] : []))
        // A duplicate sheet completion must not replay a later transition.
        browser.right.setSelection([])
        completion(discard ? .discard : .cancel)
        #expect(browser.right.selectedItems.isEmpty)
        #expect(targeted == (discard ? 1 : 0))
        let unchanged = browser.focus(browser.focusedPane, then: { targeted += 1 })
        #expect(unchanged)
        #expect(targeted == (discard ? 2 : 1))
        #expect(prompts == 1)
    }

    @Test @MainActor func staleDiscardAnswerCannotEraseAReplacementDocument() async throws {
        let preview = PreviewState(read: { .text($0.name) })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(preview: preview, confirmChanges: { _, completion in answer = completion })
        await preview.load(editorSelection("one.txt"))
        preview.setMode(.edit)
        await preview.updateText("first draft")?.value
        var resumed = false
        let continued = browser.resolveChangesIfNeeded(resume: { resumed = true })
        #expect(!continued)
        let completion = try #require(answer)
        preview.discardChanges()
        await preview.load(editorSelection("two.txt"))
        preview.setMode(.edit)
        await preview.updateText("replacement draft")?.value
        completion(.discard)
        #expect(preview.text == "replacement draft" && preview.isDirty && !resumed)
    }

    @Test @MainActor func deferredFavouriteWaitsForDiscardBeforeLoadingItsCapturedDirectory() async throws {
        try await withTestRequestGate(of: URL.self, returning: DirectoryListing.self) { gate in
            let root = URL(fileURLWithPath: "/editor", isDirectory: true)
            let target = root.appendingPathComponent("child", isDirectory: true)
            let item = DirectoryEntry(url: root.appendingPathComponent("one.txt"), isDirectory: false)
            let preview = PreviewState(read: { _ in .text("original") })
            var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
            var prompts = 0
            let browser = BrowserState(homeDirectory: root,
                load: { url in url == root ? DirectoryListing(directory: root, entries: [item]) : try await gate.request(url) },
                preview: preview, confirmChanges: { _, completion in prompts += 1; answer = completion })
            await browser.left.navigate(to: root)
            browser.left.setSelection([item.url])
            await preview.load(browser.detailsSelection)
            preview.setMode(.edit)
            await preview.updateText("draft")?.value
            await browser.openFavourite(target).value
            #expect(preview.isDirty && browser.left.directory == root && !browser.left.isLoading)
            #expect(!browser.focus(.right) && prompts == 1)
            let completion = try #require(answer)
            completion(.discard)
            let requested = try await gate.waitForRequest(0)
            #expect(requested == target)
            #expect(browser.focusedPane == .left && !preview.isDirty)
            try gate.finish(0, with: .success(DirectoryListing(directory: target, entries: [])))
            try await waitForState { !browser.left.isLoading }
            #expect(browser.left.directory == target)
        }
    }

    @Test @MainActor func hidingDirtyPrimaryCancelsVisibilityButOtherPaneChangesDoNotPrompt() async {
        let root = URL(fileURLWithPath: "/editor", isDirectory: true)
        let hidden = DirectoryEntry(url: root.appendingPathComponent(".hidden.txt"), isDirectory: false, isHidden: true)
        let state = PreviewState(read: { _ in .text("original") })
        var prompts = 0
        let browser = BrowserState(homeDirectory: root, load: { DirectoryListing(directory: $0, entries: [hidden]) },
            preview: state, confirmChanges: { _, completion in prompts += 1; completion(.cancel) })
        await browser.left.navigate(to: root)
        await browser.right.navigate(to: root)
        browser.left.showHiddenFiles = true
        browser.left.setSelection([hidden.url])
        await state.load(browser.detailsSelection)
        state.setMode(.edit)
        await state.updateText("draft")?.value
        browser.left.showHiddenFiles = false
        #expect(browser.left.showHiddenFiles && browser.left.primaryItemURL == hidden.url)
        #expect(prompts == 1 && state.text == "draft" && state.isDirty)
        browser.right.showHiddenFiles = true
        await browser.right.navigate(to: root.deletingLastPathComponent())
        #expect(prompts == 1 && state.isDirty)
    }

    @Test @MainActor func pendingNavigationCannotPublishOverNewEdits() async throws {
        try await withTestRequestGate(of: URL.self, returning: DirectoryListing.self) { gate in
            let root = URL(fileURLWithPath: "/editor", isDirectory: true)
            let entry = DirectoryEntry(url: root.appendingPathComponent("one.txt"), isDirectory: false)
            let state = PreviewState(read: { _ in .text("original") })
            var prompts = 0
            let browser = BrowserState(homeDirectory: root,
                load: { url in url == root ? DirectoryListing(directory: root, entries: [entry]) : try await gate.request(url) },
                preview: state, confirmChanges: { _, completion in prompts += 1; completion(.cancel) })
            await browser.left.navigate(to: root)
            browser.left.setSelection([entry.url])
            await state.load(browser.detailsSelection)
            let pending = Task { await browser.left.navigate(to: root.deletingLastPathComponent()) }
            gate.track(pending)
            let requested = try await gate.waitForRequest(0)
            state.setMode(.edit)
            await state.updateText("new draft")?.value
            try gate.finish(0, with: .success(DirectoryListing(directory: requested, entries: [])))
            await pending.value
            #expect(prompts == 1 && browser.left.directory == root && !browser.left.isLoading)
            #expect(browser.left.primaryItemURL == entry.url && state.text == "new draft" && state.isDirty)
        }
    }

    @Test @MainActor func cancellingOtherPaneContextTargetRetainsFocusEvenWhenItAlreadyShowsTheSameFile() async {
        let root = URL(fileURLWithPath: "/editor", isDirectory: true)
        let entries = ["one.txt", "two.txt"].map { DirectoryEntry(url: root.appendingPathComponent($0), isDirectory: false) }
        let state = PreviewState(read: { _ in .text("original") })
        let browser = BrowserState(homeDirectory: root, load: { DirectoryListing(directory: $0, entries: entries) },
                                   preview: state, confirmChanges: { _, completion in completion(.cancel) })
        await browser.left.navigate(to: root)
        await browser.right.navigate(to: root)
        browser.left.setSelection([entries[0].url])
        browser.right.setSelection([entries[0].url])
        await state.load(browser.detailsSelection)
        state.setMode(.edit)
        await state.updateText("draft")?.value
        #expect(!browser.targetContextItem(entries[1].url, in: .right))
        #expect(browser.focusedPane == .left)
        #expect(browser.left.selectedItems == [entries[0].url] && browser.right.selectedItems == [entries[0].url])
        #expect(state.text == "draft" && state.isDirty)
    }

    @Test @MainActor func draftEditingPreservesDiskBytesAndStaleLinkRowsStayReadOnly() async throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("panepeek-editor-\(UUID())", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.txt")
        let bytes = Data([0xEF, 0xBB, 0xBF]) + Data("é 👀\r\nnext\nlast\r".utf8)
        try bytes.write(to: url)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        await state.updateText("draft")?.value
        state.setMode(.preview)
        #expect(state.isDirty)
        #expect(try Data(contentsOf: url) == bytes)
        state.discardChanges()
        #expect((try Data(contentsOf: url)) == bytes)
        let link = root.appendingPathComponent("stale.txt")
        try files.createSymbolicLink(at: link, withDestinationURL: url)
        await state.load(DetailsSelection(item: DirectoryEntry(url: link, isDirectory: false), listingRevision: UUID()))
        #expect(state.text == "é 👀\r\nnext\nlast\r" && !state.canEdit)
        state.setMode(.edit)
        #expect(state.mode == .preview)
    }
}

private enum EditorTransition: CaseIterable {
    case selection, focus, context, navigation, refresh, close, clear
}

private func editorSelection(_ name: String) -> DetailsSelection {
    DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/editor/\(name)"), isDirectory: false), listingRevision: UUID())
}
