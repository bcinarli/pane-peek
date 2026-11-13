import Foundation
import Testing
@testable import PanePeekCore

struct TerminalProfileTests {
    @Test func installationAndRemovalPreserveExistingProfileBytes() throws {
        let profile = try TerminalProfile(directory: URL(fileURLWithPath: "/example/PanePeek/bin"))
        for original in ["", "export EXISTING=kept", "# ü\r\nexport EXISTING=kept\r\n", "\u{feff}# existing\n"] {
            let installed = try profile.installing(in: original)
            #expect(installed.hasPrefix(original))
            #expect(installed.contains("export PATH="))
            #expect(try profile.installing(in: installed) == installed)
            #expect(try profile.removing(from: installed) == original)
        }
    }

    @Test func removalPreservesUnrelatedChangesAndRefusesChangedOrDuplicateBlocks() throws {
        let profile = try TerminalProfile(directory: URL(fileURLWithPath: "/example/PanePeek/bin"))
        let original = "export EXISTING=kept\n"
        let installed = try profile.installing(in: original)
        #expect(try profile.removing(from: installed + "# later edit\n") == original + "# later edit\n")
        for modified in [installed + installed, installed.replacingOccurrences(of: "/example/PanePeek/bin", with: "/other/bin"),
                         "# >>> PanePeek terminal command >>>\n", "# <<< PanePeek terminal command <<<\n"] {
            #expect(throws: TerminalProfile.Failure.changed) { try profile.installing(in: modified) }
            #expect(throws: TerminalProfile.Failure.changed) { try profile.removing(from: modified) }
        }
        #expect(try profile.removing(from: original) == original)
    }

    @Test func pathIsLiteralShellDataAndUnsupportedPathSeparatorsAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-profile-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("space ü ' $(printf injected) bin")
        let profile = try TerminalProfile(directory: directory)
        let zdotdir = root.appendingPathComponent("profile")
        try FileManager.default.createDirectory(at: zdotdir, withIntermediateDirectories: false)
        try profile.installing(in: "# generated profile\n").write(to: zdotdir.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-d", "-l", "-c", "print -r -- \"$path[-1]\""]
        process.environment = ProcessInfo.processInfo.environment.merging(["ZDOTDIR": zdotdir.path, "PATH": "/usr/bin:/bin"]) { _, new in new }
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let line = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(line == directory.path + "\n")
        for path in ["/example/colon:bin", "/example/new\nline", "/example/carriage\rreturn", "/example/line\r\nbreak"] {
            #expect(throws: TerminalProfile.Failure.unsupportedPath) { _ = try TerminalProfile(directory: URL(fileURLWithPath: path)) }
        }
    }
}
