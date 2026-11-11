import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct TerminalCommandSetupTests {
    @Test func installIsIdempotentAndUninstallPreservesOriginalProfileAndMode() async throws {
        let fixture = try Fixture()
        let setup = fixture.setup
        let original = Data([0xEF, 0xBB, 0xBF]) + Data("export EXISTING=kept\r\n# ü".utf8)
        try original.write(to: setup.profile)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: setup.profile.path)
        #expect(try await setup.status(ownership: nil) == .absent)
        let owner = try await setup.install(ownership: nil)
        #expect(try await setup.status(ownership: owner) == .installed)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: setup.command.path) == setup.launcher.path)
        let installed = try Data(contentsOf: setup.profile)
        #expect(installed.starts(with: original))
        #expect(try fixture.lookup() == setup.command.path)
        _ = try await setup.install(ownership: owner)
        #expect(try Data(contentsOf: setup.profile) == installed)
        try await setup.uninstall(ownership: owner)
        try await setup.uninstall(ownership: owner)
        #expect(try await setup.status(ownership: owner) == .absent)
        #expect(try Data(contentsOf: setup.profile) == original)
        #expect((try FileManager.default.attributesOfItem(atPath: setup.profile.path)[.posixPermissions] as? Int) == 0o640)
        #expect(FileManager.default.isExecutableFile(atPath: setup.launcher.path))
    }

    @Test func setupDoesNotShadowAnExistingTerminalCommand() async throws {
        let fixture = try Fixture()
        let earlier = fixture.root.appendingPathComponent("Existing Commands", isDirectory: true)
        try FileManager.default.createDirectory(at: earlier, withIntermediateDirectories: false)
        let command = earlier.appendingPathComponent("panepeek")
        try FileManager.default.copyItem(at: fixture.setup.launcher, to: command)
        _ = try await fixture.setup.install(ownership: nil)
        #expect(try fixture.lookup(path: earlier.path + ":/usr/bin:/bin") == command.path)
    }

    @Test func manualPathEntryFindsTheInstalledLauncherInBash() async throws {
        let fixture = try Fixture(homeName: "Home ü 'quoted'")
        let setup = fixture.setup
        _ = try await setup.install(ownership: nil)
        let entry = try #require(setup.manualPathEntry)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["--noprofile", "--norc", "-c", entry + "\ncommand -v panepeek"]
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "BASH_ENV")
        environment["PATH"] = "/usr/bin:/bin"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let path = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(path.trimmingCharacters(in: .newlines) == setup.command.path)
    }

    @Test func commandConflictsLeaveRegularFilesDirectoriesAndDanglingLinksUntouched() async throws {
        for type in ["file", "directory", "link"] {
            let fixture = try Fixture()
            let setup = fixture.setup
            try FileManager.default.createDirectory(at: setup.command.deletingLastPathComponent(), withIntermediateDirectories: true)
            let original = Data("# existing\n".utf8)
            try original.write(to: setup.profile)
            switch type {
            case "file": try original.write(to: setup.command)
            case "directory": try FileManager.default.createDirectory(at: setup.command, withIntermediateDirectories: false)
            default: try FileManager.default.createSymbolicLink(atPath: setup.command.path, withDestinationPath: "/no/such/launcher")
            }
            #expect(try await setup.status(ownership: nil) == .conflict)
            await #expect(throws: TerminalCommandSetup.Failure.conflict) { _ = try await setup.install(ownership: nil) }
            await #expect(throws: TerminalCommandSetup.Failure.conflict) { try await setup.uninstall(ownership: nil) }
            #expect(try Data(contentsOf: setup.profile) == original)
            switch type {
            case "file": #expect(try Data(contentsOf: setup.command) == original)
            case "directory": #expect(try setup.command.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
            default: #expect(try FileManager.default.destinationOfSymbolicLink(atPath: setup.command.path) == "/no/such/launcher")
            }
        }
    }

    @Test func aMovedAppCanRemoveItsBrokenLinkButAnotherCopyCannot() async throws {
        let fixture = try Fixture()
        let setup = fixture.setup
        let owner = try await setup.install(ownership: nil)
        let movedApp = fixture.root.appendingPathComponent("Moved.app")
        let otherApp = fixture.root.appendingPathComponent("Other.app")
        try FileManager.default.copyItem(at: setup.app, to: otherApp)
        try FileManager.default.moveItem(at: setup.app, to: movedApp)
        let other = TerminalCommandSetup(home: setup.home, app: otherApp)
        let moved = TerminalCommandSetup(home: setup.home, app: movedApp)
        #expect(try await other.status(ownership: owner) == .conflict)
        await #expect(throws: TerminalCommandSetup.Failure.conflict) { try await other.uninstall(ownership: owner) }
        #expect(try await moved.status(ownership: owner) == .moved)
        await #expect(throws: TerminalCommandSetup.Failure.moved) { _ = try await moved.install(ownership: owner) }
        try await moved.uninstall(ownership: owner)
        #expect(try await moved.status(ownership: owner) == .absent)
        let repaired = try await moved.install(ownership: nil)
        #expect(try await moved.status(ownership: repaired) == .installed)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: moved.command.path) == moved.launcher.path)
    }

    @Test func unsafeProfilesAndRedirectedCommandDirectoriesAreNeverFollowed() async throws {
        let fixture = try Fixture()
        let setup = fixture.setup
        let unrelated = fixture.root.appendingPathComponent("Other Profile")
        let bytes = Data("# leave me alone\n".utf8)
        try bytes.write(to: unrelated)
        try FileManager.default.createSymbolicLink(at: setup.profile, withDestinationURL: unrelated)
        await #expect(throws: TerminalCommandSetup.Failure.profile) { _ = try await setup.install(ownership: nil) }
        #expect(try Data(contentsOf: unrelated) == bytes)
        #expect(!FileManager.default.fileExists(atPath: setup.command.path))
        try FileManager.default.removeItem(at: setup.profile)
        let outside = fixture.root.appendingPathComponent("Other Commands")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: setup.home.appendingPathComponent("Library"), withDestinationURL: outside)
        await #expect(throws: TerminalCommandSetup.Failure.conflict) { _ = try await setup.install(ownership: nil) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: setup.profile.path))
    }

    @Test func editedManagedBlockIsPreservedAndProfileWriteFailureRollsBackOnlyNewLink() async throws {
        let fixture = try Fixture()
        let setup = fixture.setup
        let owner = try await setup.install(ownership: nil)
        let changed = try String(contentsOf: setup.profile, encoding: .utf8).replacingOccurrences(of: "export PATH=", with: "# export PATH=")
        try changed.write(to: setup.profile, atomically: true, encoding: .utf8)
        await #expect(throws: TerminalProfile.Failure.changed) { try await setup.uninstall(ownership: owner) }
        #expect(try String(contentsOf: setup.profile, encoding: .utf8) == changed)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: setup.command.path) == setup.launcher.path)

        let failure = try Fixture()
        try Data("# read-only\n".utf8).write(to: failure.setup.profile)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: failure.setup.profile.path)
        await #expect(throws: (any Error).self) { _ = try await failure.setup.install(ownership: nil) }
        #expect(!FileManager.default.fileExists(atPath: failure.setup.command.path))
        #expect(try String(contentsOf: failure.setup.profile, encoding: .utf8) == "# read-only\n")
    }

    private final class Fixture {
        let root: URL
        let setup: TerminalCommandSetup

        init(homeName: String = "Home ü") throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-terminal-" + UUID().uuidString).resolvingSymlinksInPath()
            let home = root.appendingPathComponent(homeName, isDirectory: true)
            let app = root.appendingPathComponent("PanePeek Review.app", isDirectory: true)
            setup = TerminalCommandSetup(home: home, app: app)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: setup.launcher.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: setup.launcher)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: setup.launcher.path)
        }

        deinit { try? FileManager.default.removeItem(at: root) }

        func lookup(path: String = "/usr/bin:/bin") throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-d", "-l", "-c", "command -v panepeek"]
            process.environment = ProcessInfo.processInfo.environment.merging(["ZDOTDIR": setup.home.path, "PATH": path]) { _, new in new }
            let output = Pipe()
            process.standardOutput = output
            try process.run()
            process.waitUntilExit()
            return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .newlines)
        }
    }
}
