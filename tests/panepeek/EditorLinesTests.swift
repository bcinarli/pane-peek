import Foundation
import Testing
@testable import PanePeek

struct EditorLinesTests {
    @Test func editsPreserveLogicalOffsetsAcrossNewlineBoundaries() {
        let originals = ["", "a\r\nb\nc\r", "\r\n", "\n\n\n", "👀e\u{301}\r\nlast\u{2028}\u{2029}"]
        let replacements = ["", "x", "\n", "\r", "\r\n", "\u{2028}", "\u{2029}", "👀\n"]
        for original in originals {
            let offsets = original.unicodeScalars.indices.map { $0.utf16Offset(in: original) } + [original.utf16.count]
            for start in offsets {
                for end in offsets where end >= start {
                    for replacement in replacements {
                        var lines = EditorLines(original)
                        let text = NSMutableString(string: original)
                        let oldRange = NSRange(location: start, length: end - start)
                        let removed = text.substring(with: oldRange)
                        text.replaceCharacters(in: oldRange, with: replacement)
                        let newRange = NSRange(location: start, length: replacement.utf16.count)
                        let delta = newRange.length - oldRange.length
                        lines.applyEdit(in: text, range: newRange, changeInLength: delta)
                        #expect(lines.starts == EditorLines(text as String).starts,
                                "\(original.debugDescription), \(oldRange), \(replacement.debugDescription)")
                        text.replaceCharacters(in: newRange, with: removed)
                        lines.applyEdit(in: text, range: oldRange, changeInLength: -delta)
                        #expect(lines.starts == EditorLines(original).starts)
                    }
                }
            }
        }
    }
}
