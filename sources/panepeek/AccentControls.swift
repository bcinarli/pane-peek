import AppKit
import SwiftUI
import PanePeekCore

struct AccentButton: NSViewRepresentable {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(title: title, action: action) }
    func makeNSView(context: Context) -> NSButton { context.coordinator.button }
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.title = title
        button.isEnabled = isEnabled
        AppColours.styleAccentButton(button)
    }

    @MainActor final class Coordinator: NSObject {
        let button = NSButton()
        var action: () -> Void

        init(title: String, action: @escaping () -> Void) {
            self.action = action
            super.init()
            button.title = title
            button.bezelStyle = .rounded
            button.keyEquivalent = "\r"
            button.keyEquivalentModifierMask = []
            button.target = self
            button.action = #selector(press)
            AppColours.styleAccentButton(button)
        }

        @objc private func press() {
            guard button.isEnabled else { return }
            action()
        }
    }
}

struct TextModeToggle: NSViewRepresentable {
    @Binding var mode: PreviewState.Mode
    var isEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(mode: $mode) }
    func makeNSView(context: Context) -> NSSegmentedControl { context.coordinator.control }
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.update($mode)
        control.isEnabled = isEnabled
    }

    @MainActor final class Coordinator: NSObject {
        let control = NSSegmentedControl()
        private var mode: Binding<PreviewState.Mode>

        init(mode: Binding<PreviewState.Mode>) {
            self.mode = mode
            super.init()
            control.cell = AccentSegmentedCell()
            control.segmentStyle = .rounded
            control.segmentCount = 2
            control.trackingMode = .selectOne
            control.segmentDistribution = .fillEqually
            control.setLabel("Preview", forSegment: 0)
            control.setLabel("Edit", forSegment: 1)
            control.selectedSegmentBezelColor = AppColours.accent
            control.setAccessibilityLabel("Text mode")
            control.target = self
            control.action = #selector(changeMode)
            update(mode)
            control.sizeToFit()
        }

        func update(_ mode: Binding<PreviewState.Mode>) {
            self.mode = mode
            let selected = mode.wrappedValue == .preview ? 0 : 1
            if control.selectedSegment != selected { control.selectedSegment = selected }
        }

        @objc private func changeMode() {
            guard control.isEnabled else { return }
            mode.wrappedValue = control.selectedSegment == 0 ? .preview : .edit
        }
    }
}

private final class AccentSegmentedCell: NSSegmentedCell {
    override func draw(withFrame frame: NSRect, in controlView: NSView) {
        guard !isEnabled, NSApp.isActive, controlView.window?.isKeyWindow == true,
              AppColours.isDark(controlView.effectiveAppearance),
              let appearance = copy() as? NSSegmentedCell else {
            super.draw(withFrame: frame, in: controlView)
            return
        }
        // Draw an enabled copy so the live control stays disabled during the drag.
        appearance.isEnabled = true
        appearance.draw(withFrame: frame, in: controlView)
    }

    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        // The selected bezel stays Mauve while the control is disabled during a drag.
        guard isSelected(forSegment: segment),
              NSApp.isActive, controlView.window?.isKeyWindow == true,
              AppColours.isDark(controlView.effectiveAppearance) else {
            super.drawSegment(segment, inFrame: frame, with: controlView)
            return
        }
        let title = NSAttributedString(string: label(forSegment: segment) ?? "", attributes: [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize)),
            .foregroundColor: AppColours.accentInk
        ])
        let size = title.size()
        title.draw(at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
    }
}
