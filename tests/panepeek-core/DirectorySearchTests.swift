import Foundation
import Testing
@testable import PanePeekCore

struct DirectorySearchTests {
    @Test func searchesNestedNamesAndSkipsHiddenTreesPackagesAndLinks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-search-\(UUID())").resolvingSymlinksInPath()
        let files = FileManager.default
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        for folder in ["nested/deeper", ".hidden", "Bundle.app/Contents"] {
            try files.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for name in ["Report.txt", "nested/report notes.txt", "nested/deeper/REPORT.txt", ".hidden/report.txt", "Bundle.app/Contents/report.txt"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        try files.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let result = try await DirectorySearch.read(root, query: "REPORT", showHidden: false)
        #expect(Set(result.entries.map { $0.url.path.replacingOccurrences(of: root.path + "/", with: "") })
                == ["Report.txt", "nested/report notes.txt", "nested/deeper/REPORT.txt"])
        let hidden = try await DirectorySearch.read(root, query: "report", showHidden: true)
        #expect(hidden.entries.count == 4)
        #expect(hidden.entries.first { $0.url.path.contains("/.hidden/") }?.isHidden == true)
        #expect(!result.reachedLimit && result.skippedDirectories == 0)
    }

    @Test func matchesUnicodeAndLiteralSpacesAndReportsPartialTraversal() async throws {
        let root = URL(fileURLWithPath: "/search", isDirectory: true)
        let loader: @Sendable (URL) async throws -> DirectoryListing = { directory in
            if directory.lastPathComponent == "unreadable" { throw CocoaError(.fileReadNoPermission) }
            let names = directory == root ? ["CAFÉ notes.txt", "cafe.txt", "unreadable", "deep"] : ["cafe\u{301} notes.txt"]
            return DirectoryListing(directory: directory, entries: names.map {
                DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: ["unreadable", "deep"].contains($0))
            })
        }
        let result = try await DirectorySearch.read(root, query: "café notes", showHidden: false, load: loader)
        #expect(result.entries.count == 2)
        #expect(result.skippedDirectories == 1)
        let spaces = try await DirectorySearch.read(root, query: " notes", showHidden: false, load: loader)
        #expect(spaces.entries.count == 2)
        let bounded = try await DirectorySearch.read(root, query: "", showHidden: false, load: loader, maximumEntries: 2)
        #expect(bounded.reachedLimit)
        #expect(bounded.entries.count <= 2)
    }

    @Test func cancellationAndRootFailureAreNotSuccessfulEmptyResults() async throws {
        let root = URL(fileURLWithPath: "/search")
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await DirectorySearch.read(root, query: "a", showHidden: false, load: { .init(directory: $0, entries: []) })
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        await #expect(throws: CocoaError.self) {
            try await DirectorySearch.read(root, query: "a", showHidden: false, load: { _ in throw CocoaError(.fileReadNoPermission) })
        }
    }
    @Test func changedRootAndOutsideSubfolderAreRejected() async throws {
        let root = URL(fileURLWithPath: "/search", isDirectory: true)
        let outside = URL(fileURLWithPath: "/elsewhere", isDirectory: true)
        await #expect(throws: CocoaError.self) {
            try await DirectorySearch.read(root, query: "secret", showHidden: false,
                load: { _ in .init(directory: outside, entries: []) })
        }
        let result = try await DirectorySearch.read(root, query: "secret", showHidden: false, load: { directory in
            if directory == root {
                return .init(directory: root, entries: [DirectoryEntry(url: root.appendingPathComponent("replaced"), isDirectory: true)])
            }
            return .init(directory: outside, entries: [DirectoryEntry(url: outside.appendingPathComponent("secret.txt"), isDirectory: false)])
        })
        #expect(result.entries.isEmpty && result.skippedDirectories == 1)
    }

}
