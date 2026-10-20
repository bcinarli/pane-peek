import AppKit
import PanePeekCore

/// Requests access to the captured parent without changing the browser's location.
@MainActor final class TrashAccessPrompt: NSObject, NSOpenSavePanelDelegate {
    typealias Choose = @MainActor (NSOpenPanel, NSWindow) async -> URL?
    private let choose: Choose
    private var directory: URL?

    init(choose: @escaping Choose = { panel, window in
        await withTaskCancellationHandler {
            await withCheckedContinuation { answer in
                guard !Task.isCancelled else { answer.resume(returning: nil); return }
                panel.beginSheetModal(for: window) { response in
                    answer.resume(returning: response == .OK ? panel.url : nil)
                }
            }
        } onCancel: {
            Task { @MainActor in panel.cancel(nil) }
        }
    }) { self.choose = choose }

    func request(for directory: URL, in window: NSWindow) async -> ItemTrash.FolderAccess? {
        guard window.attachedSheet == nil, self.directory == nil, !Task.isCancelled else { return nil }
        self.directory = directory
        defer { self.directory = nil }
        let panel = NSOpenPanel()
        panel.title = "Allow Folder Access"
        panel.message = "Choose “\(directory.lastPathComponent)” to let PanePeek move the remaining selected items to Trash."
        panel.prompt = "Allow Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = directory
        panel.delegate = self
        guard let url = await choose(panel, window) else { return nil }
        // Native panels start the selected scope; retain its original URL until Trash finishes.
        let access = ItemTrash.FolderAccess(directory: url.resolvingSymlinksInPath()) { url.stopAccessingSecurityScopedResource() }
        guard !Task.isCancelled, access.directory.standardizedFileURL.path == directory.standardizedFileURL.path else { return nil }
        return access
    }

    func panel(_ sender: Any, validate url: URL) throws {
        guard let directory, url.resolvingSymlinksInPath().standardizedFileURL.path == directory.standardizedFileURL.path else {
            throw FolderChoiceError()
        }
    }
}

private struct FolderChoiceError: LocalizedError {
    var errorDescription: String? { "Choose the containing folder shown in the request." }
}
