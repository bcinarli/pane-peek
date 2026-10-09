import SwiftUI
import AppKit

/// Own the content split without adding tracking separators to the window toolbar.
struct BrowserSplitView<Left: View, Right: View, Details: View>: NSViewControllerRepresentable {
    let left: Left
    let right: Right
    let details: Details

    func makeNSViewController(context: Context) -> Controller {
        Controller(left: left, right: right, details: details)
    }

    func updateNSViewController(_ controller: Controller, context: Context) {
        controller.left.rootView = left
        controller.right.rootView = right
        controller.details.rootView = details
    }

    final class Controller: NSSplitViewController {
        let left: NSHostingController<Left>
        let right: NSHostingController<Right>
        let details: NSHostingController<Details>
        private var initialSizingConstraints: [NSLayoutConstraint] = []

        init(left: Left, right: Right, details: Details) {
            self.left = NSHostingController(rootView: left)
            self.right = NSHostingController(rootView: right)
            self.details = NSHostingController(rootView: details)
            super.init(nibName: nil, bundle: nil)

            splitView.isVertical = true
            splitView.dividerStyle = .thin
            let leftItem = NSSplitViewItem(viewController: self.left)
            let rightItem = NSSplitViewItem(viewController: self.right)
            let detailsItem = NSSplitViewItem(viewController: self.details)
            // Native limits apply throughout dragging, before SwiftUI lays out again.
            leftItem.minimumThickness = 250
            rightItem.minimumThickness = 250
            detailsItem.minimumThickness = 280
            detailsItem.maximumThickness = 400
            addSplitViewItem(leftItem)
            addSplitViewItem(rightItem)
            addSplitViewItem(detailsItem)

            // Balance the first layout, then leave sizing to the native dividers.
            initialSizingConstraints = [
                self.left.view.widthAnchor.constraint(equalTo: self.right.view.widthAnchor),
                self.details.view.widthAnchor.constraint(equalToConstant: 300)
            ]
            for constraint in initialSizingConstraints {
                constraint.priority = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.defaultLow.rawValue + 1)
            }
        }

        override func viewWillAppear() {
            super.viewWillAppear()
            NSLayoutConstraint.activate(initialSizingConstraints)
        }

        override func viewDidAppear() {
            super.viewDidAppear()
            NSLayoutConstraint.deactivate(initialSizingConstraints)
            initialSizingConstraints.removeAll()
            // Release intrinsic sizing so the native dividers hold their chosen widths.
            left.sizingOptions = [.minSize, .maxSize]
            right.sizingOptions = [.minSize, .maxSize]
            details.sizingOptions = [.minSize, .maxSize]
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
