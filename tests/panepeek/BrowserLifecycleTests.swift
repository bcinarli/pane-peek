import AppKit
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserLifecycleTests {
    @Test func aboutReopeningAndClosureRetainTheBrowserDraftAndQuitGuard() async throws {
        let lifecycle = BrowserLifecycle()
        let preview = try await dirtyPreview("about.txt")
        var prompts = 0
        let fixture = WindowFixture(lifecycle: lifecycle, preview: preview, present: { _, _, completion in
            prompts += 1
            completion(.cancel)
        })
        defer { fixture.finish() }
        fixture.window.orderFront(nil)
        let browserWindows = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        AboutPanel.show()
        let about = try #require(NSApplication.shared.windows.first { !browserWindows.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { about.close() }
        AboutPanel.show()
        #expect(NSApplication.shared.windows.filter { !browserWindows.contains(ObjectIdentifier($0)) && $0.isVisible }.count == 1)
        #expect(!about.isRestorable)
        about.cancelOperation(nil)
        #expect(!about.isVisible && fixture.window.isVisible)
        AboutPanel.show()
        let reopened = try #require(NSApplication.shared.windows.first { !browserWindows.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { reopened.close() }
        reopened.performClose(nil)
        #expect(!reopened.isVisible && fixture.window.isVisible)
        #expect(preview.isDirty && preview.text == "about.txt draft")
        #expect(await lifecycle.prepareToQuit() == false)
        #expect(prompts == 1 && preview.isDirty)
    }

    @Test func replacingANativeGuardRetainsRegistrationPromptsAndDelegateForwarding() async throws {
        let lifecycle = BrowserLifecycle()
        let preview = try await dirtyPreview("source.txt")
        var prompts = 0
        let original = LifecycleDelegateRecorder()
        let fixture = WindowFixture(lifecycle: lifecycle, preview: preview,
            present: { _, _, completion in prompts += 1; completion(.cancel) }, originalDelegate: original)
        let replacement = BrowserWindowGuard.GuardView()
        replacement.browser = fixture.browser
        replacement.prompts = fixture.prompts
        replacement.lifecycle = lifecycle
        fixture.view.addSubview(replacement)
        fixture.view.uninstall()
        defer { replacement.uninstall(); fixture.finish() }
        #expect(fixture.prompts.window === fixture.window)
        #expect(await lifecycle.prepareToQuit() == false)
        #expect(prompts == 1 && preview.isDirty)
        let previous = original.activations
        fixture.window.delegate?.windowDidBecomeKey?(Notification(name: NSWindow.didBecomeKeyNotification, object: fixture.window))
        #expect(original.activations == previous + 1)
        #expect(fixture.window.delegate?.responds(to: #selector(NSWindowDelegate.windowShouldZoom(_:toFrame:))) == true)
        #expect(fixture.window.delegate?.windowShouldZoom?(fixture.window, toFrame: .zero) == false)
        #expect(original.zoomRequests == 1)
    }

    @Test func submittedDropReservesMutationBeforeItsTaskAndPreventsQuit() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("source.txt")
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try Data("original".utf8).write(to: file)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let lifecycle = BrowserLifecycle()
        let fixture = WindowFixture(lifecycle: lifecycle)
        defer { fixture.finish() }
        await fixture.browser.left.navigate(to: destination)
        let operation = try #require(fixture.browser.submitDrop([file], into: .left, operation: .copy))
        #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        await operation.value
        #expect(fixture.browser.copyOutcome?.succeeded == true)
        #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }

    @Test func quitFindsADirtyDocumentOutsideTheLastRegisteredWindow() async throws {
        let lifecycle = BrowserLifecycle()
        let preview = try await dirtyPreview("first.txt")
        var prompts = 0
        let first = WindowFixture(lifecycle: lifecycle, preview: preview, present: { _, owner, completion in
            #expect(owner.title == "first")
            prompts += 1
            completion(.cancel)
        })
        first.window.title = "first"
        let second = WindowFixture(lifecycle: lifecycle)
        defer { first.finish(); second.finish() }

        #expect(await lifecycle.prepareToQuit() == false)
        #expect(prompts == 1)
        #expect(preview.isDirty && preview.text == "first.txt draft")
    }

    @Test func dirtyPromptUsesItsOwningWindowAfterAnotherWindowRegisters() async throws {
        let lifecycle = BrowserLifecycle()
        let preview = try await dirtyPreview("first.txt")
        let first = WindowFixture(lifecycle: lifecycle, preview: preview)
        let second = WindowFixture(lifecycle: lifecycle)
        defer { first.finish(); second.finish() }

        #expect(!first.browser.resolveChangesIfNeeded())
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while first.window.attachedSheet == nil && second.window.attachedSheet == nil && ContinuousClock.now < deadline {
            await Task.yield()
        }
        #expect(first.window.attachedSheet != nil)
        #expect(second.window.attachedSheet == nil)
    }

    @Test(arguments: [false, true])
    func laterCancellationOrFailedSaveRetainsEarlierDiscardedDraft(failedSave: Bool) async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = BrowserLifecycle()
        let firstPreview = try await dirtyPreview("first.txt", root: root)
        let secondPreview = try await dirtyPreview("second.txt", root: root, failSave: failedSave)
        let first = WindowFixture(lifecycle: lifecycle, preview: firstPreview, present: { _, _, completion in
            completion(.discard)
        })
        let second = WindowFixture(lifecycle: lifecycle, preview: secondPreview, present: { _, _, completion in
            #expect(firstPreview.isDirty && firstPreview.text == "first.txt draft")
            completion(failedSave ? .save : .cancel)
        })
        defer { first.finish(); second.finish() }

        #expect(await lifecycle.prepareToQuit() == false)
        #expect(firstPreview.isDirty && firstPreview.text == "first.txt draft")
        #expect(secondPreview.isDirty && secondPreview.text == "second.txt draft")
        #expect((secondPreview.errorMessage != nil) == failedSave)
        #expect(try String(contentsOf: root.appendingPathComponent("first.txt"), encoding: .utf8) == "original")
    }

    @Test func successfulQuitSavesAndThenAppliesDeferredDiscards() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = BrowserLifecycle()
        let firstPreview = try await dirtyPreview("first.txt", root: root)
        let secondPreview = try await dirtyPreview("second.txt", root: root)
        let first = WindowFixture(lifecycle: lifecycle, preview: firstPreview, present: { _, _, completion in
            completion(.save)
        })
        let second = WindowFixture(lifecycle: lifecycle, preview: secondPreview, present: { _, _, completion in
            completion(.discard)
        })
        defer { first.finish(); second.finish() }

        #expect(await lifecycle.prepareToQuit())
        #expect(!firstPreview.isDirty && !secondPreview.isDirty)
        #expect(firstPreview.text == "first.txt draft" && secondPreview.text == "original")
        #expect(try String(contentsOf: root.appendingPathComponent("first.txt"), encoding: .utf8) == "first.txt draft")
        #expect(try String(contentsOf: root.appendingPathComponent("second.txt"), encoding: .utf8) == "original")
    }

    @Test(arguments: [false, true])
    func changedDocumentAndDuplicateAnswersCannotDiscardOrStartAnotherQuit(equivalentUnicode: Bool) async throws {
        let lifecycle = BrowserLifecycle()
        let preview = try await dirtyPreview("first.txt")
        if equivalentUnicode { await preview.updateText("\u{e9}")?.value }
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let first = WindowFixture(lifecycle: lifecycle, preview: preview, present: { _, _, completion in answer = completion })
        defer { first.finish() }
        let quit = Task { await lifecycle.prepareToQuit() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while answer == nil && ContinuousClock.now < deadline { await Task.yield() }
        let completion = try #require(answer)
        #expect(await lifecycle.prepareToQuit() == false)
        #expect(first.window.delegate?.windowShouldClose?(first.window) == false)
        let newText = equivalentUnicode ? "e\u{301}" : "new draft"
        await preview.updateText(newText)?.value
        completion(.discard)
        completion(.discard)
        #expect(await quit.value == false)
        #expect(preview.isDirty && preview.text?.utf8.elementsEqual(newText.utf8) == true)
    }

    @Test func closingAWindowRemovesItsDraftFromQuitAndDoesNotRetargetItsPrompt() async throws {
        let lifecycle = BrowserLifecycle()
        let preview = try await dirtyPreview("closed.txt")
        var presented = 0
        let first = WindowFixture(lifecycle: lifecycle, preview: preview, present: { _, _, _ in presented += 1 })
        let second = WindowFixture(lifecycle: lifecycle)
        defer { first.finish(); second.finish() }
        first.window.close()
        var choice: BrowserState.UnsavedChoice?
        first.prompts.confirmChanges("closed.txt") { choice = $0 }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while choice == nil && ContinuousClock.now < deadline { await Task.yield() }
        #expect(choice == .cancel)
        #expect(presented == 0)
        #expect(await lifecycle.prepareToQuit())
        #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }

    @Test func savingTheSameFileInTwoWindowsStopsQuitAndRetainsTheSecondDraft() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = BrowserLifecycle()
        let firstPreview = try await dirtyPreview("shared.txt", root: root)
        let secondPreview = try await dirtyPreview("shared.txt", root: root)
        await secondPreview.updateText("second draft")?.value
        let save: BrowserPrompts.Present = { _, _, completion in completion(.save) }
        let first = WindowFixture(lifecycle: lifecycle, preview: firstPreview, present: save)
        let second = WindowFixture(lifecycle: lifecycle, preview: secondPreview, present: save)
        defer { first.finish(); second.finish() }

        #expect(await lifecycle.prepareToQuit() == false)
        #expect(!firstPreview.isDirty)
        #expect(secondPreview.isDirty && secondPreview.text == "second draft" && secondPreview.errorMessage != nil)
        #expect(try String(contentsOf: root.appendingPathComponent("shared.txt"), encoding: .utf8) == "shared.txt draft")
    }

    private func dirtyPreview(_ name: String, root: URL? = nil, failSave: Bool = false) async throws -> PreviewState {
        let url = (root ?? URL(fileURLWithPath: "/fixture")).appendingPathComponent(name)
        let preview: PreviewState
        if root != nil {
            if !FileManager.default.fileExists(atPath: url.path) { try Data("original".utf8).write(to: url) }
            preview = PreviewState(write: { snapshot, text, destination in
                if failSave { throw CocoaError(.fileWriteNoPermission) }
                return try await snapshot.save(text, to: destination)
            })
        } else {
            preview = PreviewState(read: { _ in .text("original") })
        }
        let item = DirectoryEntry(url: url, isDirectory: false, isHidden: false)
        await preview.load(DetailsSelection(item: item, listingRevision: UUID()))
        preview.setMode(.edit)
        await preview.updateText(name + " draft")?.value
        return preview
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-lifecycle-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

@MainActor private final class WindowFixture {
    let window: NSWindow
    let view = BrowserWindowGuard.GuardView()
    let browser: BrowserState
    let prompts: BrowserPrompts

    init(lifecycle: BrowserLifecycle, preview: PreviewState? = nil, present: BrowserPrompts.Present? = nil,
         originalDelegate: (any NSWindowDelegate)? = nil) {
        _ = NSApplication.shared
        prompts = present.map { BrowserPrompts(present: $0) } ?? BrowserPrompts()
        browser = BrowserState(operations: lifecycle.operations, preview: preview, resolveTransferCollision: prompts.resolveTransferCollision,
                               confirmChanges: prompts.confirmChanges)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.delegate = originalDelegate
        view.browser = browser
        view.prompts = prompts
        view.lifecycle = lifecycle
        window.contentView = view
        window.orderFront(nil)
    }

    func finish() {
        if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .cancel) }
        window.orderOut(nil)
        view.uninstall()
    }
}

@MainActor private final class LifecycleDelegateRecorder: NSObject, NSWindowDelegate {
    var activations = 0
    var zoomRequests = 0
    func windowDidBecomeKey(_ notification: Notification) { activations += 1 }
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        zoomRequests += 1
        return false
    }
}
