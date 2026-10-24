import Foundation
import Testing
import CryptoKit
@testable import PanePeek

struct UpdateInstallerTests {
    @Test func unsignedAndUnquarantinedPayloadsCannotPassValidation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("payload.dmg")
        let bytes = Data("untrusted payload".utf8)
        try bytes.write(to: file)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        await #expect(throws: (any Error).self) { try await UpdateInstaller.validate(file, digest: hash) }
        var values = URLResourceValues()
        values.quarantineProperties = ["LSQuarantineType": "LSQuarantineTypeOtherDownload"]
        var quarantined = file
        try quarantined.setResourceValues(values)
        await #expect(throws: (any Error).self) { try await UpdateInstaller.validate(file, digest: hash) }
        await #expect(throws: (any Error).self) { try await UpdateInstaller.validate(file, digest: String(repeating: "a", count: 64)) }
    }

    @Test func aChangedOversizedInstallerIsRejectedBeforeHashingOrOpening() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        var file = root.appendingPathComponent("oversized.dmg")
        try Data().write(to: file)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(UpdateTransport.maximumDownloadBytes + 1))
        try handle.close()
        var values = URLResourceValues()
        values.quarantineProperties = ["LSQuarantineType": "LSQuarantineTypeOtherDownload"]
        try file.setResourceValues(values)
        do { try await UpdateInstaller.validate(file, digest: "unused"); Issue.record("Expected size rejection") }
        catch UpdateError.tooLarge { }
        catch { Issue.record("Expected size rejection before hashing, got \(error)") }
    }

    @Test func storageRejectsLinksAndBoundsRetainedInstallersWithoutRemovingThem() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = UpdateStorage(root: root)
        #expect(throws: (any Error).self) { try storage.staging(size: 0) }
        #expect(throws: (any Error).self) { try storage.staging(size: UpdateTransport.maximumDownloadBytes + 1) }
        let retained = root.appendingPathComponent("retained.dmg")
        try Data().write(to: retained)
        let file = try FileHandle(forWritingTo: retained)
        try file.truncate(atOffset: 512 * 1024 * 1024)
        try file.close()
        #expect(throws: (any Error).self) { try storage.staging(size: 1) }
        #expect(FileManager.default.fileExists(atPath: retained.path))
        let linkedRoot = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
        #expect(throws: (any Error).self) { try UpdateStorage(root: linkedRoot).staging(size: 1) }
    }

    @Test func cleanupRemovesOnlyOldOwnedPartials() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("\(UUID()).partial")
        let recent = root.appendingPathComponent("\(UUID()).partial")
        let complete = root.appendingPathComponent("\(UUID()).dmg")
        for url in [old, recent, complete] { try Data("data".utf8).write(to: url) }
        for url in [old, complete] { try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-90000)], ofItemAtPath: url.path) }
        _ = try UpdateStorage(root: root).staging(size: 1)
        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: recent.path))
        #expect(FileManager.default.fileExists(atPath: complete.path))
    }
}
