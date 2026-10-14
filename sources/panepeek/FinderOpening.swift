import AppKit

@MainActor
struct FinderOpening {
    var openDirectories: ([URL]) async throws -> Void = { urls in
        let workspace = NSWorkspace.shared
        guard let finder = workspace.urlForApplication(withBundleIdentifier: "com.apple.finder") else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
                          userInfo: [NSLocalizedDescriptionKey: "Finder is unavailable."])
        }
        _ = try await workspace.open(urls, withApplicationAt: finder, configuration: .init())
    }
    var revealFiles: ([URL]) -> Void = { NSWorkspace.shared.activateFileViewerSelecting($0) }

    func open(_ urls: [URL]) async throws {
        let (directories, files) = try await Task.detached {
            var directories: [URL] = []
            var files: [URL] = []
            for url in urls {
                // Check link identity without requiring an existing target.
                _ = try FileManager.default.attributesOfItem(atPath: url.path)
                var isDirectory: ObjCBool = false
                _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                let isPackage = try isDirectory.boolValue
                    && url.resolvingSymlinksInPath().resourceValues(forKeys: [.isPackageKey]).isPackage == true
                if isDirectory.boolValue && !isPackage { directories.append(url) }
                else { files.append(url) }
            }
            return (directories, files)
        }.value
        if !directories.isEmpty { try await openDirectories(directories) }
        if !files.isEmpty { revealFiles(files) }
    }
}
