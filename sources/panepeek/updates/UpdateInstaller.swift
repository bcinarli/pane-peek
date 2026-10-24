#if !PANEPEEK_APP_STORE
import Foundation
import Security
import CryptoKit

struct UpdateInstaller: Sendable {
    // The public production publisher, independent of the certificate used for local review builds.
    private static let requirement = "anchor apple generic and certificate leaf[subject.OU] = VUFJLDLSHH and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and identifier com.bcinarli.PanePeek.diskimage"

    static func validate(_ url: URL, digest: String) async throws {
        let work = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .quarantinePropertiesKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  values.quarantineProperties != nil else { throw UpdateError.validation }
            guard let size = values.fileSize, size > 0, size <= UpdateTransport.maximumDownloadBytes else { throw UpdateError.tooLarge }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            var hash = SHA256()
            var bytes: Int64 = 0
            while let chunk = try file.read(upToCount: 64 * 1024), !chunk.isEmpty {
                try Task.checkCancellation()
                bytes += Int64(chunk.count)
                guard bytes <= UpdateTransport.maximumDownloadBytes else { throw UpdateError.tooLarge }
                hash.update(data: chunk)
            }
            guard bytes == size else { throw UpdateError.validation }
            guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == digest else { throw UpdateError.validation }
            var code: SecStaticCode?
            var requirement: SecRequirement?
            guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
                  SecRequirementCreateWithString(Self.requirement as CFString, [], &requirement) == errSecSuccess,
                  let requirement,
                  SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess else {
                throw UpdateError.validation
            }
            var information: CFDictionary?
            guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
                  let information = information as? [String: Any], information[kSecCodeInfoTimestamp as String] is Date else {
                throw UpdateError.validation
            }
            try Task.checkCancellation()
        }
        try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
    }
}

struct UpdateStorage: Sendable {
    let root: URL
    private static let maximumStoredBytes: Int64 = 512 * 1024 * 1024

    func staging(size: Int64) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else { throw UpdateError.storage }
        var used: Int64 = 0
        for url in try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw UpdateError.storage }
            if url.pathExtension == "partial", UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil,
               let date = values.contentModificationDate, date < Date().addingTimeInterval(-86400) {
                try manager.removeItem(at: url)
            } else { used += Int64(values.fileSize ?? 0) }
        }
        let free = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        guard size > 0, size <= UpdateTransport.maximumDownloadBytes,
              used <= Self.maximumStoredBytes - size, let free, free > size + 16 * 1024 * 1024 else { throw UpdateError.storage }
        return root.appendingPathComponent("\(UUID()).partial")
    }
}

#endif
