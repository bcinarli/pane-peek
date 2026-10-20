import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct SaveOwnershipTests {
    @Test(arguments: [TextFileSnapshot.QuarantinePolicy.preserveExisting, .systemManaged])
    func saveRetainsOwnerGroupAndModeAcrossRepeatedSaves(policy: TextFileSnapshot.QuarantinePolicy) async throws {
        let fixture = try OwnershipFixture()
        defer { fixture.remove() }
        try #require(chown(fixture.file.path, uid_t.max, fixture.otherGroup) == 0)
        try #require(chmod(fixture.file.path, 0o2640) == 0)
        let original = try fixture.attributes()
        let parent = try fixture.attributes(at: fixture.root)
        try #require(original.st_gid != parent.st_gid)
        var snapshot = try #require(try await TextPreview.load(fixture.selection.item).snapshot)
        for text in ["draft", "saved again"] {
            snapshot = try await snapshot.save(text, to: fixture.file, quarantine: policy)
            let saved = try fixture.attributes()
            #expect(saved.st_uid == original.st_uid && saved.st_gid == original.st_gid)
            #expect(saved.st_mode == original.st_mode)
            #expect(try String(contentsOf: fixture.file, encoding: .utf8) == text)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["notes.txt"])
    }

    @Test @MainActor func aGroupChangeAfterOpeningRejectsSaveAndRetainsTheDraft() async throws {
        let fixture = try OwnershipFixture()
        defer { fixture.remove() }
        let state = PreviewState()
        await state.load(fixture.selection)
        state.setMode(.edit)
        await state.updateText("draft")?.value
        try #require(chown(fixture.file.path, uid_t.max, fixture.otherGroup) == 0)
        let changed = try fixture.attributes()
        #expect(!(await state.save()))
        #expect(state.isDirty && state.text == "draft" && state.errorMessage != nil)
        let retained = try fixture.attributes()
        #expect(retained.st_ino == changed.st_ino && retained.st_gid == changed.st_gid)
        #expect(try String(contentsOf: fixture.file, encoding: .utf8) == "original")
    }

    @Test func aGroupChangeDuringRenameCannotBecomeTheSavedBaseline() async throws {
        let fixture = try OwnershipFixture()
        defer { fixture.remove() }
        let snapshot = try #require(try await TextPreview.load(fixture.selection.item).snapshot)
        let renamed = fixture.root.appendingPathComponent("renamed.txt")
        try FileManager.default.moveItem(at: fixture.file, to: renamed)
        try #require(chown(renamed.path, uid_t.max, fixture.otherGroup) == 0)
        await #expect(throws: (any Error).self) {
            _ = try await snapshot.acceptingRestoredFile(at: renamed)
        }
        #expect(try String(contentsOf: renamed, encoding: .utf8) == "original")
    }
}

private struct OwnershipFixture {
    let root: URL
    let otherGroup: gid_t
    var file: URL { root.appendingPathComponent("notes.txt") }
    var selection: DetailsSelection {
        DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID())
    }

    init() throws {
        let count = getgroups(0, nil)
        try #require(count > 0)
        var groups = [gid_t](repeating: 0, count: Int(count))
        try #require(getgroups(count, &groups) == count)
        otherGroup = try #require(groups.first { $0 != getegid() })
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-save-ownership-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try #require(chown(root.path, uid_t.max, getegid()) == 0)
        try Data("original".utf8).write(to: file)
    }

    func attributes(at url: URL? = nil) throws -> stat {
        var result = stat()
        try #require(lstat((url ?? file).path, &result) == 0)
        return result
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
