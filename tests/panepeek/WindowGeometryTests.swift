import AppKit
import Testing
@testable import PanePeek

struct WindowGeometryTests {
    @Test func visibleNegativeCoordinatesArePreservedAndLargestOverlapSelectsTheScreen() {
        let left = NSRect(x: -1600, y: 0, width: 1600, height: 1000)
        let main = NSRect(x: 0, y: 0, width: 1400, height: 900)
        let frame = NSRect(x: -1400, y: 100, width: 1100, height: 650)
        #expect(WindowGeometry.constrained(frame, screens: [main, left], minimumSize: .zero) == frame)
        let straddling = NSRect(x: -900, y: 100, width: 1100, height: 650)
        let constrained = WindowGeometry.constrained(straddling, screens: [main, left], minimumSize: .zero)
        #expect(constrained == NSRect(x: -1100, y: 100, width: 1100, height: 650))
    }

    @Test func removedScreensOversizedFramesAndMinimumsKeepUsableBounds() {
        let screen = NSRect(x: 100, y: 80, width: 1400, height: 900)
        let minimum = NSSize(width: 800, height: 520)
        let removed = NSRect(x: 6000, y: -2000, width: 2000, height: 1600)
        #expect(WindowGeometry.constrained(removed, screens: [screen], minimumSize: minimum) == screen)
        let tiny = NSRect(x: 200, y: 200, width: 20, height: 20)
        #expect(WindowGeometry.constrained(tiny, screens: [screen], minimumSize: minimum)
                == NSRect(x: 200, y: 200, width: 800, height: 520))
        #expect(WindowGeometry.constrained(tiny, screens: [], minimumSize: minimum) == tiny)
    }

    @Test func invalidOrIncompleteFramesDoNotBecomeNativeGeometry() {
        let records: [Any] = ["frame", ["x": 0.0],
                              ["x": 0.0, "y": 0, "width": -1, "height": 650],
                              ["x": Double.infinity, "y": 0, "width": 1100, "height": 650],
                              ["x": 0.0, "y": 0, "width": Double.nan, "height": 650],
                              ["x": Double.greatestFiniteMagnitude, "y": 0, "width": Double.greatestFiniteMagnitude, "height": 650]]
        for record in records { #expect(WindowGeometry.decode(record) == nil) }
    }

    @Test func nativeMinimumsCannotPushRestorationOutsideTheVisibleScreen() {
        let screen = NSRect(x: 0, y: 63, width: 1024, height: 674)
        let frame = NSRect(x: 30, y: 93, width: 900, height: 600)
        let minimum = NSSize(width: 1000, height: 700)
        #expect(WindowGeometry.constrained(frame, screens: [screen], minimumSize: minimum)
                == NSRect(x: 24, y: 63, width: 1000, height: 674))
    }
}
