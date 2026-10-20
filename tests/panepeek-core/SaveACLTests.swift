import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct SaveACLTests {
    @Test(arguments: ["explicit", "inherited", "none"],
          [TextFileSnapshot.QuarantinePolicy.preserveExisting, .systemManaged])
    func saveRetainsTheSourceACLInsteadOfInheritingTheStagingACL(kind: String, policy: TextFileSnapshot.QuarantinePolicy) async throws {
        let fixture = try ACLFixture()
        defer { fixture.remove() }
        if kind == "inherited" { try fixture.chmod(["+a", "user:nobody deny read,file_inherit"], at: fixture.root) }
        try Data("original".utf8).write(to: fixture.file)
        try fixture.chmod(["0644"], at: fixture.file)
        if kind == "explicit" { try fixture.chmod(["+a", "user:nobody deny read"], at: fixture.file) }
        let originalACL = try fixture.acl()
        try #require(kind == "none" ? originalACL.isEmpty : originalACL.contains("deny"))
        try #require(originalACL.contains("inherited") == (kind == "inherited"))
        try fixture.chmod(["-N"], at: fixture.root)
        try fixture.chmod(["+a", "user:nobody allow read,file_inherit"], at: fixture.root)
        var snapshot = try #require(try await TextPreview.load(fixture.selection.item).snapshot)
        for text in ["draft", "saved again"] {
            snapshot = try await snapshot.save(text, to: fixture.file, quarantine: policy)
            #expect(try fixture.acl() == originalACL)
            #expect(try String(contentsOf: fixture.file, encoding: .utf8) == text)
            #expect(try FileManager.default.attributesOfItem(atPath: fixture.file.path)[.posixPermissions] as? Int == 0o644)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["notes.txt"])
    }

    @Test @MainActor func anACLChangeAfterOpeningRejectsSaveAndRetainsTheDraft() async throws {
        let fixture = try ACLFixture()
        defer { fixture.remove() }
        try Data("original".utf8).write(to: fixture.file)
        let state = PreviewState()
        await state.load(fixture.selection)
        state.setMode(.edit)
        await state.updateText("draft")?.value
        try fixture.chmod(["+a", "user:nobody deny read"], at: fixture.file)
        let changedACL = try fixture.acl()
        #expect(!(await state.save()))
        #expect(state.isDirty && state.text == "draft" && state.errorMessage != nil)
        #expect(try fixture.acl() == changedACL)
        #expect(try String(contentsOf: fixture.file, encoding: .utf8) == "original")
    }
}

private struct ACLFixture {
    let root: URL
    var file: URL { root.appendingPathComponent("notes.txt") }
    var selection: DetailsSelection {
        DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID())
    }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-save-acl-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    func chmod(_ arguments: [String], at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = arguments + [url.path]
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
    }

    func acl() throws -> String {
        guard let acl = acl_get_file(file.path, ACL_TYPE_EXTENDED) else {
            if errno == ENOENT { return "" }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        let text = try #require(acl_to_text(acl, nil))
        defer { acl_free(text) }
        return String(cString: text)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
