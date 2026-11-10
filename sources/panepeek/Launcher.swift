import AppKit
import Foundation

enum Launcher {
    static let modeArgument = "--panepeek-cli"

    static func packagedVersion(_ info: [String: Any]) throws -> String {
        guard let version = info["CFBundleShortVersionString"] as? String,
              version.wholeMatch(of: #/[0-9]+\.[0-9]+\.[0-9]+/#) != nil,
              let build = info["CFBundleVersion"] as? String,
              build.wholeMatch(of: #/[1-9][0-9]*/#) != nil,
              let number = Int64(build), number <= 9_007_199_254_740_991 else { throw LauncherFailure.bundle }
        var display = version
        if let raw = info["PanePeekPrereleaseSuffix"] {
            guard let suffix = raw as? String, let match = suffix.wholeMatch(of: #/(?:beta|rc)\.([1-9][0-9]*)/#),
                  let sequence = Int64(match.1), sequence <= 9_007_199_254_740_991 else { throw LauncherFailure.bundle }
            display += "-" + suffix
        }
        return "PanePeek \(display) (\(build))"
    }

    static func confirmsApplication(expected: URL, identifier: String, actual: URL?, actualIdentifier: String?,
                                    process: Int32, caller: Int32) -> Bool {
        guard process > 0, process != caller, identifier == actualIdentifier,
              expected.isFileURL, let actual, actual.isFileURL else { return false }
        if expected.resolvingSymlinksInPath() == actual.resolvingSymlinksInPath() { return true }
        guard let expectedIdentity = try? FolderAccess.Identity.read(expected),
              let actualIdentity = try? FolderAccess.Identity.read(actual) else { return false }
        return expectedIdentity == actualIdentity
    }

    private struct Package: Sendable {
        let url: URL
        let identifier: String
        let version: String

        init(_ bundle: Bundle) throws {
            guard bundle.bundleURL.pathExtension == "app",
                  bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
                  bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "PanePeek",
                  let identifier = bundle.bundleIdentifier,
                  identifier.wholeMatch(of: #/[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+/#) != nil,
                  let executable = bundle.executableURL,
                  FileManager.default.isExecutableFile(atPath: executable.path),
                  let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
                  types.contains(where: { ($0["CFBundleURLSchemes"] as? [String]) == [LauncherRequest.scheme] }) else {
                throw LauncherFailure.bundle
            }
            url = bundle.bundleURL
            self.identifier = identifier
            version = try Launcher.packagedVersion(bundle.infoDictionary ?? [:])
        }
    }

    @MainActor static func run(_ arguments: [String]) -> Never {
        do {
            guard let directory = arguments.first else { throw LauncherFailure.workingDirectory }
            let command = try LauncherCommand.parse(Array(arguments.dropFirst()))
            if command == .help { print(usage); exit(0) }
            let package = try Package(.main)
            if command == .version { print(package.version); exit(0) }
            guard case let .open(path, intent) = command else { throw LauncherFailure.usage }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { fail(LauncherFailure.handoff) }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = try LauncherRequest.resolve(path, relativeTo: directory, intent: intent)
                    Task { @MainActor in deliver(request, to: package) }
                } catch {
                    Task { @MainActor in fail(error) }
                }
            }
            RunLoop.main.run()
            fail(LauncherFailure.handoff)
        } catch { fail(error) }
    }

    @MainActor private static func deliver(_ request: LauncherRequest, to package: Package) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        configuration.promptsUserIfNeeded = false
        NSWorkspace.shared.open([request.eventURL], withApplicationAt: package.url, configuration: configuration) { application, error in
            guard error == nil, let application,
                  confirmsApplication(expected: package.url, identifier: package.identifier, actual: application.bundleURL,
                                      actualIdentifier: application.bundleIdentifier, process: application.processIdentifier,
                                      caller: ProcessInfo.processInfo.processIdentifier) else { fail(LauncherFailure.handoff) }
            exit(0)
        }
    }

    private static func fail(_ error: any Error) -> Never {
        let message = (error as? LauncherFailure)?.errorDescription ?? error.localizedDescription
        FileHandle.standardError.write(Data(("panepeek: " + message + "\n").utf8))
        if error as? LauncherFailure == .usage {
            FileHandle.standardError.write(Data((usage + "\n").utf8))
            exit(2)
        }
        exit(1)
    }

    private static let usage = """
    Usage: panepeek [--reveal] [--] [path]
           panepeek --help
           panepeek --version

    Browse the current directory when no path is supplied.
    --reveal selects the item in its containing folder.
    Options may follow the path; -- ends option parsing.
    PanePeek may request folder access after accepting the request.
    """
}

extension LauncherFailure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .usage: "Invalid arguments."
        case .workingDirectory: "Could not obtain the caller's physical directory."
        case .bundle: "The containing PanePeek app has missing or invalid packaged metadata."
        case .handoff: "Could not confirm delivery to the containing PanePeek app."
        case .fileSystem(let code): POSIXError(code).localizedDescription
        }
    }
}
