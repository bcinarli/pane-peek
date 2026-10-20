import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct ExecutableFileTests {
    @Test func atomicSavePreservesExistingQuarantineAndExecutablePermissions() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("script.sh")
        try Data("#!/bin/sh\nprintf 'original\\n'\n".utf8).write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
        let quarantine = Data("0083;00000000;PanePeek Test;".utf8)
        try setQuarantine(quarantine, at: source)
        let loaded = try await TextPreview.load(DirectoryEntry(url: source, isDirectory: false))
        let snapshot = try #require(loaded.snapshot)
        _ = try await snapshot.save("#!/bin/sh\nprintf 'saved\\n'\n", to: source)
        #expect(try getQuarantine(at: source) == quarantine)
        #expect(try FileManager.default.attributesOfItem(atPath: source.path)[.posixPermissions] as? Int == 0o755)
        #expect(try String(contentsOf: source, encoding: .utf8) == "#!/bin/sh\nprintf 'saved\\n'\n")
    }

    @Test(arguments: [TextFileSnapshot.QuarantinePolicy.preserveExisting, .systemManaged])
    func quarantineChangedAfterOpeningRejectsSaveAndRetainsTheFile(policy: TextFileSnapshot.QuarantinePolicy) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("script.sh")
        let original = Data("#!/bin/sh\nprintf 'original\\n'\n".utf8)
        try original.write(to: source)
        let loaded = try await TextPreview.load(DirectoryEntry(url: source, isDirectory: false))
        let snapshot = try #require(loaded.snapshot)
        let quarantine = Data("0083;00000000;PanePeek Test;".utf8)
        try setQuarantine(quarantine, at: source)
        await #expect(throws: (any Error).self) { _ = try await snapshot.save("draft", to: source, quarantine: policy) }
        #expect(try Data(contentsOf: source) == original)
        #expect(try getQuarantine(at: source) == quarantine)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["script.sh"])
    }

    @Test(arguments: [false, true])
    func copyingAndMovingPreserveExecutableModeAndQuarantine(moving: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("script.sh")
        let destination = root.appendingPathComponent("Destination", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let bytes = Data("#!/bin/sh\nprintf 'synthetic\\n'\n".utf8)
        try bytes.write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
        let quarantine = Data("0083;00000000;PanePeek Test;".utf8)
        try setQuarantine(quarantine, at: source)
        if moving {
            let operation = try await ItemMove.Batch.capture([source], to: destination)
            #expect(await operation.move().succeeded)
        } else {
            let operation = try await ItemCopy.capture(source, to: destination)
            #expect(await operation.copy().succeeded)
        }
        let output = destination.appendingPathComponent(source.lastPathComponent)
        #expect(try getQuarantine(at: output) == quarantine)
        #expect(try FileManager.default.attributesOfItem(atPath: output.path)[.posixPermissions] as? Int == 0o755)
        #expect(try Data(contentsOf: output) == bytes)
        #expect(FileManager.default.fileExists(atPath: source.path) != moving)
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-executable-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func setQuarantine(_ data: Data, at url: URL) throws {
        let result = data.withUnsafeBytes { setxattr(url.path, "com.apple.quarantine", $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW) }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private func getQuarantine(at url: URL) throws -> Data? {
        let size = getxattr(url.path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW)
        if size < 0 && errno == ENOATTR { return nil }
        guard size >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var data = Data(count: size)
        let count = data.withUnsafeMutableBytes { getxattr(url.path, "com.apple.quarantine", $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW) }
        guard count == size else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return data
    }
}
