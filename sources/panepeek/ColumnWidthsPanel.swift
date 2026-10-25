import AppKit
import Observation
import PanePeekCore

/// Adjusts the retained native columns of one browser without replacing its document focus.
@MainActor final class ColumnWidthsPanel: NSPanel, NSTextFieldDelegate {
    private weak var table: DirectoryTableView?
    private var fields: [NSTextField] = []
    private var steppers: [NSStepper] = []
    private let heading = NSTextField(labelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let number = NumberFormatter()
    private var closing = false

    static func show(in window: NSWindow?, browser: BrowserState) {
        func target(in view: NSView) -> DirectoryTableView? {
            if let table = view as? DirectoryTableView, table.browser === browser, table.paneID == browser.focusedPane { return table }
            return view.subviews.lazy.compactMap { target(in: $0) }.first
        }
        guard let content = window?.contentView else { return }
        target(in: content)?.showColumnWidths(nil)
    }

    init(table: DirectoryTableView) {
        self.table = table
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 250),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Column Widths"
        isReleasedWhenClosed = false
        isRestorable = false
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        backgroundColor = AppColours.floating
        number.numberStyle = .decimal
        number.usesGroupingSeparator = false
        number.maximumFractionDigits = 1
        number.isLenient = false

        heading.font = .preferredFont(forTextStyle: .headline)
        let font = NSFont.preferredFont(forTextStyle: .body)
        let rows: [[NSView]] = table.tableColumns.enumerated().map { index, column in
            let name = column.headerCell.stringValue
            let label = NSTextField(labelWithString: name)
            label.font = font
            let field = NSTextField()
            field.tag = index
            field.font = font
            field.alignment = .right
            field.delegate = self
            field.target = self
            field.action = #selector(changeWidth(_:))
            field.setAccessibilityLabel("\(name) column width")
            field.setAccessibilityHelp("Width in points. Minimum \(Int(column.minWidth)) points. Return applies the width.")
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: max(90, font.pointSize * 7)).isActive = true
            let stepper = NSStepper()
            stepper.tag = index
            stepper.minValue = column.minWidth
            stepper.maxValue = column.maxWidth
            stepper.increment = 10
            stepper.valueWraps = false
            stepper.target = self
            stepper.action = #selector(changeWidth(_:))
            stepper.setAccessibilityLabel("\(name) column width")
            stepper.setAccessibilityHelp("Adjust the width in 10 point steps.")
            let unit = NSTextField(labelWithString: "pt")
            unit.font = font
            unit.setAccessibilityElement(false)
            fields.append(field)
            steppers.append(stepper)
            return [label, field, stepper, unit]
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .leading
        message.font = .preferredFont(forTextStyle: .callout)
        message.setAccessibilityLabel("Width input error")
        message.isHidden = true
        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults(_:)))
        restore.bezelStyle = .rounded
        let done = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        AppColours.styleAccentButton(done)
        let buttons = NSStackView(views: [restore, NSView(), done])
        buttons.orientation = .horizontal
        let stack = NSStackView(views: [heading, grid, message, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            grid.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        var order: [NSView] = []
        for index in fields.indices { order += [fields[index], steppers[index]] }
        order += [restore, done]
        for index in order.indices { order[index].nextKeyView = order[(index + 1) % order.count] }
        initialFirstResponder = fields.first
        NotificationCenter.default.addObserver(self, selector: #selector(synchronize), name: NSTableView.columnDidResizeNotification, object: table)
        synchronize()
        observeLayout()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func present(in owner: NSWindow) {
        closing = false
        message.isHidden = true
        synchronize()
        refreshHeading()
        if parent == nil {
            setFrameOrigin(NSPoint(x: owner.frame.midX - frame.width / 2, y: owner.frame.midY - frame.height / 2))
            owner.addChildWindow(self, ordered: .above)
        }
        makeKeyAndOrderFront(nil)
    }

    private func observeLayout() {
        withObservationTracking { refreshHeading() } onChange: { [weak self] in
            Task { @MainActor in self?.observeLayout() }
        }
    }

    private func refreshHeading() {
        guard let table, let browser = table.browser else { return }
        heading.stringValue = browser.mode == .onePane ? "Directory pane"
            : (browser.presentationOrder.first == table.paneID ? "Left directory pane" : "Right directory pane")
        fitContent()
    }

    @objc private func synchronize() {
        guard let table else { return }
        for (index, column) in table.tableColumns.enumerated() {
            fields[index].stringValue = number.string(from: NSNumber(value: column.width)) ?? ""
            steppers[index].doubleValue = column.width
        }
    }

    @objc private func changeWidth(_ sender: NSControl) {
        guard !closing, let table, table.window === parent, table.window != nil,
              table.tableColumns.indices.contains(sender.tag) else { return }
        let index = sender.tag
        let value = sender is NSStepper ? sender.doubleValue : number.number(from: fields[index].stringValue)?.doubleValue
        guard let value, value.isFinite, value <= table.tableColumns[index].maxWidth else {
            synchronize()
            message.stringValue = "Enter a valid width in points."
            message.isHidden = false
            fitContent()
            NSAccessibility.post(element: message, notification: .announcementRequested, userInfo: [
                .announcement: message.stringValue, .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ])
            return
        }
        guard value != table.tableColumns[index].width else { return }
        table.tableColumns[index].width = value
        message.isHidden = true
        synchronize()
        fitContent()
        NSAccessibility.post(element: fields[index], notification: .valueChanged)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        changeWidth(field)
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !message.isHidden else { return }
        message.isHidden = true
        fitContent()
    }

    @objc private func restoreDefaults(_ sender: Any?) {
        guard let table, table.window === parent, table.window != nil else { return }
        table.restoreColumnWidths()
        message.isHidden = true
        synchronize()
        fitContent()
    }

    @objc private func done(_ sender: Any?) {
        if let field = firstResponder as? NSTextView, let control = field.delegate as? NSTextField { changeWidth(control) }
        close()
    }

    override func cancelOperation(_ sender: Any?) { close() }

    override func close() {
        guard !closing else { return }
        closing = true
        parent?.removeChildWindow(self)
        super.close()
    }

    private func fitContent() {
        guard let contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        setContentSize(contentView.fittingSize)
    }
}
