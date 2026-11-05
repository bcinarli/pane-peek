import Foundation

public struct BrowserColumnWidths: Equatable, Sendable {
    public struct Name: Equatable, Sendable {
        public let width: CGFloat
        public let viewport: CGFloat

        public init(width: CGFloat, viewport: CGFloat) {
            self.width = width
            self.viewport = viewport
        }
    }

    public var name: Name?
    public var size: CGFloat?
    public var modified: CGFloat?

    public init(name: Name? = nil, size: CGFloat? = nil, modified: CGFloat? = nil) {
        self.name = name
        self.size = size
        self.modified = modified
    }

    public static func minimum(for field: DirectorySortField) -> CGFloat {
        switch field {
        case .name: 160
        case .size: 72
        case .lastModified: 120
        }
    }

    public static func initialWidth(for field: DirectorySortField) -> CGFloat {
        field == .lastModified ? 136 : minimum(for: field)
    }
}
