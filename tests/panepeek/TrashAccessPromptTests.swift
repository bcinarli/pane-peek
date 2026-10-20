import AppKit
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor struct TrashAccessPromptTests {
    @Test(arguments: ["allow", "cancel", "wrong-folder"])
    func nativeChooserTargetsTheCapturedParentWithoutAcceptingAnotherFolder(choice: String) async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let prompt = TrashAccessPrompt { panel, owner in
            #expect(owner === window && panel.directoryURL?.path == directory.path)
            #expect(panel.canChooseDirectories && !panel.canChooseFiles && !panel.allowsMultipleSelection && !panel.canCreateDirectories)
            #expect(panel.prompt == "Allow Access" && panel.title == "Allow Folder Access")
            #expect(panel.message.contains("Trash") && panel.delegate != nil)
            if let delegate = panel.delegate as? TrashAccessPrompt {
                #expect(throws: Never.self) { try delegate.panel(panel, validate: directory) }
                do {
                    try delegate.panel(panel, validate: directory.deletingLastPathComponent())
                    Issue.record("A different containing folder was accepted")
                } catch {
                    #expect(error.localizedDescription == "Choose the containing folder shown in the request.")
                    #expect((error as NSError).domain != NSCocoaErrorDomain)
                }
            }
            if choice == "cancel" { return nil }
            return choice == "allow" ? directory : directory.deletingLastPathComponent()
        }
        let access = await prompt.request(for: directory, in: window)
        #expect((access?.directory.path == directory.path) == (choice == "allow"))
    }

    @Test func detachedOrChangedWindowCannotApproveRecovery() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let owner = PromptOwner()
        var presented = 0
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let access = TrashAccessPrompt { _, _ in
            presented += 1
            owner.prompts?.window = nil
            return directory
        }
        let prompts = BrowserPrompts(trashAccess: access)
        owner.prompts = prompts
        #expect(await prompts.recoverTrashAccess(for: directory) == nil)
        #expect(presented == 0)
        prompts.window = window
        #expect(await prompts.recoverTrashAccess(for: directory) == nil)
        #expect(presented == 1)
    }

}

@MainActor private final class PromptOwner { weak var prompts: BrowserPrompts? }
