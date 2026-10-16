import AppKit
import SwiftUI
import PanePeekCore

struct DirectoryTable<Row: View>: NSViewRepresentable {
    let browser: BrowserState
    let id: PaneID
    let entries: [DirectoryEntry]
    let selection: Set<URL>
    let renameID: UUID?
    let row: (DirectoryEntry, @escaping () -> Void) -> Row

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView { context.coordinator.scroll }
    func updateNSView(_ scroll: NSScrollView, context: Context) { context.coordinator.update(self) }

    @MainActor final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        let table = DirectoryTableView()
        let scroll = NSScrollView()
        var input: DirectoryTable
        private var syncingSelection = false
        private var interactedItem: URL?
        private var directory: URL
        private var renameItem: URL?
        private var renameError: String?
        private var dragWriters: [Int: URL] = [:]
        private var dragSessionActive = false

        init(_ input: DirectoryTable) {
            self.input = input
            directory = input.browser.pane(input.id).directory
            super.init()
            let column = NSTableColumn(identifier: .init("item"))
            column.resizingMask = .autoresizingMask
            table.addTableColumn(column)
            table.headerView = nil
            table.style = .plain
            table.backgroundColor = .textBackgroundColor
            table.intercellSpacing = .zero
            table.rowHeight = NSFont.preferredFont(forTextStyle: .body).boundingRectForFont.height + 8
            table.allowsMultipleSelection = true
            table.allowsEmptySelection = true
            table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
            table.autoresizingMask = [.width]
            table.dataSource = self
            table.delegate = self
            table.registerForDraggedTypes([.fileURL])
            table.setAccessibilityHelp("Drag selected files to another pane or Finder. Resolve unsaved changes before retrying a drag. Drop local files to copy here; Command requests a move. File context actions offer Copy and Move to Other Pane. Space previews the selection in Quick Look; Escape closes its preview.")
            table.focus = { [weak self] in
                guard let self else { return false }
                return self.input.browser.focus(self.input.id)
            }
            table.prepareInteraction = { [weak self] event in self?.prepareInteraction(event) }
            table.publishSelection = { [weak self] in self?.publishSelection() }
            table.prepareDrag = { [weak self] indexes in self?.prepareDrag(indexes) ?? false }
            table.finishUnusedDrag = { [weak self] in
                guard let self, !self.dragSessionActive else { return }
                self.dragWriters = [:]
                self.input.browser.endDrag()
            }
            table.rename = { [weak self] in
                guard let self else { return }
                Task { await self.input.browser.beginRename(in: self.input.id) }
            }
            table.showItemMenu = { [weak self] in self?.showItemMenu() }
            table.activate = { [weak self] in self?.activate() }
            table.target = self
            table.doubleAction = #selector(doubleClick)
            scroll.documentView = table
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.drawsBackground = true
            scroll.backgroundColor = .textBackgroundColor
            scroll.contentView.drawsBackground = true
            scroll.contentView.backgroundColor = .textBackgroundColor
            update(input)
        }

        func update(_ input: DirectoryTable) {
            let previous = self.input
            self.input = input
            let directoryChanged = directory != input.browser.pane(input.id).directory
            if directoryChanged {
                directory = input.browser.pane(input.id).directory
                interactedItem = nil
            } else {
                interactedItem = SelectionInteraction.reconciledItem(interactedItem, from: previous.entries, to: input.entries)
            }
            if table.numberOfRows != input.entries.count || previous.entries != input.entries {
                syncingSelection = true
                table.reloadData()
                syncingSelection = false
            } else {
                table.enumerateAvailableRowViews { rowView, index in
                    guard input.entries.indices.contains(index),
                          let cell = rowView.view(atColumn: 0) as? DirectoryTableCell<Row> else { return }
                    cell.host.rootView = content(input.entries[index])
                    cell.isEditing = input.browser.renameRequest?.item.url == input.entries[index].url
                }
            }
            // Scrolling can synchronously request rows from the new listing.
            if directoryChanged {
                scroll.layoutSubtreeIfNeeded()
                scroll.contentView.scroll(to: .zero)
            }
            synchronizeSelection()
            let currentRenameItem = input.browser.renameRequest?.pane == input.id
                ? input.browser.renameRequest?.item.url : nil
            let currentError = currentRenameItem == nil ? nil : input.browser.renameError
            if renameItem != currentRenameItem || renameError != currentError {
                let indexes = IndexSet([renameItem, currentRenameItem].compactMap { item in
                    input.entries.firstIndex { $0.url == item }
                })
                renameItem = currentRenameItem
                renameError = currentError
                table.noteHeightOfRows(withIndexesChanged: indexes)
            }
            if previous.renameID != nil, input.renameID == nil, input.browser.focusedPane == input.id {
                DispatchQueue.main.async { [weak table] in
                    guard let table, table.window != nil else { return }
                    table.window?.makeFirstResponder(table)
                }
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { input.entries.count }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
            guard let source = dragWriters[row], input.browser.draggedSources.contains(source) else { return nil }
            return source as NSURL
        }

        private func prepareDrag(_ indexes: IndexSet) -> Bool {
            guard !indexes.isEmpty, indexes.allSatisfy(input.entries.indices.contains) else { return false }
            let nativeSelection = Set(table.selectedRowIndexes.compactMap { input.entries.indices.contains($0) ? input.entries[$0].url : nil })
            if nativeSelection != input.browser.pane(input.id).selectedItems || input.browser.focusedPane != input.id {
                publishSelection()
            }
            let sources = indexes.map { input.entries[$0].url }
            guard let captured = input.browser.beginDrag(in: input.id, items: Set(sources)), Set(captured) == Set(sources) else { return false }
            dragWriters = Dictionary(uniqueKeysWithValues: zip(indexes, captured))
            table.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
            table.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
            return true
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                       willBeginAt screenPoint: NSPoint, forRowIndexes indexes: IndexSet) {
            dragSessionActive = true
            let written = indexes.compactMap { dragWriters[$0] }
            guard written.count == indexes.count, Set(written) == Set(input.browser.draggedSources) else {
                table.setDraggingSourceOperationMask([], forLocal: true)
                table.setDraggingSourceOperationMask([], forLocal: false)
                input.browser.endDrag()
                dragWriters = [:]
                return
            }
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                       endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            dragSessionActive = false
            dragWriters = [:]
            input.browser.endDrag(external: !operation.isEmpty)
        }

        func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo,
                       proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard let sources = FileDrop.sources(from: info.draggingPasteboard),
                  input.browser.canReceiveDrop(into: input.id, sources: sources) else { return [] }
            tableView.setDropRow(-1, dropOperation: .on)
            return FileDrop.operation(allowed: info.draggingSourceOperationMask, modifiers: NSEvent.modifierFlags)
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo,
                       row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard let sources = FileDrop.sources(from: info.draggingPasteboard) else { return false }
            let operation = FileDrop.operation(allowed: info.draggingSourceOperationMask, modifiers: NSEvent.modifierFlags)
            guard operation == .copy || operation == .move else { return false }
            return input.browser.submitDrop(sources, into: input.id, operation: operation == .move ? .move : .copy) != nil
        }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard input.entries.indices.contains(row) else { return nil }
            let entry = input.entries[row]
            let identifier = NSUserInterfaceItemIdentifier("item-cell")
            let cell = table.makeView(withIdentifier: identifier, owner: self) as? DirectoryTableCell<Row>
                ?? DirectoryTableCell(rootView: content(entry))
            cell.identifier = identifier
            cell.host.rootView = content(entry)
            cell.isEditing = input.browser.renameRequest?.item.url == entry.url
            return cell
        }

        private func content(_ entry: DirectoryEntry) -> Row {
            input.row(entry) { [weak table] in
                guard let table else { return }
                table.window?.makeFirstResponder(table)
            }
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            guard input.entries.indices.contains(row) else { return nil }
            let view = MutedSelectionRow()
            view.setAccessibilityLabel(input.entries[row].name)
            return view
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard input.entries.indices.contains(row),
                  input.browser.renameRequest?.item.url == input.entries[row].url else { return table.rowHeight }
            return input.browser.renameError == nil ? max(36, table.rowHeight) : max(70, table.rowHeight)
        }

        func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
            guard input.entries.indices.contains(row) else { return nil }
            return input.entries[row].name
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !syncingSelection, !table.handlingEvent else { return }
            publishSelection()
        }

        private func prepareInteraction(_ event: NSEvent) {
            if event.type == .leftMouseDown {
                let index = table.row(at: table.convert(event.locationInWindow, from: nil))
                interactedItem = input.entries.indices.contains(index) ? input.entries[index].url : nil
            } else if [125, 126].contains(event.keyCode), !event.modifierFlags.contains(.command) {
                interactedItem = SelectionInteraction.keyboardEndpoint(
                    in: input.entries, interactedItem: interactedItem,
                    primaryItem: input.browser.pane(input.id).primaryItemURL, movingUp: event.keyCode == 126
                )
            }
        }

        private func publishSelection() {
            guard !syncingSelection else { return }
            let urls = Set(table.selectedRowIndexes.compactMap { index in
                input.entries.indices.contains(index) ? input.entries[index].url : nil
            })
            let browser = input.browser
            let primary = urls.count == input.entries.count ? browser.pane(input.id).primaryItemURL : interactedItem
            browser.select(urls, in: input.id, focusedItem: primary)
            // A rejected dirty-document transition must immediately retain its native row.
            synchronizeSelection()
        }

        private func synchronizeSelection() {
            let selected = input.browser.pane(input.id).selectedItems
            let indexes = IndexSet(input.entries.indices.filter { selected.contains(input.entries[$0].url) })
            guard indexes != table.selectedRowIndexes else { return }
            syncingSelection = true
            table.selectRowIndexes(indexes, byExtendingSelection: false)
            syncingSelection = false
        }

        private func showItemMenu() {
            guard let item = input.browser.pane(input.id).primaryItemURL,
                  let row = input.entries.firstIndex(where: { $0.url == item }) else { return }
            table.scrollRowToVisible(row)
            guard let cell = table.view(atColumn: 0, row: row, makeIfNecessary: true) else { return }
            itemMenu(in: cell)?.showMenu()
        }

        private func itemMenu(in view: NSView) -> ItemPathContextMenuView? {
            if let menu = view as? ItemPathContextMenuView { return menu }
            for child in view.subviews {
                if let menu = itemMenu(in: child) { return menu }
            }
            return nil
        }

        @objc private func doubleClick() {
            let index = table.clickedRow
            guard input.entries.indices.contains(index), input.browser.pane(input.id).selectedItems == [input.entries[index].url] else { return }
            activate()
        }

        private func activate() {
            let browser = input.browser
            let pane = browser.pane(input.id)
            guard pane.selectedItems.count == 1, let item = pane.primaryItem else { return }
            Task {
                if item.isDirectory { await browser.navigate(to: item.url, in: input.id) }
                else { await browser.beginRename(in: input.id) }
            }
        }
    }
}

final class DirectoryTableView: NSTableView {
    var prepareDrag: (IndexSet) -> Bool = { _ in false }
    var finishUnusedDrag: () -> Void = {}
    override func canDragRows(with rowIndexes: IndexSet, at mouseDownPoint: NSPoint) -> Bool { prepareDrag(rowIndexes) }
    var focus: () -> Bool = { true }
    var prepareInteraction: (NSEvent) -> Void = { _ in }
    var publishSelection: () -> Void = {}
    var showItemMenu: () -> Void = {}
    var rename: () -> Void = {}
    var activate: () -> Void = {}
    private(set) var handlingEvent = false

    override func becomeFirstResponder() -> Bool { focus() && super.becomeFirstResponder() }

    override func mouseDown(with event: NSEvent) {
        guard focus() else { return }
        prepareInteraction(event)
        handlingEvent = true
        super.mouseDown(with: event)
        handlingEvent = false
        publishSelection()
        finishUnusedDrag()
    }

    override func keyDown(with event: NSEvent) {
        let preview = window?.delegate as? QuickLookControlling
        if event.keyCode == 49, event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            if !event.isARepeat { preview?.toggleQuickLook() }
            return
        }
        if event.keyCode == 53, preview?.closeQuickLook() == true { return }
        if event.keyCode == 109, event.modifierFlags.contains(.shift) { showItemMenu(); return }
        if [36, 76].contains(event.keyCode) { rename(); return }
        if event.keyCode == 125, event.modifierFlags.contains(.command) { activate(); return }
        prepareInteraction(event)
        handlingEvent = true
        if event.keyCode == 53 { deselectAll(nil) }
        else { super.keyDown(with: event) }
        handlingEvent = false
        publishSelection()
    }

    override func selectAll(_ sender: Any?) {
        handlingEvent = true
        super.selectAll(sender)
        handlingEvent = false
        publishSelection()
    }
}

private final class DirectoryTableCell<Row: View>: NSTableCellView {
    let host: NSHostingView<Row>
    var isEditing = false

    init(rootView: Row) {
        host = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            host.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            host.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            host.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let event = NSApp.currentEvent
        let contextClick = event?.type == .rightMouseDown || event?.modifierFlags.contains(.control) == true
        return isEditing || contextClick ? super.hitTest(point) : nil
    }
}

final class MutedSelectionRow: NSTableRowView {
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }

    override func drawSelection(in dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 6, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        let fill = isEmphasized ? (NSColor(named: "selection") ?? .selectedContentBackgroundColor)
            : .unemphasizedSelectedContentBackgroundColor
        fill.setFill()
        path.fill()
        let outline = isEmphasized ? (NSColor(named: "accent") ?? .controlAccentColor) : .secondaryLabelColor
        outline.setStroke()
        path.lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 2 : 1
        path.stroke()
    }
}
