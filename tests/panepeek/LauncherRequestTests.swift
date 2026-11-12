import Foundation
import Darwin
import Testing
@testable import PanePeek

struct LauncherRequestTests {
    @Test func informationCommandsAreStandalone() throws {
        #expect(try LauncherCommand.parse(["--help"]) == .help)
        #expect(try LauncherCommand.parse(["--version"]) == .version)
        for arguments in [["--help", "."], [".", "--version"], ["--help", "--version"]] {
            #expect(throws: LauncherFailure.usage) { try LauncherCommand.parse(arguments) }
        }
    }

    @Test func oneTargetAndRevealRespectTheOptionBoundary() throws {
        #expect(try LauncherCommand.parse([]) == .open(".", .open))
        #expect(try LauncherCommand.parse(["folder ü"]) == .open("folder ü", .open))
        #expect(try LauncherCommand.parse(["--reveal", "folder"]) == .open("folder", .reveal))
        #expect(try LauncherCommand.parse(["folder", "--reveal"]) == .open("folder", .reveal))
        #expect(try LauncherCommand.parse(["--", "--reveal"]) == .open("--reveal", .open))
        #expect(try LauncherCommand.parse(["--reveal", "--", "-file"]) == .open("-file", .reveal))
        for arguments in [["--reveal"], ["--reveal", "--reveal", "."], ["--unknown"],
                          ["a", "b"], ["a", "--", "b"], [""], ["--", ""], ["--reveal", "--"]] {
            #expect(throws: LauncherFailure.usage) { try LauncherCommand.parse(arguments) }
        }
    }

    @Test func relativeDotAndAncestorLinksUseFilesystemTraversal() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target", isDirectory: true)
        let child = target.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let file = target.appendingPathComponent("document.txt")
        try Data().write(to: file)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("alias"), withDestinationURL: child)
        #expect(try request(".", in: root).path == root.path)
        #expect(try request("alias/../document.txt", in: root).path == file.path)
        #expect(try request("alias/..", in: root, intent: .reveal).path == target.path)
        #expect(try request("/", in: root, intent: .reveal).path == "/")
    }

    @Test func revealRetainsTheNamedLinkAndDanglingLinksRemainSelectable() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("directory link")
        let dangling = root.appendingPathComponent("dangling")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        try FileManager.default.createSymbolicLink(at: dangling, withDestinationURL: root.appendingPathComponent("absent"))
        let revealed = try request("directory link/", in: root, intent: .reveal)
        #expect(revealed.path == link.path && revealed.requiresDirectory)
        #expect(try request("dangling", in: root).path == dangling.path)
        #expect(throws: (any Error).self) { try request("dangling/", in: root) }
        #expect(throws: (any Error).self) { try request("absent", in: root) }
        let file = root.appendingPathComponent("file")
        try Data().write(to: file)
        #expect(throws: (any Error).self) { try request("file/", in: root) }
    }

    @Test func deniedMetadataIsLeftForTheAppsAccessFlow() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let denied = root.appendingPathComponent("denied", isDirectory: true)
        try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path) }
        let path = denied.appendingPathComponent("unknown")
        #expect(try request(path.path, in: root).path == path.path)
    }

    @Test func localEventRoundTripsLiteralPathsAndIntent() throws {
        for path in ["/tmp/space ü/%?#&=+file", "/tmp/line\nbreak", "/-leading", "/"] {
            for intent in [LauncherRequest.Intent.open, .reveal] {
                for required in [false, true] {
                    let request = LauncherRequest(path: path, intent: intent, requiresDirectory: required)
                    #expect(LauncherRequest(eventURL: request.eventURL) == request)
                }
            }
        }
    }

    @Test func malformedOrNonlocalEventDataIsRejected() {
        for value in [
            "https://open?path=/tmp&intent=open&directory=0",
            "panepeek://other?path=/tmp&intent=open&directory=0",
            "panepeek://user@open?path=/tmp&intent=open&directory=0",
            "panepeek://open:80?path=/tmp&intent=open&directory=0",
            "panepeek://open/extra?path=/tmp&intent=open&directory=0",
            "panepeek://open?path=/tmp&intent=open&directory=0#fragment",
            "panepeek://open?path=relative&intent=open&directory=0",
            "panepeek://open?path=/tmp&path=/other&intent=open&directory=0",
            "panepeek://open?path=/tmp&intent=execute&directory=0",
            "panepeek://open?path=/tmp&intent=open&directory=yes",
            "panepeek://open?path=/tmp&intent=open&directory=0&extra=1",
            "panepeek://open?path=%00&intent=open&directory=0",
            "panepeek://open?path=%FF&intent=open&directory=0",
            "panepeek://open?intent=open&directory=0",
        ] {
            #expect(LauncherRequest(eventURL: URL(string: value)!) == nil)
        }
    }

    private func request(_ path: String, in root: URL, intent: LauncherRequest.Intent = .open) throws -> LauncherRequest {
        try LauncherRequest.resolve(path, relativeTo: root.path, intent: intent)
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-launcher-" + UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        guard let physical = root.path.withCString({ realpath($0, nil) }) else { throw POSIXError(.EIO) }
        defer { free(physical) }
        return URL(fileURLWithPath: String(cString: physical), isDirectory: true)
    }
}
