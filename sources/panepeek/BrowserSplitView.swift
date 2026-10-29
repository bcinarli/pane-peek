import SwiftUI
import AppKit
import PanePeekCore

/// Own the content split without adding tracking separators to the window toolbar.
struct BrowserSplitView<Left: View, Right: View, Details: View>: NSViewControllerRepresentable {
    let left: Left
    let right: Right
    let details: Details
    let sizing: DetailsSizing
    var visiblePanes: [PaneID] = [.left, .right]
    // Forward observed changes without replacing the hosted browsers or editor.
    let preferredWidth: CGFloat
    let isExpanded: Bool
    var browserProportion: CGFloat = 1

    func makeNSViewController(context: Context) -> Controller {
        Controller(left: left, right: right, details: details, sizing: sizing)
    }

    func updateNSViewController(_ controller: Controller, context: Context) {
        controller.left.rootView = left
        controller.right.rootView = right
        controller.details.rootView = details
        controller.applyLayout(visiblePanes)
        controller.applySizing()
    }

    final class Controller: NSSplitViewController {
        let left: NSHostingController<Left>
        let right: NSHostingController<Right>
        let details: NSHostingController<Details>
        let sizing: DetailsSizing
        private var widthPreference: NSLayoutConstraint!
        private var browserProportion: NSLayoutConstraint!
        private var maximumWidth: NSLayoutConstraint!
        private var leftItem: NSSplitViewItem!
        private var rightItem: NSSplitViewItem!
        private var detailsItem: NSSplitViewItem!
        private var visiblePanes: [PaneID] = [.left, .right]
        private var hiddenScrollPositions: [PaneID: [(NSScrollView, NSPoint)]] = [:]

        init(left: Left, right: Right, details: Details, sizing: DetailsSizing = DetailsSizing()) {
            self.left = NSHostingController(rootView: left)
            self.right = NSHostingController(rootView: right)
            self.details = NSHostingController(rootView: details)
            self.sizing = sizing
            super.init(nibName: nil, bundle: nil)
            self.details.view.identifier = FindResponder.documentContainerIdentifier
            sizing.refreshLayout = { [weak self] in self?.recordLayout() }

            splitView.isVertical = true
            splitView.dividerStyle = .thin
            leftItem = NSSplitViewItem(viewController: self.left)
            rightItem = NSSplitViewItem(viewController: self.right)
            detailsItem = NSSplitViewItem(viewController: self.details)
            // Native limits apply throughout dragging, before SwiftUI lays out again.
            leftItem.minimumThickness = DetailsSizing.browserMinimum
            rightItem.minimumThickness = DetailsSizing.browserMinimum
            detailsItem.minimumThickness = DetailsSizing.detailsMinimum
            addSplitViewItem(leftItem)
            addSplitViewItem(rightItem)
            addSplitViewItem(detailsItem)

            browserProportion = self.left.view.widthAnchor.constraint(equalTo: self.right.view.widthAnchor, multiplier: sizing.browserProportion)
            browserProportion.priority = NSLayoutConstraint.Priority(rawValue: 489)
            widthPreference = self.details.view.widthAnchor.constraint(equalToConstant: sizing.preferredWidth)
            widthPreference.priority = NSLayoutConstraint.Priority(rawValue: 490)
            maximumWidth = self.details.view.widthAnchor.constraint(lessThanOrEqualTo: splitView.widthAnchor,
                multiplier: DetailsSizing.maximumProportion(browserCount: visiblePanes.count))
            NotificationCenter.default.addObserver(self, selector: #selector(willResize(_:)),
                                                   name: NSSplitView.willResizeSubviewsNotification, object: splitView)
            NotificationCenter.default.addObserver(self, selector: #selector(didResize(_:)),
                                                   name: NSSplitView.didResizeSubviewsNotification, object: splitView)
        }

        override func viewWillAppear() {
            super.viewWillAppear()
            browserProportion.isActive = visiblePanes.count == 2
            NSLayoutConstraint.activate([widthPreference, maximumWidth])
        }

        override func viewDidAppear() {
            super.viewDidAppear()
            // Release intrinsic sizing so the native dividers hold their chosen widths.
            left.sizingOptions = [.minSize, .maxSize]
            right.sizingOptions = [.minSize, .maxSize]
            details.sizingOptions = [.minSize, .maxSize]
            applySizing()
        }

        override func viewWillLayout() {
            super.viewWillLayout()
            applySizing()
        }

        override func viewDidLayout() {
            super.viewDidLayout()
            // Expansion follows the resized content bounds.
            applySizing()
            recordLayout()
        }

        func applySizing() {
            let proportion = DetailsSizing.maximumProportion(browserCount: visiblePanes.count)
            if maximumWidth.multiplier != proportion {
                let wasActive = maximumWidth.isActive
                maximumWidth.isActive = false
                maximumWidth = details.view.widthAnchor.constraint(lessThanOrEqualTo: splitView.widthAnchor,
                                                                   multiplier: proportion)
                maximumWidth.isActive = wasActive
            }
            if browserProportion.multiplier != sizing.browserProportion {
                browserProportion.isActive = false
                browserProportion = left.view.widthAnchor.constraint(equalTo: right.view.widthAnchor, multiplier: sizing.browserProportion)
                browserProportion.priority = NSLayoutConstraint.Priority(rawValue: 489)
                browserProportion.isActive = visiblePanes.count == 2
            }
            guard splitView.bounds.width > 0 else { return }
            let requested = sizing.requestedWidth(in: splitView.bounds.width, browserCount: visiblePanes.count)
            if widthPreference.constant != requested {
                widthPreference.constant = requested
            }
        }

        func applyLayout(_ visiblePanes: [PaneID]) {
            guard visiblePanes != self.visiblePanes else { return }
            browserProportion.isActive = false
            self.visiblePanes = visiblePanes
            let items: [NSSplitViewItem] = visiblePanes.map { $0 == .left ? leftItem : rightItem } + [detailsItem]
            var restoredScrollPositions: [(NSScrollView, NSPoint)] = []
            // Detach only hidden browsers. The active host and editor stay in the hierarchy.
            for item in splitViewItems where !items.contains(item) {
                let id: PaneID = item === leftItem ? .left : .right
                hiddenScrollPositions[id] = scrollPositions(in: item.viewController.view)
                if let responder = view.window?.firstResponder as? NSView,
                   responder.isDescendant(of: item.viewController.view) {
                    view.window?.makeFirstResponder(nil)
                }
                removeSplitViewItem(item)
            }
            for (index, item) in items.enumerated() {
                if splitViewItems.indices.contains(index), splitViewItems[index] === item { continue }
                if splitViewItems.contains(item) { removeSplitViewItem(item) }
                insertSplitViewItem(item, at: index)
                if item !== detailsItem {
                    let id: PaneID = item === leftItem ? .left : .right
                    restoredScrollPositions += hiddenScrollPositions.removeValue(forKey: id) ?? []
                }
            }
            browserProportion.isActive = visiblePanes.count == 2
            applySizing()
            // Restore after SwiftUI finishes reattaching and laying out the native list.
            if !restoredScrollPositions.isEmpty {
                let restore = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue,
                                                                false, CFIndex.max) { _, _ in
                    MainActor.assumeIsolated {
                        for (scroll, origin) in restoredScrollPositions where scroll.window != nil {
                            scroll.documentView?.scroll(origin)
                            scroll.reflectScrolledClipView(scroll.contentView)
                        }
                    }
                }
                CFRunLoopAddObserver(CFRunLoopGetMain(), restore, .commonModes)
            }
        }

        private func scrollPositions(in view: NSView) -> [(NSScrollView, NSPoint)] {
            let own = (view as? NSScrollView).map { [($0, $0.contentView.bounds.origin)] } ?? []
            return own + view.subviews.flatMap { scrollPositions(in: $0) }
        }

        private func recordLayout() {
            sizing.recordLayout(contentWidth: splitView.bounds.width, dividerThickness: splitView.dividerThickness,
                                visibleWidth: details.view.frame.width, browserCount: visiblePanes.count)
        }

        @objc private func willResize(_ notification: Notification) {
            guard let divider = userDraggedDivider(notification) else { return }
            if divider == visiblePanes.count - 1 { widthPreference.isActive = false }
            else { browserProportion.isActive = false }
        }

        @objc private func didResize(_ notification: Notification) {
            recordLayout()
            guard let divider = userDraggedDivider(notification) else { return }
            if divider == visiblePanes.count - 1 {
                sizing.setWidthFromUser(details.view.frame.width)
                applySizing()
                widthPreference.isActive = true
            } else {
                guard right.view.frame.width > 0 else { return }
                // Keep the chosen browser division through Details changes and temporary clamping.
                sizing.setBrowserProportion(left.view.frame.width / right.view.frame.width)
                applySizing()
                browserProportion.isActive = visiblePanes.count == 2
            }
        }

        private func userDraggedDivider(_ notification: Notification) -> Int? {
            guard (notification.userInfo?["NSSplitViewUserResizeKey"] as? NSNumber)?.boolValue == true else { return nil }
            return (notification.userInfo?["NSSplitViewDividerIndex"] as? NSNumber)?.intValue
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
