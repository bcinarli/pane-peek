import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct ItemCreationTests {
    @Test(arguments: ["", ".", "..", "parent/child", "bad\0name"])
    func rejectsInvalidNames(name: String) async throws {
        #expect(throws: ItemName.ValidationError.invalid) { try ItemName.validate(name) }
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        await #expect(throws: ItemName.ValidationError.invalid) {
            try await ItemCreation.create(.textFile, named: name, in: fixture.root)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).isEmpty)
    }

    @Test(arguments: ["notes.txt", "café 👀.txt", " spaced ", ".env", "back\\slash.txt"])
    func keepsValidNamesExactly(name: String) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        try ItemName.validate(name)
        let url = try await ItemCreation.create(.textFile, named: name, in: fixture.root)
        #expect(url.lastPathComponent == name)
        #expect(try Data(contentsOf: url).isEmpty)
        #expect(try await TextPreview.read(DirectoryEntry(url: url, isDirectory: false)) == .text(""))
    }

    @Test(arguments: ItemCreation.Kind.allCases)
    func createsEmptyItem(kind: ItemCreation.Kind) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let url = try await ItemCreation.create(kind, named: "new item", in: fixture.root)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue == (kind == .folder))
        if kind == .folder {
            #expect(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
        } else {
            #expect(try Data(contentsOf: url).isEmpty)
        }
    }

    @Test(arguments: ItemCreation.Kind.allCases, ["file", "folder", "link", "broken-link"])
    func collisionsPreserveExistingItems(kind: ItemCreation.Kind, existing: String) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let url = fixture.root.appendingPathComponent("occupied")
        let target = try fixture.file("target.txt")
        switch existing {
        case "file": try Data("keep me".utf8).write(to: url)
        case "folder":
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            try Data("keep me".utf8).write(to: url.appendingPathComponent("child"))
        default:
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL:
                existing == "link" ? target : fixture.root.appendingPathComponent("missing"))
        }
        await #expect(throws: ItemName.ValidationError.collision) {
            try await ItemCreation.create(kind, named: "occupied", in: fixture.root)
        }
        switch existing {
        case "file": #expect(try Data(contentsOf: url) == Data("keep me".utf8))
        case "folder": #expect(try Data(contentsOf: url.appendingPathComponent("child")) == Data("keep me".utf8))
        default: #expect(try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
            == (existing == "link" ? target.path : fixture.root.appendingPathComponent("missing").path))
        }
        #expect(try Data(contentsOf: target) == Data("original".utf8))
    }

    @Test(arguments: ItemCreation.Kind.allCases)
    func concurrentCreationHasOnlyOneWinner(kind: ItemCreation.Kind) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let create: @Sendable () async -> Bool = {
            do {
                _ = try await ItemCreation.create(kind, named: "contended", in: fixture.root)
                return true
            } catch { return false }
        }
        async let first = create()
        async let second = create()
        let results = await [first, second]
        #expect(results.filter { $0 }.count == 1)
    }

    @Test func collisionsFollowTheFilesystemCaseRules() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("case.txt")
        let alias = fixture.root.appendingPathComponent("CASE.txt")
        if FileManager.default.fileExists(atPath: alias.path) {
            await #expect(throws: ItemName.ValidationError.collision) {
                try await ItemCreation.create(.textFile, named: "CASE.txt", in: fixture.root)
            }
        } else {
            #expect(try await ItemCreation.create(.textFile, named: "CASE.txt", in: fixture.root) == alias)
        }
        #expect(try Data(contentsOf: original) == Data("original".utf8))
    }

    @Test func missingParentDoesNotCreateIntermediates() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let missing = fixture.root.appendingPathComponent("missing", isDirectory: true)
        await #expect(throws: POSIXError(.ENOENT)) {
            try await ItemCreation.create(.folder, named: "child", in: missing)
        }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    @Test func creationThroughDirectoryAliasReturnsCanonicalIdentity() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let target = fixture.root.appendingPathComponent("target", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let created = try await ItemCreation.create(.textFile, named: "new.txt", in: alias)
        #expect(created == target.appendingPathComponent("new.txt"))
        #expect(try Data(contentsOf: created).isEmpty)
    }
}

struct BrowserCreationTests {
    @Test @MainActor func pendingDirtyDecisionBlocksAnotherCreationEvenIfTheDraftBecomesClean() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("original.txt")
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, completion in answer = completion })
        await browser.left.refresh()
        browser.left.setSelection([original])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        #expect(browser.canCreate())
        browser.beginCreation(.textFile)
        let completion = try #require(answer)
        defer { completion(.cancel) }
        #expect(browser.creationRequest == nil && !browser.canCreate())
        await browser.preview.updateText("original")?.value
        #expect(!browser.preview.isDirty && !browser.canCreate())
        browser.beginCreation(.folder)
        #expect(browser.creationRequest == nil)
        completion(.cancel)
        #expect(browser.canCreate())
        browser.beginCreation(.folder)
        #expect(browser.creationRequest?.kind == .folder)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["original.txt"])
    }

    @Test @MainActor func creationAvailabilityRecoversAfterASharedSave() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("original.txt")
        let gate = OperationGate()
        let preview = PreviewState(write: { snapshot, text, url in
            try await gate.pause()
            return try await snapshot.save(text, to: url)
        })
        let first = BrowserState(homeDirectory: fixture.root, preview: preview)
        let second = BrowserState(homeDirectory: fixture.root, operations: first.operations)
        await first.left.refresh()
        first.left.setSelection([original])
        await preview.load(first.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        #expect(first.canCreate() && second.canCreate())
        let saving = Task { await preview.save() }
        try await gate.waitForRequest()
        #expect(preview.isSaving && !first.canCreate() && !second.canCreate())
        first.beginCreation(.folder)
        second.beginCreation(.textFile)
        #expect(first.creationRequest == nil && second.creationRequest == nil)
        try await gate.finish()
        #expect(await saving.value)
        #expect(first.canCreate() && second.canCreate())
        #expect(try Data(contentsOf: original) == Data("draft".utf8))
    }

    @Test @MainActor func creationBeforeFirstAliasListingSelectsTheCanonicalResult() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let target = fixture.root.appendingPathComponent("target", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let browser = BrowserState(homeDirectory: alias)
        browser.beginCreation(.textFile)
        await browser.submitCreation(named: ".new.txt")
        let created = target.appendingPathComponent(".new.txt")
        #expect(browser.creationError == nil && browser.left.primaryItemURL == created)
        #expect(browser.left.directory == target && browser.left.showHiddenFiles)
        #expect(browser.right.directory == target && !browser.right.showHiddenFiles)
        #expect(try Data(contentsOf: created).isEmpty)
    }

    @Test(arguments: [false, true], [false, true]) @MainActor
    func initialAliasListingCanPublishDuringThePromptOrCreation(beforeSubmission: Bool, slowListing: Bool) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let target = fixture.root.appendingPathComponent("target", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let kept = target.appendingPathComponent("kept.txt")
        try Data("keep".utf8).write(to: kept)
        let listingGate = OperationGate(timeout: .seconds(30))
        let creationGate = OperationGate(timeout: .seconds(30))
        let browser = BrowserState(homeDirectory: alias, load: { directory in
            if directory == alias {
                if slowListing { try await Task.sleep(for: .seconds(6)) }
                try await listingGate.pause()
            }
            return try await DirectoryListing.read(directory)
        }, create: { kind, name, directory in
            try await creationGate.create(kind, name: name, directory: directory)
        })
        let initialRead = Task { await browser.left.refresh() }
        try await listingGate.waitForRequest()
        await browser.right.navigate(to: target)
        browser.right.setSelection([kept])
        let revision = browser.right.listingRevision
        browser.beginCreation(.textFile)
        _ = try #require(browser.creationRequest)
        if beforeSubmission {
            try await listingGate.finish()
            await initialRead.value
        }
        let creation = Task { await browser.submitCreation(named: "new.txt") }
        try await creationGate.waitForRequest()
        #expect(browser.isCreating && browser.creationError == nil)
        if !beforeSubmission {
            try await listingGate.finish()
            await initialRead.value
        }
        try await creationGate.finish()
        await creation.value
        let created = target.appendingPathComponent("new.txt")
        #expect(browser.creationError == nil && browser.left.primaryItemURL == created)
        #expect(browser.right.listingRevision != revision && browser.right.selectedItems == [kept])
        #expect(browser.right.entries.contains { $0.url == created })
        #expect(try Data(contentsOf: created).isEmpty)
    }

    @Test(arguments: [false, true], [PaneID.left, .right]) @MainActor
    func creationDoesNotReplaceNavigationThatIsStillLoading(finishNavigationFirst: Bool, navigatingPane: PaneID) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let elsewhere = fixture.root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
        let listingGate = OperationGate(timeout: .seconds(30))
        let creationGate = OperationGate(timeout: .seconds(30))
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if directory == elsewhere { try await listingGate.pause() }
            return try await DirectoryListing.read(directory)
        }, create: { kind, name, directory in
            try await creationGate.create(kind, name: name, directory: directory)
        })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.beginCreation(.textFile)
        let creation = Task { await browser.submitCreation(named: ".captured.txt") }
        try await creationGate.waitForRequest()
        let target = browser.pane(navigatingPane)
        let navigation = Task { await target.navigate(to: elsewhere) }
        try await listingGate.waitForRequest()
        #expect(target.isLoading && target.directory == fixture.root)
        if finishNavigationFirst {
            try await listingGate.finish()
            await navigation.value
        }
        try await creationGate.finish()
        await creation.value
        if !finishNavigationFirst {
            #expect(target.isLoading && !target.showHiddenFiles)
            try await listingGate.finish()
            await navigation.value
        }
        #expect(target.directory == elsewhere && target.selectedItems.isEmpty)
        #expect(!target.showHiddenFiles && !browser.isCreating && browser.creationError == nil)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent(".captured.txt")).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent(".captured.txt").path))
    }

    @Test @MainActor func creationLeavesEarlierPendingNavigationUntouched() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let elsewhere = fixture.root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
        let listingGate = OperationGate(timeout: .seconds(30))
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if directory == elsewhere { try await listingGate.pause() }
            return try await DirectoryListing.read(directory)
        })
        await browser.left.refresh()
        let navigation = Task { await browser.left.navigate(to: elsewhere) }
        try await listingGate.waitForRequest()
        browser.beginCreation(.textFile)
        await browser.submitCreation(named: ".captured.txt")
        #expect(browser.left.isLoading && !browser.left.showHiddenFiles)
        try await listingGate.finish()
        await navigation.value
        #expect(browser.left.directory == elsewhere && browser.left.selectedItems.isEmpty)
        #expect(browser.creationError == nil)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent(".captured.txt")).isEmpty)
    }

    @Test @MainActor func creationRefreshUsesAMatchingPendingDestination() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let target = fixture.root.appendingPathComponent("target", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let oldSelection = try fixture.file("old.txt")
        let listingGate = OperationGate(timeout: .seconds(30))
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if directory == alias { try await listingGate.pause() }
            return try await DirectoryListing.read(directory)
        })
        await browser.left.navigate(to: target)
        await browser.right.refresh()
        browser.right.setSelection([oldSelection])
        let navigation = Task { await browser.right.navigate(to: alias) }
        try await listingGate.waitForRequest()
        browser.beginCreation(.textFile)
        await browser.submitCreation(named: "new.txt")
        let created = target.appendingPathComponent("new.txt")
        #expect(browser.left.primaryItemURL == created && browser.creationError == nil)
        #expect(browser.right.directory == target && browser.right.selectedItems.isEmpty)
        #expect(browser.right.entries.contains { $0.url == created })
        try await listingGate.finish()
        await navigation.value
        #expect(browser.right.directory == target && !browser.right.showHiddenFiles)
        #expect(try Data(contentsOf: created).isEmpty)
    }

    @Test(arguments: ItemCreation.Kind.allCases, [false, true]) @MainActor
    func selectsCreatedItemAndRefreshesMatchingPanes(kind: ItemCreation.Kind, hidden: Bool) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let kept = try fixture.file("kept.txt")
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([kept])
        browser.right.setSelection([kept])
        await browser.right.sort(by: .lastModified)
        let revision = browser.left.listingRevision
        browser.beginCreation(kind, in: .right)
        let request = try #require(browser.creationRequest)
        #expect(request.directory == fixture.root && request.pane == .right)
        let name = hidden ? ".new" : "new"
        await browser.submitCreation(named: name)
        let created = fixture.root.appendingPathComponent(name, isDirectory: kind == .folder)
        #expect(browser.creationRequest == nil && !browser.isCreating && browser.creationError == nil)
        #expect(browser.right.primaryItemURL == created && browser.right.selectedItems == [created])
        #expect(browser.right.sortField == .lastModified && browser.right.showHiddenFiles == hidden)
        #expect(browser.left.listingRevision != revision && browser.left.selectedItems == [kept])
        #expect(!browser.left.showHiddenFiles && browser.focusedPane == .right)
        #expect(browser.left.entries.contains { $0.url == created } == !hidden)
        await browser.preview.load(browser.detailsSelection)
        if kind == .textFile {
            #expect(browser.preview.text == "" && browser.preview.canEdit)
            browser.preview.setMode(.edit)
            await browser.preview.updateText("new text")?.value
            #expect(await browser.preview.save())
            #expect(try Data(contentsOf: created) == Data("new text".utf8))
        }
    }

    @Test @MainActor func invalidSubmissionAndNameSheetCancelDoNotMutate() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let browser = BrowserState(homeDirectory: fixture.root)
        browser.beginCreation(.textFile)
        let request = try #require(browser.creationRequest)
        #expect(!browser.canCreate())
        await browser.submitCreation(named: "../escape")
        #expect(browser.creationRequest?.id == request.id && browser.creationError != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).isEmpty)
        browser.cancelCreation()
        #expect(browser.creationRequest == nil && browser.creationError == nil && browser.canCreate())
    }

    @Test(arguments: [BrowserState.UnsavedChoice.cancel, .discard, .save]) @MainActor
    func creationResolvesDirtyDocumentBeforePrompting(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("original.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, answer in
            prompts += 1
            answer(choice)
        })
        await browser.left.refresh()
        browser.left.setSelection([original])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        browser.beginCreation(.textFile)
        if choice == .save {
            try await waitForCreation { browser.creationRequest != nil }
        }
        #expect(prompts == 1)
        #expect((browser.creationRequest != nil) == (choice != .cancel))
        #expect(browser.preview.isDirty == (choice == .cancel))
        #expect(try Data(contentsOf: original) == Data((choice == .save ? "draft" : "original").utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["original.txt"])
    }

    @Test @MainActor func failedSaveAbortsCreationAndKeepsTheDraft() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("original.txt")
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        let browser = BrowserState(homeDirectory: fixture.root, preview: preview, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        browser.left.setSelection([original])
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        browser.beginCreation(.folder)
        try await waitForCreation { preview.errorMessage != nil }
        #expect(browser.creationRequest == nil && preview.isDirty && preview.text == "draft")
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["original.txt"])
    }

    @Test @MainActor func duplicateSubmissionAndLateCompletionKeepTheCapturedDirectory() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let elsewhere = fixture.root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
        let gate = OperationGate(timeout: .seconds(30))
        let browser = BrowserState(homeDirectory: fixture.root, create: { kind, name, directory in
            try await gate.create(kind, name: name, directory: directory)
        })
        await browser.left.refresh()
        await browser.right.navigate(to: elsewhere)
        browser.beginCreation(.textFile)
        _ = try #require(browser.creationRequest)
        let operation = Task { await browser.submitCreation(named: "captured.txt") }
        try await waitForCreation { browser.isCreating }
        try await gate.waitForRequest()
        #expect(!browser.canCreate())
        await browser.submitCreation(named: "duplicate.txt")
        browser.beginCreation(.folder)
        #expect(browser.creationRequest == nil)
        await browser.left.navigate(to: elsewhere)
        browser.focus(.right)
        try await gate.finish()
        await operation.value
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("captured.txt")).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent("captured.txt").path))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("duplicate.txt").path))
        #expect(browser.left.directory == elsewhere && browser.left.selectedItems.isEmpty)
        #expect(browser.focusedPane == .right && !browser.isCreating && browser.creationError == nil)
        #expect(browser.canCreate())
    }

    @Test @MainActor func stalePromptAndHiddenPaneCannotSubmit() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let browser = BrowserState(homeDirectory: fixture.root)
        #expect(browser.canCreate(in: .left) && browser.canCreate(in: .right))
        browser.setMode(.onePane)
        #expect(browser.canCreate() && browser.canCreate(in: .left) && !browser.canCreate(in: .right))
        browser.beginCreation(.textFile, in: .right)
        #expect(browser.creationRequest == nil)
        browser.beginCreation(.textFile)
        _ = try #require(browser.creationRequest)
        await browser.left.navigate(to: fixture.root.deletingLastPathComponent())
        await browser.submitCreation(named: "stale.txt")
        #expect(browser.creationRequest == nil && browser.creationError != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).isEmpty)
    }

    @Test @MainActor func creationFailurePreservesSelectionAndVisibility() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let kept = try fixture.file("kept.txt")
        let browser = BrowserState(homeDirectory: fixture.root, create: { _, _, _ in throw POSIXError(.EACCES) })
        await browser.left.refresh()
        browser.left.setSelection([kept])
        browser.beginCreation(.textFile)
        _ = try #require(browser.creationRequest)
        await browser.submitCreation(named: ".failed")
        #expect(browser.creationRequest == nil && browser.creationError != nil && !browser.isCreating)
        #expect(browser.left.selectedItems == [kept] && !browser.left.showHiddenFiles)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["kept.txt"])
    }

    @Test @MainActor func successfulCreationWithFailedRefreshReportsTheCreatedPath() async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let kept = try fixture.file("kept.txt")
        let listing = FailingCreationListing()
        let browser = BrowserState(homeDirectory: fixture.root, load: { try await listing.read($0) }, create: {
            try await listing.create($0, name: $1, directory: $2)
        })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([kept])
        browser.beginCreation(.textFile)
        await browser.submitCreation(named: "created.txt")
        let created = fixture.root.appendingPathComponent("created.txt")
        #expect(try Data(contentsOf: created).isEmpty)
        #expect(browser.creationError?.contains("Created \(created.path)") == true)
        #expect(browser.left.errorMessage != nil && browser.right.errorMessage != nil)
        #expect(browser.left.selectedItems == [kept] && !browser.isCreating)
    }

    @Test(arguments: [false, true]) @MainActor
    func draftStartedDuringCreationGuardsResultSelection(discard: Bool) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("original.txt")
        let gate = OperationGate(timeout: .seconds(30))
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.root, create: { kind, name, directory in
            try await gate.create(kind, name: name, directory: directory)
        }, confirmChanges: { _, answer in
            prompts += 1
            answer(discard ? .discard : .cancel)
        })
        await browser.left.refresh()
        browser.left.setSelection([original])
        await browser.preview.load(browser.detailsSelection)
        browser.beginCreation(.textFile)
        let operation = Task { await browser.submitCreation(named: "created.txt") }
        try await gate.waitForRequest()
        browser.preview.setMode(.edit)
        await browser.preview.updateText("late draft")?.value
        try await gate.finish()
        await operation.value
        let created = fixture.root.appendingPathComponent("created.txt")
        if discard { try await waitForCreation { browser.left.primaryItemURL == created } }
        #expect(prompts == 1 && browser.preview.isDirty == !discard)
        #expect(browser.left.primaryItemURL == (discard ? created : original))
        #expect(browser.preview.text == (discard ? "original" : "late draft"))
        #expect(try Data(contentsOf: created).isEmpty)
        #expect(try Data(contentsOf: original) == Data("original".utf8))
    }

    @Test(arguments: [false, true]) @MainActor
    func guardedCreationRefreshDoesNotReportAnEarlierReadError(discard: Bool) async throws {
        let fixture = try CreationFixture()
        defer { fixture.remove() }
        let original = try fixture.file("original.txt")
        let missing = fixture.root.appendingPathComponent("missing", isDirectory: true)
        let gate = OperationGate(timeout: .seconds(30))
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.root, create: { kind, name, directory in
            try await gate.create(kind, name: name, directory: directory)
        }, confirmChanges: { _, answer in
            prompts += 1
            answer(discard ? .discard : .cancel)
        })
        await browser.left.refresh()
        browser.left.setSelection([original])
        await browser.preview.load(browser.detailsSelection)
        await browser.left.navigate(to: missing)
        _ = try #require(browser.left.errorMessage)
        browser.beginCreation(.textFile)
        let creation = Task { await browser.submitCreation(named: "created.txt") }
        try await gate.waitForRequest()
        browser.preview.setMode(.edit)
        await browser.preview.updateText("late draft")?.value
        try await gate.finish()
        await creation.value
        #expect(browser.creationError == nil)
        let created = fixture.root.appendingPathComponent("created.txt")
        if discard {
            try await waitForCreation { browser.left.primaryItemURL == created }
            #expect(browser.left.errorMessage == nil && !browser.preview.isDirty)
        } else {
            #expect(browser.left.errorMessage != nil && browser.left.primaryItemURL == original)
            #expect(browser.preview.isDirty && browser.preview.text == "late draft")
        }
        #expect(prompts == 1 && !browser.isCreating)
        #expect(try Data(contentsOf: created).isEmpty)
        #expect(try Data(contentsOf: original) == Data("original".utf8))
    }
}

@MainActor private func waitForCreation(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition(), ContinuousClock.now < deadline { await Task.yield() }
    guard condition() else { throw POSIXError(.ETIMEDOUT) }
}

private extension OperationGate {
    func create(_ kind: ItemCreation.Kind, name: String, directory: URL) async throws -> URL {
        try await pause()
        return try await ItemCreation.create(kind, named: name, in: directory)
    }
}

private actor FailingCreationListing {
    private var fail = false

    func read(_ directory: URL) async throws -> DirectoryListing {
        if fail { throw POSIXError(.EACCES) }
        return try await DirectoryListing.read(directory)
    }

    func create(_ kind: ItemCreation.Kind, name: String, directory: URL) async throws -> URL {
        let created = try await ItemCreation.create(kind, named: name, in: directory)
        fail = true
        return created
    }
}

private struct CreationFixture: Sendable {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-creation-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("original".utf8).write(to: url)
        return url
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
