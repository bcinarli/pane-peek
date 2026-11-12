import Foundation
import Darwin

enum LauncherFailure: Error, Equatable {
    case usage
    case workingDirectory
    case bundle
    case handoff
    case fileSystem(POSIXErrorCode)
}

enum LauncherCommand: Equatable {
    case help
    case version
    case open(String, LauncherRequest.Intent)

    static func parse(_ arguments: [String]) throws -> Self {
        if arguments == ["--help"] { return .help }
        if arguments == ["--version"] { return .version }
        var options = true
        var reveal = false
        var path: String?
        for argument in arguments {
            if options && argument == "--" { options = false }
            else if options && argument == "--reveal" {
                guard !reveal else { throw LauncherFailure.usage }
                reveal = true
            } else {
                guard !(options && argument.hasPrefix("-")), path == nil,
                      !argument.isEmpty, !argument.contains("\0") else { throw LauncherFailure.usage }
                path = argument
            }
        }
        guard !reveal || path != nil else { throw LauncherFailure.usage }
        return .open(path ?? ".", reveal ? .reveal : .open)
    }
}

struct LauncherRequest: Equatable, Sendable {
    enum Intent: String, Sendable { case open, reveal }

    static let scheme = "panepeek"
    let path: String
    let intent: Intent
    let requiresDirectory: Bool

    static func resolve(_ path: String, relativeTo directory: String, intent: Intent) throws -> Self {
        guard !path.isEmpty, !path.contains("\0") else { throw LauncherFailure.usage }
        guard directory.hasPrefix("/"), !directory.contains("\0") else { throw LauncherFailure.workingDirectory }
        var absolute = path.hasPrefix("/") ? path : directory + "/" + path
        let trailingSlash = absolute.hasSuffix("/")
        while absolute.count > 1 && absolute.hasSuffix("/") { absolute.removeLast() }
        let separator = absolute.lastIndex(of: "/")!
        let name = String(absolute[absolute.index(after: separator)...])
        let dot = name == "." || name == ".."
        if dot {
            absolute = try physical(absolute) ?? absolute
        } else if absolute != "/" {
            let parent = String(absolute[..<separator])
            if let canonical = try physical(parent.isEmpty ? "/" : parent) {
                absolute = (canonical == "/" ? "/" : canonical + "/") + name
            }
        }
        let required = trailingSlash || dot
        try preflight(absolute, directoryRequired: required)
        return Self(path: absolute, intent: intent, requiresDirectory: required)
    }

    var eventURL: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "intent", value: intent.rawValue),
            URLQueryItem(name: "directory", value: requiresDirectory ? "1" : "0"),
        ]
        return components.url!
    }

    init(path: String, intent: Intent, requiresDirectory: Bool = false) {
        self.path = path
        self.intent = intent
        self.requiresDirectory = requiresDirectory
    }

    init?(eventURL: URL) {
        guard eventURL.absoluteString.utf8.count <= 65_536,
              let components = URLComponents(url: eventURL, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme, components.host == "open",
              components.user == nil, components.password == nil, components.port == nil,
              components.path.isEmpty, components.fragment == nil,
              components.percentEncodedQuery?.removingPercentEncoding != nil,
              let items = components.queryItems, items.count == 3,
              Set(items.map(\.name)) == ["path", "intent", "directory"],
              let path = items.first(where: { $0.name == "path" })?.value,
              path.hasPrefix("/"), !path.contains("\0"),
              let rawIntent = items.first(where: { $0.name == "intent" })?.value,
              let intent = Intent(rawValue: rawIntent),
              let required = items.first(where: { $0.name == "directory" })?.value,
              required == "0" || required == "1" else { return nil }
        self.init(path: path, intent: intent, requiresDirectory: required == "1")
    }

    private static func physical(_ path: String) throws -> String? {
        try path.withCString { name in
            guard let resolved = realpath(name, nil) else {
                try rejectConfirmedFailure(errno)
                return nil
            }
            defer { free(resolved) }
            return String(cString: resolved)
        }
    }

    private static func preflight(_ path: String, directoryRequired: Bool) throws {
        var value = stat()
        let code = path.withCString { name in
            let result = directoryRequired ? fstatat(AT_FDCWD, name, &value, 0) : lstat(name, &value)
            return result == 0 ? 0 : errno
        }
        guard code == 0 else { try rejectConfirmedFailure(code); return }
        if directoryRequired && value.st_mode & S_IFMT != S_IFDIR { throw LauncherFailure.fileSystem(.ENOTDIR) }
    }

    private static func rejectConfirmedFailure(_ code: Int32) throws {
        let error = POSIXErrorCode(rawValue: code) ?? .EIO
        if [.ENOENT, .ENOTDIR, .ELOOP, .ENAMETOOLONG].contains(error) { throw LauncherFailure.fileSystem(error) }
        // Unavailable metadata is not evidence of absence; the app obtains access.
    }
}
