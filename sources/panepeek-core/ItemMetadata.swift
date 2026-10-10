import Foundation

public struct ItemMetadata: Sendable, Equatable {
    public let createdDate: Date?
    public let modifiedDate: Date?
    public let permissions: UInt16?
    public let owner: String?
    public let group: String?
    public let type: String?
    public let size: UInt64?
    public let targetPath: String?

    public init(createdDate: Date? = nil, modifiedDate: Date? = nil, permissions: UInt16? = nil,
                owner: String? = nil, group: String? = nil, type: String? = nil,
                size: UInt64? = nil, targetPath: String? = nil) {
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.permissions = permissions
        self.owner = owner
        self.group = group
        self.type = type
        self.size = size
        self.targetPath = targetPath
    }

    /// Unix access and special bits, without a file-type prefix.
    public var permissionsDescription: String {
        guard let permissions else { return "Unavailable" }
        let mode = permissions & 0o7777
        var symbols = Array("---------")
        let bits: [UInt16] = [0o400, 0o200, 0o100, 0o040, 0o020, 0o010, 0o004, 0o002, 0o001]
        for (index, bit) in bits.enumerated() where mode & bit != 0 {
            symbols[index] = Array("rwx")[index % 3]
        }
        for (bit, index, enabled, disabled): (UInt16, Int, Character, Character) in [
            (0o4000, 2, "s", "S"), (0o2000, 5, "s", "S"), (0o1000, 8, "t", "T")
        ] where mode & bit != 0 {
            symbols[index] = symbols[index] == "x" ? enabled : disabled
        }
        return String(format: "%04o", mode) + " · " + String(symbols)
    }

    /// Reads the listed item's own attributes off the UI thread; link targets are not traversed.
    public static func read(_ item: DirectoryEntry) async throws -> ItemMetadata {
        try await Task.detached(priority: .userInitiated) {
            let files = FileManager.default
            let attributes = try files.attributesOfItem(atPath: item.url.path)
            let type = attributes[.type] as? FileAttributeType
            let target = type == .typeSymbolicLink ? try? files.destinationOfSymbolicLink(atPath: item.url.path) : nil
            return ItemMetadata(
                createdDate: attributes[.creationDate] as? Date,
                modifiedDate: attributes[.modificationDate] as? Date,
                permissions: (attributes[.posixPermissions] as? NSNumber)?.uint16Value,
                owner: attributes[.ownerAccountName] as? String
                    ?? (attributes[.ownerAccountID] as? NSNumber).map { "UID \($0)" },
                group: attributes[.groupOwnerAccountName] as? String
                    ?? (attributes[.groupOwnerAccountID] as? NSNumber).map { "GID \($0)" },
                type: typeDescription(type, isPackage: item.isPackage),
                size: type == .typeRegular || type == .typeSymbolicLink
                    ? (attributes[.size] as? NSNumber)?.uint64Value : nil,
                targetPath: target
            )
        }.value
    }

    private static func typeDescription(_ type: FileAttributeType?, isPackage: Bool) -> String? {
        switch type {
        case .typeRegular: return "File"
        case .typeDirectory: return isPackage ? "Package" : "Folder"
        case .typeSymbolicLink: return "Symbolic link"
        case .typeSocket: return "Socket"
        case .typeCharacterSpecial: return "Character device"
        case .typeBlockSpecial: return "Block device"
        case nil: return nil
        default: return "Other"
        }
    }
}
