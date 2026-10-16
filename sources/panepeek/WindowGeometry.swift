import AppKit

enum WindowGeometry {
    static let minimumContentSize = NSSize(width: 800, height: 480)

    static func decode(_ record: Any?) -> NSRect? {
        guard let fields = record as? [String: Double],
              let x = fields["x"], let y = fields["y"],
              let width = fields["width"], let height = fields["height"],
              [x, y, width, height, x + width, y + height].allSatisfy(\.isFinite),
              width > 0, height > 0 else { return nil }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    static func record(_ frame: NSRect) -> [String: Double] {
        ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
    }

    static func constrained(_ frame: NSRect, screens: [NSRect], minimumSize: NSSize) -> NSRect {
        guard let screen = screens.max(by: { score(frame, in: $0) < score(frame, in: $1) }) else { return frame }
        let width = min(max(frame.width, minimumSize.width), screen.width)
        let height = min(max(frame.height, minimumSize.height), screen.height)
        return NSRect(x: min(max(frame.minX, screen.minX), screen.maxX - width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - height), width: width, height: height)
    }

    private static func score(_ frame: NSRect, in screen: NSRect) -> CGFloat {
        let overlap = frame.intersection(screen)
        if !overlap.isNull && overlap.width > 0 && overlap.height > 0 { return overlap.width * overlap.height }
        return -hypot(frame.midX - screen.midX, frame.midY - screen.midY)
    }
}
