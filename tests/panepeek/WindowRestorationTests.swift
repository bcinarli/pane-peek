import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct WindowRestorationTests {
    @Test(.timeLimit(.minutes(1)), arguments: [false, true], [Duration.zero, .seconds(2)])
    func missingReadsOrReleaseReportsTimeout(missingReads: Bool, timeout: Duration) async {
        let gate = RestorationReadGate(timeout: timeout)
        let expected = RestorationReadGate.Failure(message: "Restoration gate timed out; reads: \(missingReads ? 0 : 1); waiting for: \(missingReads ? "[2]" : "[]")")
        await withKnownIssue {
            await #expect(throws: expected) {
                if missingReads { try await gate.waitForReads(2) }
                else { try await gate.wait() }
            }
            await #expect(throws: expected) { try await gate.release() }
            await #expect(throws: expected) { try await gate.waitForReads(2) }
            await #expect(throws: expected) { try await gate.wait() }
        } matching: { $0.error as? RestorationReadGate.Failure == expected }
    }

    @Test func timeoutReleasesConcurrentReadsWithTheSameFailure() async {
        await withKnownIssue {
            let gate = RestorationReadGate(timeout: .zero)
            let readers = (0..<2).map { _ in Task { try await gate.wait() } }
            var failures: [RestorationReadGate.Failure] = []
            for reader in readers {
                switch await reader.result {
                case .success: Issue.record("A timed-out restoration read resumed normally")
                case .failure(let error):
                    if let failure = error as? RestorationReadGate.Failure { failures.append(failure) }
                    else { Issue.record(error) }
                }
            }
            #expect(failures.count == 2 && failures.first == failures.last)
        } matching: { ($0.error as? RestorationReadGate.Failure)?.message.hasPrefix("Restoration gate timed out;") == true }
    }

    @Test func firstLaunchWithoutPreferencesStartsWithOnePaneAndExpandedDetails() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.browser.visiblePanes == [.left])
        #expect(window.browser.left.directory == fixture.home && window.browser.right.directory == fixture.home)
        #expect(window.sizing.preferredWidth == 300 && window.sizing.isExpanded)
        let controller = window.attachSplitController()
        window.window.setContentSize(NSSize(width: 1100, height: 650))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 726) < 1)
        window.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 300) < 1)
    }

    @Test func initialWindowRestoresOrderedIdentitiesAndLayoutButNewWindowsStayFresh() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(mode: "twoPanes", order: ["right", "left"], active: "left", width: 620),
                                forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let initial = fixture.window(lifecycle)
        await lifecycle.start(initial.browser, sizing: initial.sizing)
        #expect(initial.browser.right.directory == fixture.first)
        #expect(initial.browser.left.directory == fixture.second)
        #expect(initial.browser.presentationOrder == [.right, .left])
        #expect(initial.browser.focusedPane == .left && initial.browser.mode == .twoPanes)
        #expect(initial.sizing.preferredWidth == 620 && !initial.sizing.isExpanded)
        initial.sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 298)
        #expect(initial.sizing.preferredWidth == 620)
        initial.sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 620)
        #expect(initial.sizing.requestedWidth(in: 1400) == 620)
        let next = fixture.window(lifecycle)
        await lifecycle.start(next.browser, sizing: next.sizing)
        #expect(next.browser.left.directory == fixture.home && next.browser.right.directory == fixture.home)
        #expect(next.browser.mode == .onePane && next.browser.focusedPane == .left)
        #expect(next.browser.presentationOrder == [.left, .right] && next.sizing.preferredWidth == 300)
        #expect(next.sizing.isExpanded)
        #expect(next.browser.left.selectedItems.isEmpty && next.browser.preview.selection == nil)
        #expect(!next.browser.left.showHiddenFiles && next.browser.left.sortField == .name)
    }

    @Test func lastActiveWindowPublishesCompleteChangesAndFinalClosePreservesThem() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let first = fixture.window(lifecycle)
        await lifecycle.start(first.browser, sizing: first.sizing)
        first.activate()
        await first.browser.left.navigate(to: fixture.first)
        await first.browser.right.navigate(to: fixture.second)
        first.browser.setMode(.twoPanes)
        first.browser.focus(.right)
        first.browser.setMode(.onePane)
        first.sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 300)
        first.sizing.setWidthFromUser(620)
        first.sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 298)
        first.sizing.toggleExpansion()
        let expected = fixture.record(directories: [fixture.second, fixture.first], mode: "onePane",
                                      order: ["right", "left"], active: "right", width: 620, expanded: true)
        await fixture.waitForRecord(expected)
        let second = fixture.window(lifecycle)
        await lifecycle.start(second.browser, sizing: second.sizing)
        second.activate()
        await fixture.waitForRecord(fixture.record(directories: [fixture.home, fixture.home], mode: "onePane", expanded: true))
        await first.browser.left.navigate(to: fixture.home)
        first.browser.setMode(.twoPanes)
        await fixture.waitForRecord(fixture.record(directories: [fixture.home, fixture.home], mode: "onePane", expanded: true))
        first.activate()
        first.browser.focus(.left)
        first.sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 620)
        first.sizing.setWidthFromUser(480)
        second.close()
        first.close()
        let final = fixture.record(directories: [fixture.second, fixture.home], mode: "twoPanes",
                                   order: ["right", "left"], active: "left", width: 480)
        #expect(fixture.matches(final))
        let relaunched = BrowserLifecycle(preferences: fixture.preferences)
        let restored = fixture.window(relaunched)
        await relaunched.start(restored.browser, sizing: restored.sizing)
        #expect(restored.browser.right.directory == fixture.second && restored.browser.left.directory == fixture.home)
        #expect(restored.browser.presentationOrder == [.right, .left] && restored.browser.focusedPane == .left)
        #expect(restored.sizing.preferredWidth == 480)
    }

    @Test(arguments: [false, true])
    func dockReopeningRepeatedlyRestoresTheFinalClosedConfiguration(single: Bool) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let initial = fixture.window(lifecycle)
        await lifecycle.start(initial.browser, sizing: initial.sizing)
        initial.activate()
        await initial.browser.left.navigate(to: fixture.first)
        await initial.browser.right.navigate(to: fixture.second)
        initial.browser.setMode(.twoPanes)
        initial.browser.focus(.right)
        initial.browser.setMode(single ? .onePane : .twoPanes)
        initial.sizing.restorePreferredWidth(480)
        initial.close()

        let delegate: any NSApplicationDelegate = lifecycle
        for _ in 0..<2 {
            #expect(delegate.applicationShouldHandleReopen?(NSApplication.shared, hasVisibleWindows: false) ?? true)
            await lifecycle.start(initial.browser, sizing: initial.sizing)
            let reopened = fixture.window(lifecycle)
            await lifecycle.start(reopened.browser, sizing: reopened.sizing)
            #expect(reopened.browser.right.directory == fixture.second && reopened.browser.left.directory == fixture.first)
            #expect(reopened.browser.presentationOrder == (single ? [.right, .left] : [.left, .right]))
            #expect(reopened.browser.mode == (single ? .onePane : .twoPanes))
            #expect(reopened.browser.focusedPane == .right && reopened.sizing.preferredWidth == 480)
            reopened.activate()
            reopened.close()
        }
        #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
        let nextLifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let next = fixture.window(nextLifecycle)
        await nextLifecycle.start(next.browser, sizing: next.sizing)
        #expect(next.browser.right.directory == fixture.second && next.browser.left.directory == fixture.first)
        #expect(next.browser.mode == (single ? .onePane : .twoPanes) && next.sizing.preferredWidth == 480)
    }

    @Test func explicitNewWindowStaysFreshAfterFinalCloseOrDockActivationOfAnExistingWindow() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(mode: "onePane", order: ["right", "left"], width: 480), forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let first = fixture.window(lifecycle)
        await lifecycle.start(first.browser, sizing: first.sizing)
        first.activate()
        let delegate: any NSApplicationDelegate = lifecycle
        for visible in [true, false] {
            // A miniaturised window is registered even when none are visible.
            #expect(delegate.applicationShouldHandleReopen?(NSApplication.shared, hasVisibleWindows: visible) ?? true)
        }
        first.close()
        let fresh = fixture.window(lifecycle)
        await lifecycle.start(fresh.browser, sizing: fresh.sizing)
        #expect(fresh.browser.left.directory == fixture.home && fresh.browser.right.directory == fixture.home)
        #expect(fresh.browser.mode == .onePane && fresh.browser.focusedPane == .left)
        #expect(fresh.browser.presentationOrder == [.left, .right] && fresh.sizing.preferredWidth == 300)
        #expect(fresh.sizing.isExpanded)
    }

    @Test(arguments: [false, true], [false, true])
    func quitCapturesLatestActiveLayoutBeforeObservationRunsAndRelaunchRestoresIt(resolveChanges: Bool, single: Bool) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let initial = fixture.window(lifecycle)
        await lifecycle.start(initial.browser, sizing: initial.sizing)
        initial.activate()
        await initial.browser.left.navigate(to: fixture.first)
        await initial.browser.right.navigate(to: fixture.second)
        initial.browser.setMode(.twoPanes)
        initial.browser.focus(.right)
        initial.browser.setMode(single ? .onePane : .twoPanes)
        initial.sizing.restorePreferredWidth(480)
        if resolveChanges { #expect(await lifecycle.prepareToQuit()) }
        else { #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow) }
        #expect(fixture.matches(fixture.record(directories: single ? [fixture.second, fixture.first] : [fixture.first, fixture.second],
                                             mode: single ? "onePane" : "twoPanes",
                                             order: single ? ["right", "left"] : ["left", "right"], active: "right", width: 480)))

        let nextLifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let restored = fixture.window(nextLifecycle)
        await nextLifecycle.start(restored.browser, sizing: restored.sizing)
        #expect(restored.browser.right.directory == fixture.second && restored.browser.left.directory == fixture.first)
        #expect(restored.browser.presentationOrder == (single ? [.right, .left] : [.left, .right]))
        #expect(restored.browser.mode == (single ? .onePane : .twoPanes))
        #expect(restored.browser.focusedPane == .right && restored.sizing.preferredWidth == 480)
    }

    @Test func directoryOnlyAndInvalidLayoutFieldsKeepUsablePathsAndSafeDefaults() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let records: [[String: Any]] = [
            ["directories": [fixture.first.path, fixture.second.path]],
            ["directories": [fixture.first.path, fixture.second.path], "mode": "invalid", "activeBrowser": "invalid",
             "presentationOrder": ["left", "left"], "detailsWidth": -10],
            ["directories": [fixture.first.path, fixture.second.path], "detailsWidth": "wide"],
            ["directories": [fixture.first.path, fixture.second.path], "presentationOrder": ["right", "left", "unknown"]]
        ]
        for record in records {
            fixture.preferences.set(record, forKey: "rememberedWindow")
            let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
            let window = fixture.window(lifecycle)
            await lifecycle.start(window.browser, sizing: window.sizing)
            #expect(window.browser.left.directory == fixture.first && window.browser.right.directory == fixture.second)
            #expect(window.browser.mode == .twoPanes && window.browser.focusedPane == .left)
            #expect(window.browser.presentationOrder == [.left, .right] && window.sizing.preferredWidth == 300)
            window.close()
        }
    }

    @Test func invalidDirectoryAndActiveFieldsDefaultIndependently() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        var record = fixture.record(mode: "onePane", order: ["right", "left"], active: "invalid", width: 420)
        record["directories"] = [fixture.first.path, "relative/path"]
        fixture.preferences.set(record, forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.browser.right.directory == fixture.first && window.browser.left.directory == fixture.home)
        #expect(window.browser.visiblePanes == [.right] && window.browser.focusedPane == .right)
        #expect(window.sizing.preferredWidth == 420)
    }

    @Test(arguments: [false, true])
    func unavailableHiddenPathFallsBackWithoutChangingTheOtherBrowser(denied: Bool) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let unavailable = fixture.root.appendingPathComponent("unavailable")
        fixture.preferences.set(fixture.record(directories: [fixture.first, unavailable], mode: "onePane",
                                               order: ["right", "left"], active: "right"), forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle, load: { directory in
            if denied && directory == unavailable { throw CocoaError(.fileReadNoPermission) }
            return try await DirectoryListing.read(directory)
        })
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.browser.right.directory == fixture.first && window.browser.left.directory == fixture.home)
        #expect(window.browser.visiblePanes == [.right])
        #expect(window.browser.restorationMessage?.contains(unavailable.path) == true)
        #expect(window.browser.right.recoveryMessage == nil)
    }

    @Test func repeatedStartupDoesNotResetNavigationOrConsumeNewWindowRestoration() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(), forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let first = fixture.window(lifecycle)
        await lifecycle.start(first.browser, sizing: first.sizing)
        await first.browser.left.navigate(to: fixture.second)
        await lifecycle.start(first.browser, sizing: first.sizing)
        #expect(first.browser.left.directory == fixture.second)
        let next = fixture.window(lifecycle)
        await lifecycle.start(next.browser, sizing: next.sizing)
        #expect(next.browser.left.directory == fixture.home && next.browser.right.directory == fixture.home)
    }

    @Test func slowInitialReadsDoNotPublishHomeDefaultsOrOverwriteANewerActiveWindow() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let remembered = fixture.record(mode: "onePane", order: ["right", "left"], active: "right", width: 480)
        fixture.preferences.set(remembered, forKey: "rememberedWindow")
        let gate = RestorationReadGate()
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let initial = fixture.window(lifecycle, load: { directory in
            try await gate.wait()
            return try await DirectoryListing.read(directory)
        })
        initial.activate()
        let startup = Task { await lifecycle.start(initial.browser, sizing: initial.sizing) }
        try await gate.waitForReads(2)
        #expect(fixture.matches(remembered))
        let next = fixture.window(lifecycle)
        await lifecycle.start(next.browser, sizing: next.sizing)
        next.activate()
        let fresh = fixture.record(directories: [fixture.home, fixture.home], mode: "onePane", expanded: true)
        await fixture.waitForRecord(fresh)
        try await gate.release()
        await startup.value
        #expect(initial.browser.right.directory == fixture.first && initial.browser.left.directory == fixture.second)
        #expect(fixture.matches(fresh))
        initial.activate()
        await fixture.waitForRecord(remembered)
    }

    @Test func supersededFailedRestoreDoesNotRedirectNewerNavigation() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(), forKey: "rememberedWindow")
        let gate = RestorationReadGate()
        let firstPath = fixture.first
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle, load: { directory in
            if directory == firstPath {
                try await gate.wait()
                throw CocoaError(.fileReadNoPermission)
            }
            return try await DirectoryListing.read(directory)
        })
        window.activate()
        let startup = Task { await lifecycle.start(window.browser, sizing: window.sizing) }
        try await gate.waitForReads(1)
        await window.browser.left.navigate(to: fixture.home)
        try await gate.release()
        await startup.value
        #expect(window.browser.left.directory == fixture.home && window.browser.right.directory == fixture.second)
        #expect(window.browser.restorationMessage == nil && window.browser.left.errorMessage == nil)
        await fixture.waitForRecord(fixture.record(directories: [fixture.home, fixture.second]))
    }

    @Test func replacingTheNativeGuardKeepsObservationAndCloseCapture() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        await lifecycle.start(window.browser, sizing: window.sizing)
        window.activate()
        window.replaceGuard(lifecycle)
        await window.browser.right.navigate(to: fixture.second)
        window.browser.setMode(.twoPanes)
        window.browser.focus(.right)
        window.browser.setMode(.onePane)
        let expected = fixture.record(directories: [fixture.second, fixture.home], mode: "onePane",
                                      order: ["right", "left"], active: "right", expanded: true)
        await fixture.waitForRecord(expected)
        window.close()
        #expect(fixture.matches(expected))
    }

    @Test func restoredPreferredWidthUsesNativeBoundsAndRecoversAfterWidening() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(width: 620), forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        await lifecycle.start(window.browser, sizing: window.sizing)
        let controller = window.attachSplitController()
        window.window.setContentSize(NSSize(width: 800, height: 650))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 298) < 1)
        #expect(window.sizing.preferredWidth == 620)
        window.window.setContentSize(NSSize(width: 1400, height: 650))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 620) < 1)
    }

    @Test(arguments: [false, true])
    func expandedDetailsSurvivesReopeningAndRestoreKeepsThePreferredWidth(relaunch: Bool) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let initial = fixture.window(lifecycle)
        await lifecycle.start(initial.browser, sizing: initial.sizing)
        initial.activate()
        initial.sizing.restorePreferredWidth(480)
        initial.sizing.toggleExpansion()
        var expanded = fixture.record(directories: [fixture.home, fixture.home], mode: "onePane", width: 480)
        expanded["detailsExpanded"] = true
        await fixture.waitForRecord(expanded)

        let fresh = fixture.window(lifecycle)
        await lifecycle.start(fresh.browser, sizing: fresh.sizing)
        #expect(fresh.sizing.isExpanded && fresh.sizing.preferredWidth == 300)
        fresh.close()
        if relaunch { #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow) }
        initial.close()

        let nextLifecycle = relaunch ? BrowserLifecycle(preferences: fixture.preferences) : lifecycle
        if !relaunch {
            let delegate: any NSApplicationDelegate = nextLifecycle
            #expect(delegate.applicationShouldHandleReopen?(NSApplication.shared, hasVisibleWindows: false) ?? true)
        }
        let restored = fixture.window(nextLifecycle)
        await nextLifecycle.start(restored.browser, sizing: restored.sizing)
        restored.activate()
        #expect(restored.sizing.isExpanded && restored.sizing.preferredWidth == 480)
        let controller = restored.attachSplitController()
        restored.window.setContentSize(NSSize(width: 800, height: 650))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 528) < 1)
        #expect(restored.sizing.isExpanded && restored.sizing.preferredWidth == 480)
        restored.window.setContentSize(NSSize(width: 1400, height: 650))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 924) < 1)
        restored.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 480) < 1)
        expanded["detailsExpanded"] = false
        await fixture.waitForRecord(expanded)
    }

    @Test func absentOrInvalidExpansionKeepsOtherPreferencesAndStartsUnexpanded() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        for expansion: Any? in [nil, "true", [true]] {
            var record = fixture.record(width: 480)
            record["detailsExpanded"] = expansion
            fixture.preferences.set(record, forKey: "rememberedWindow")
            let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
            let window = fixture.window(lifecycle)
            await lifecycle.start(window.browser, sizing: window.sizing)
            #expect(!window.sizing.isExpanded && window.sizing.preferredWidth == 480)
            #expect(window.browser.left.directory == fixture.first && window.browser.right.directory == fixture.second)
            window.close()
        }
    }

    @Test(arguments: [false, true])
    func browserProportionsAndWindowFrameSurviveBothReopenPaths(relaunch: Bool) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(directories: [fixture.home, fixture.home]), forKey: "rememberedWindow")
        let screen = try #require(NSScreen.main).visibleFrame
        let frame = NSRect(x: screen.minX + 40, y: screen.minY + 40,
                           width: min(1200, screen.width - 80), height: min(700, screen.height - 80))
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let initial = fixture.window(lifecycle)
        let controller = initial.attachSplitController()
        await lifecycle.start(initial.browser, sizing: initial.sizing)
        initial.activate()
        initial.window.setFrame(frame, display: false)
        controller.view.layoutSubtreeIfNeeded()
        let drag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": 0]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification, object: controller.splitView, userInfo: drag)
        let browsersWidth = controller.left.view.frame.width + controller.right.view.frame.width
        controller.splitView.setPosition(browsersWidth * 0.6, ofDividerAt: 0)
        controller.view.layoutSubtreeIfNeeded()
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification, object: controller.splitView, userInfo: drag)
        let proportion = controller.left.view.frame.width / controller.right.view.frame.width
        var expected = fixture.record(directories: [fixture.home, fixture.home])
        expected["browserProportion"] = Double(proportion)
        expected["windowFrame"] = ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
        await fixture.waitForRecord(expected)
        if relaunch { #expect(lifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow) }
        initial.close()

        let nextLifecycle = relaunch ? BrowserLifecycle(preferences: fixture.preferences) : lifecycle
        if !relaunch {
            let delegate: any NSApplicationDelegate = nextLifecycle
            #expect(delegate.applicationShouldHandleReopen?(NSApplication.shared, hasVisibleWindows: false) ?? true)
        }
        let restored = fixture.window(nextLifecycle)
        let restoredController = restored.attachSplitController()
        await nextLifecycle.start(restored.browser, sizing: restored.sizing)
        restoredController.applySizing()
        restoredController.view.layoutSubtreeIfNeeded()
        #expect(restored.window.frame == frame)
        #expect(abs(restoredController.left.view.frame.width / restoredController.right.view.frame.width - proportion) < 0.01)
        restored.window.setContentSize(NSSize(width: 800, height: 480))
        restoredController.view.layoutSubtreeIfNeeded()
        #expect(restoredController.left.view.frame.width >= 250 && restoredController.right.view.frame.width >= 250)
        restored.window.setFrame(frame, display: false)
        restoredController.view.layoutSubtreeIfNeeded()
        #expect(abs(restoredController.left.view.frame.width / restoredController.right.view.frame.width - proportion) < 0.01)
        restored.browser.focus(.right)
        restored.browser.setMode(.onePane)
        restoredController.applyLayout(restored.browser.visiblePanes)
        restored.browser.setMode(.twoPanes)
        restoredController.applyLayout(restored.browser.visiblePanes)
        restoredController.view.layoutSubtreeIfNeeded()
        #expect(restored.browser.presentationOrder == [.right, .left])
        #expect(abs(restoredController.left.view.frame.width / restoredController.right.view.frame.width - proportion) < 0.01)
        restored.sizing.toggleExpansion()
        restoredController.applySizing()
        restoredController.view.layoutSubtreeIfNeeded()
        restored.sizing.toggleExpansion()
        restoredController.applySizing()
        restoredController.view.layoutSubtreeIfNeeded()
        #expect(abs(restoredController.left.view.frame.width / restoredController.right.view.frame.width - proportion) < 0.01)
        let fresh = fixture.window(nextLifecycle)
        let freshController = fresh.attachSplitController()
        await nextLifecycle.start(fresh.browser, sizing: fresh.sizing)
        freshController.applyLayout(fresh.browser.visiblePanes)
        freshController.applySizing()
        freshController.view.layoutSubtreeIfNeeded()
        #expect(fresh.browser.visiblePanes == [.left] && freshController.splitViewItems.count == 2)
        #expect(fresh.sizing.browserProportion == 1 && fresh.sizing.preferredWidth == 300 && fresh.sizing.isExpanded)
        #expect(fresh.window.frame.size != frame.size)
    }

    @Test func offscreenOversizedRestorationKeepsTheWindowInAnAvailableScreen() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        var record = fixture.record()
        record["windowFrame"] = ["x": 100_000.0, "y": -100_000.0, "width": 20_000.0, "height": 20_000.0]
        fixture.preferences.set(record, forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(NSScreen.screens.contains { $0.visibleFrame.contains(window.window.frame) })
        #expect(window.window.frame.width >= 800 && window.window.frame.height >= 480)
    }

    @Test func lateNativeAttachmentRestoresFrameOnceAndSubsequentMovesAreRemembered() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let screen = try #require(NSScreen.main).visibleFrame
        let frame = NSRect(x: screen.minX + 30, y: screen.minY + 30,
                           width: min(1000, screen.width - 80), height: min(650, screen.height - 80))
        var record = fixture.record(width: 420)
        record["windowFrame"] = WindowGeometry.record(frame)
        record["browserProportion"] = 1.5
        fixture.preferences.set(record, forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle, attach: false)
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.window.frame != frame)
        let controller = window.attachSplitController()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(window.window.frame == frame)
        window.activate()
        let moved = frame.offsetBy(dx: 20, dy: 20)
        window.window.setFrame(moved, display: false)
        record["windowFrame"] = WindowGeometry.record(moved)
        await fixture.waitForRecord(record)
        window.replaceGuard(lifecycle)
        #expect(window.window.frame == moved && window.sizing.frameToRestore == nil)
    }

    @Test func restorationAlsoRespectsTheAttachedWindowsNativeMinimumSize() async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        let screen = try #require(NSScreen.main).visibleFrame
        var record = fixture.record()
        record["windowFrame"] = WindowGeometry.record(NSRect(x: screen.minX + 20, y: screen.minY + 20, width: 900, height: 600))
        fixture.preferences.set(record, forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        window.window.minSize = NSSize(width: 1000, height: 700)
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.window.frame.width >= min(1000, screen.width) && window.window.frame.height >= min(700, screen.height))
        #expect(screen.contains(window.window.frame))
    }

    @Test(arguments: [0.0, -1, Double.nan, .infinity])
    func invalidProportionAndFrameKeepTheOtherRestoredFields(proportion: Double) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        var record = fixture.record(width: 480, expanded: true)
        record["browserProportion"] = proportion
        record["windowFrame"] = ["x": 10.0, "y": 10, "width": -1, "height": 650]
        fixture.preferences.set(record, forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        let original = window.window.frame
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.sizing.browserProportion == 1 && window.window.frame == original)
        #expect(window.sizing.preferredWidth == 480 && window.sizing.isExpanded)
        #expect(window.browser.left.directory == fixture.first && window.browser.right.directory == fixture.second)
    }

    @Test(arguments: [Double.nan, .infinity, 0, 279])
    func invalidWidthsUseTheCompactDefault(width: Double) async throws {
        let fixture = try RestorationFixture()
        defer { fixture.finish() }
        fixture.preferences.set(fixture.record(width: width), forKey: "rememberedWindow")
        let lifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let window = fixture.window(lifecycle)
        await lifecycle.start(window.browser, sizing: window.sizing)
        #expect(window.sizing.preferredWidth == 300)
        #expect(window.browser.left.directory == fixture.first)
    }
}

@MainActor private final class RestorationFixture {
    let domain = "panepeek-restoration-" + UUID().uuidString
    let preferences: UserDefaults
    let root: URL
    let home: URL
    let first: URL
    let second: URL
    private var windows: [RestorationWindow] = []

    init() throws {
        preferences = try #require(UserDefaults(suiteName: domain))
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-restoration-" + UUID().uuidString).resolvingSymlinksInPath()
        home = root.appendingPathComponent("home", isDirectory: true)
        first = root.appendingPathComponent("first", isDirectory: true)
        second = root.appendingPathComponent("second", isDirectory: true)
        for directory in [home, first, second] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }

    func window(_ lifecycle: BrowserLifecycle, attach: Bool = true, load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read) -> RestorationWindow {
        let window = RestorationWindow(home: home, lifecycle: lifecycle, load: load, attach: attach)
        windows.append(window)
        return window
    }

    func record(directories: [URL]? = nil, mode: String = "twoPanes", order: [String] = ["left", "right"],
                active: String = "left", width: Double = 300, expanded: Bool = false) -> [String: Any] {
        ["directories": (directories ?? [first, second]).map(\.path), "mode": mode,
         "presentationOrder": order, "activeBrowser": active, "detailsWidth": width, "detailsExpanded": expanded,
         "browserProportion": 1.0]
    }

    func matches(_ expected: [String: Any]) -> Bool {
        guard var record = preferences.dictionary(forKey: "rememberedWindow") else { return false }
        // Older fixtures assert their own fields; geometry cases include an exact frame.
        if expected["windowFrame"] == nil { record.removeValue(forKey: "windowFrame") }
        return NSDictionary(dictionary: record).isEqual(to: expected)
    }

    func waitForRecord(_ expected: [String: Any]) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while !matches(expected) && ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(matches(expected))
    }

    func finish() {
        windows.forEach { $0.close() }
        preferences.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor private final class RestorationWindow {
    let browser: BrowserState
    let sizing = DetailsSizing()
    let window: NSWindow
    private let prompts = BrowserPrompts()
    private var guardView = BrowserWindowGuard.GuardView()

    init(home: URL, lifecycle: BrowserLifecycle, load: @escaping @Sendable (URL) async throws -> DirectoryListing, attach: Bool = true) {
        _ = NSApplication.shared
        browser = BrowserState(homeDirectory: home, load: load, operations: lifecycle.operations)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 650),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        guardView.browser = browser
        guardView.sizing = sizing
        guardView.prompts = prompts
        guardView.lifecycle = lifecycle
        if attach { window.contentView = guardView }
    }

    func activate() {
        window.delegate?.windowDidBecomeKey?(Notification(name: NSWindow.didBecomeKeyNotification, object: window))
    }

    func replaceGuard(_ lifecycle: BrowserLifecycle) {
        let replacement = BrowserWindowGuard.GuardView()
        replacement.browser = browser
        replacement.sizing = sizing
        replacement.prompts = prompts
        replacement.lifecycle = lifecycle
        guardView.addSubview(replacement)
        guardView.uninstall()
        guardView = replacement
    }

    func attachSplitController() -> BrowserSplitView<Color, Color, Color>.Controller {
        let controller = BrowserSplitView<Color, Color, Color>.Controller(left: .clear, right: .clear, details: .clear, sizing: sizing)
        window.contentViewController = controller
        controller.view.addSubview(guardView)
        window.orderFront(nil)
        controller.applyLayout(browser.visiblePanes)
        controller.view.layoutSubtreeIfNeeded()
        return controller
    }

    func close() {
        window.close()
        guardView.uninstall()
    }
}

private actor RestorationReadGate {
    struct Failure: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    private let timeout: Duration
    private var deadline: Task<Void, Never>?
    private var failure: Failure?
    private var reads: [CheckedContinuation<Void, any Error>] = []
    private var observers: [Int: CheckedContinuation<Void, any Error>] = [:]

    init(timeout: Duration = .seconds(10)) { self.timeout = timeout }
    deinit { deadline?.cancel() }

    func wait() async throws {
        if let failure { throw failure }
        startDeadline()
        try await withCheckedThrowingContinuation {
            reads.append($0)
            for count in observers.keys.filter({ $0 <= reads.count }) {
                observers.removeValue(forKey: count)?.resume()
            }
        }
    }

    func waitForReads(_ count: Int) async throws {
        if let failure { throw failure }
        if reads.count >= count { return }
        guard observers[count] == nil else {
            let error = Failure(message: "Duplicate restoration gate observer for \(count) reads")
            abort(error)
            throw error
        }
        startDeadline()
        try await withCheckedThrowingContinuation { observers[count] = $0 }
    }

    func release() throws {
        guard !reads.isEmpty, observers.isEmpty else {
            let error = failure ?? Failure(message: "Restoration gate released without all requested reads; reads: \(reads.count); waiting for: \(observers.keys.sorted())")
            abort(error)
            throw error
        }
        let pending = reads
        reads = []
        deadline?.cancel()
        deadline = nil
        pending.forEach { $0.resume() }
    }

    private func startDeadline() {
        guard deadline == nil else { return }
        let timeout = timeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            await self?.expire()
        }
    }

    private func expire() {
        guard !Task.isCancelled, !reads.isEmpty || !observers.isEmpty else { return }
        let error = Failure(message: "Restoration gate timed out; reads: \(reads.count); waiting for: \(observers.keys.sorted())")
        Issue.record(error)
        abort(error)
    }

    private func abort(_ error: Failure) {
        failure = error
        deadline?.cancel()
        deadline = nil
        let reads = reads
        let observers = observers
        self.reads = []
        self.observers = [:]
        reads.forEach { $0.resume(throwing: error) }
        observers.values.forEach { $0.resume(throwing: error) }
    }
}
