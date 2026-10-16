import AppKit
import SwiftUI
import PanePeekCore

struct BrowserLayoutToggle: NSViewRepresentable {
    @Binding var mode: BrowserMode

    func makeCoordinator() -> Coordinator { Coordinator(mode: $mode) }
    func makeNSView(context: Context) -> NSSegmentedControl { context.coordinator.control }
    func updateNSView(_ control: NSSegmentedControl, context: Context) { context.coordinator.update($mode) }

    @MainActor final class Coordinator: NSObject {
        let control = NSSegmentedControl()
        private var mode: Binding<BrowserMode>

        init(mode: Binding<BrowserMode>) {
            self.mode = mode
            super.init()
            control.segmentCount = 2
            control.trackingMode = .selectOne
            control.segmentDistribution = .fillEqually
            for (index, label) in ["One Pane", "Two Panes"].enumerated() {
                control.setLabel(label, forSegment: index)
                control.setImage(NSImage(named: index == 0 ? "icon-square" : "icon-square-split-horizontal"), forSegment: index)
                control.setImageScaling(.scaleProportionallyDown, forSegment: index)
            }
            control.setAccessibilityLabel("Browser layout")
            control.toolTip = "Keep the active browser in One Pane; restore the other on the right in Two Panes"
            control.target = self
            control.action = #selector(changeMode)
            update(mode)
            control.sizeToFit()
        }

        func update(_ mode: Binding<BrowserMode>) {
            self.mode = mode
            let selection = mode.wrappedValue == .onePane ? 0 : 1
            if control.selectedSegment != selection { control.selectedSegment = selection }
        }

        @objc private func changeMode(_ sender: NSSegmentedControl) {
            mode.wrappedValue = sender.selectedSegment == 0 ? .onePane : .twoPanes
        }
    }
}
