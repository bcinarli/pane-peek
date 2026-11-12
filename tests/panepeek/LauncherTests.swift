import Foundation
import Testing
@testable import PanePeek

struct LauncherTests {
    @Test func versionUsesOnlyValidPackagedVersionBuildAndCandidateMetadata() throws {
        let stable: [String: Any] = ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "11"]
        #expect(try Launcher.packagedVersion(stable) == "PanePeek 1.3.0 (11)")
        for suffix in ["beta.1", "rc.12"] {
            #expect(try Launcher.packagedVersion(stable.merging(["PanePeekPrereleaseSuffix": suffix]) { _, value in value })
                    == "PanePeek 1.3.0-\(suffix) (11)")
        }
        for invalid in [
            [:], ["CFBundleShortVersionString": "1.3.0"], ["CFBundleVersion": "11"],
            ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "0"],
            ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "01"],
            ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "9007199254740992"],
            ["CFBundleShortVersionString": "1.3.0\n", "CFBundleVersion": "11"],
            ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "11", "PanePeekPrereleaseSuffix": ""],
            ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "11", "PanePeekPrereleaseSuffix": "beta.0"],
            ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "11", "PanePeekPrereleaseSuffix": "rc.9007199254740992"],
        ] as [[String: Any]] {
            #expect(throws: LauncherFailure.bundle) { try Launcher.packagedVersion(invalid) }
        }
    }

    @Test func handoffRejectsSelfAndAnotherCopyButAcceptsAliasesOfTheContainingApp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-handoff-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("first/PanePeek.app")
        let other = root.appendingPathComponent("second/PanePeek.app")
        for directory in [app, other] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let alias = root.appendingPathComponent("alias.app")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: app)
        func confirmed(_ url: URL?, id: String? = "example.panepeek", pid: Int32 = 101) -> Bool {
            Launcher.confirmsApplication(expected: app, identifier: "example.panepeek", actual: url,
                                         actualIdentifier: id, process: pid, caller: 100)
        }
        #expect(confirmed(app))
        #expect(confirmed(alias))
        #expect(!confirmed(other))
        #expect(!confirmed(app, pid: 100))
        #expect(!confirmed(app, pid: 0))
        #expect(!confirmed(app, id: "different.app"))
        #expect(!confirmed(nil))
    }
}
