import Foundation
import Observation

/// A primary item and its successful listing revision, including same-item Refresh.
public struct DetailsSelection: Sendable, Equatable {
    public let item: DirectoryEntry
    public let listingRevision: UUID
    /// Keeps folder access alive independently of the originating pane.
    public let access: DirectoryAccess?

    public init(item: DirectoryEntry, listingRevision: UUID, access: DirectoryAccess? = nil) {
        self.item = item
        self.listingRevision = listingRevision
        self.access = access
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item == rhs.item && lhs.listingRevision == rhs.listingRevision
    }
}

@MainActor @Observable
public final class DetailsState {
    public private(set) var selection: DetailsSelection?
    public private(set) var metadata: ItemMetadata?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private let read: @Sendable (DirectoryEntry) async throws -> ItemMetadata
    private var requestID = UUID()

    public init(read: @escaping @Sendable (DirectoryEntry) async throws -> ItemMetadata = ItemMetadata.read) {
        self.read = read
    }

    /// Replace details for a selection, discarding superseded or cancelled reads.
    public func load(_ selection: DetailsSelection?) async {
        defer { withExtendedLifetime(selection) {} }
        guard !Task.isCancelled else { return }
        let request = UUID()
        requestID = request
        self.selection = selection
        metadata = nil
        errorMessage = nil
        isLoading = selection != nil
        defer {
            if requestID == request { isLoading = false }
        }
        guard let selection else { return }
        do {
            let metadata = try await read(selection.item)
            guard requestID == request, !Task.isCancelled else { return }
            self.metadata = metadata
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t read file information. \(error.localizedDescription)"
        }
    }
}
