import AppKit

struct EditorLines {
    let starts: [Int]

    init(_ text: String) {
        let text = text as NSString
        var starts = [0]
        var offset = 0
        while offset < text.length {
            var end = 0
            var contentEnd = 0
            text.getLineStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: offset, length: 0))
            if contentEnd < end { starts.append(end) }
            offset = end
        }
        self.starts = starts
    }

    func number(at offset: Int) -> Int {
        var lower = 0
        var upper = starts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if starts[middle] <= offset { lower = middle + 1 } else { upper = middle }
        }
        return max(1, lower)
    }
}

@MainActor final class EditorLineNumberRuler: NSRulerView {
    struct Label {
        let number: Int
        let baseline: CGFloat
    }

    private var lines = EditorLines("")
    private var font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = scrollView.documentView
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
        clipsToBounds = true
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Line numbers")
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    func update(textChanged: Bool) {
        guard let editor = clientView as? NSTextView else { return }
        if textChanged { lines = EditorLines(editor.string) }
        setAccessibilityValue("\(lines.starts.count) \(lines.starts.count == 1 ? "line" : "lines")")
        font = editor.font ?? font
        let width = ceil((String(max(99, lines.starts.count)) as NSString).size(withAttributes: [.font: font]).width) + 16
        if ruleThickness != width { ruleThickness = width }
        needsDisplay = true
    }

    /// Use laid-out viewport fragments without forcing layout of the entire document.
    func labels() -> [Label] {
        guard let editor = clientView as? NSTextView, let layout = editor.textLayoutManager,
              let content = layout.textContentManager else { return [] }
        let visible = editor.visibleRect
        var labels: [Label] = []
        let start = layout.textViewportLayoutController.viewportRange?.location
        layout.enumerateTextLayoutFragments(from: start, options: [.ensuresExtraLineFragment]) { fragment in
            let origin = fragment.layoutFragmentFrame.origin.y + editor.textContainerOrigin.y
            if origin > visible.maxY { return false }
            let offset = content.offset(from: content.documentRange.location, to: fragment.rangeInElement.location)
            for line in fragment.textLineFragments {
                let location = offset + line.characterRange.location
                let number = lines.number(at: location)
                guard lines.starts[number - 1] == location else { continue }
                let bounds = line.typographicBounds.offsetBy(dx: 0, dy: origin)
                guard bounds.maxY >= visible.minY, bounds.minY <= visible.maxY else { continue }
                let baseline = origin + line.typographicBounds.minY + line.glyphOrigin.y
                labels.append(Label(number: number, baseline: convert(NSPoint(x: 0, y: baseline), from: editor).y))
            }
            return true
        }
        return labels
    }

    override func draw(_ dirtyRect: NSRect) {
        AppColours.paper.setFill()
        bounds.fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        for label in labels() {
            let text = String(label.number) as NSString
            text.draw(at: NSPoint(x: bounds.maxX - 8 - text.size(withAttributes: attributes).width,
                                 y: label.baseline - font.ascender), withAttributes: attributes)
        }
        AppColours.divider.setFill()
        NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @objc private func scrolled() { needsDisplay = true }
}
