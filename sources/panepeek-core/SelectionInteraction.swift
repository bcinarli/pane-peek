import Foundation

public enum SelectionInteraction {
    /// Follows the interacted row, falling back to the primary before any interaction.
    public static func keyboardEndpoint(in entries: [DirectoryEntry], interactedItem: URL?,
                                        primaryItem: URL?, movingUp: Bool) -> URL? {
        let current = interactedItem ?? primaryItem
        guard let index = entries.firstIndex(where: { $0.url == current }) else { return nil }
        let next = movingUp ? max(0, index - 1) : min(entries.count - 1, index + 1)
        return entries[next].url
    }

    /// Retains native keyboard position when the interacted row disappears.
    public static func reconciledItem(_ interactedItem: URL?, from oldEntries: [DirectoryEntry],
                                      to entries: [DirectoryEntry]) -> URL? {
        guard let index = oldEntries.firstIndex(where: { $0.url == interactedItem }),
              !entries.contains(where: { $0.url == interactedItem }) else { return interactedItem }
        return entries.isEmpty ? nil : entries[min(index, entries.count - 1)].url
    }
}
