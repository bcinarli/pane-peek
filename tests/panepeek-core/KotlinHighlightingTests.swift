import Foundation
import Testing
@testable import PanePeekCore

struct KotlinHighlightingTests {
    @Test(arguments: ["Main.kt", "build.gradle.KTS", "/project/script.kts"])
    func kotlinNamesReachTheKotlinScanner(name: String) async throws {
        #expect(SyntaxDetection.language(forFileName: name) == .kotlin)
        let text = "val greeting = \"Hi, ${name}!\" // note"
        #expect(try await SyntaxHighlighting.tokens(in: text, fileName: name) == (try KotlinHighlighting.tokens(in: text)))
    }

    @Test func hardSoftAndModifierKeywordsKeepIdentifierBoundaries() throws {
        let text = """
        package app.data; import kotlin.math.max
        private data class Point(val x: Int) : Base by impl {
          init { } constructor() : this(0)
          var name: String = ""
            get() = field
            set(value) { field = value }
        }
        fun interface Runner { suspend fun run(): Unit where T : Any }
        value class Id(val value: Int)
        val data = holder.data; obj?.get(); x as? Int; y !is Z; z !in w; Foo::class
        returnç return𐐀 `return` Return 👀return falsehood true false null
        """
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.keyword, tokens, text) == [
            "package", "import", "private", "data", "class", "val", "by", "init", "constructor", "this",
            "var", "get", "field", "set", "field", "fun", "interface", "suspend", "fun", "where",
            "value", "class", "val", "val", "as?", "is", "in", "class", "return"
        ])
        #expect(kotlinParts(.literal, tokens, text) == ["true", "false", "null"])
        #expect(kotlinParts(.string, tokens, text) == ["\"\""])
        kotlinRanges(tokens, text)
    }

    @Test func templatesSplitStringsAndBalanceNestedBracesAndStrings() throws {
        let text = #"val s = "a $name ${user.age + 1} \"q\" \$x // not /* comment"; val t = "${map["k"]} ${ if (ok) { "y" } else "n" }!""#
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.string, tokens, text) == [#""a "#, " ", #" \"q\" \$x // not /* comment""#, "\"", #""k""#, " ", #""y""#, #""n""#, "!\""])
        #expect(kotlinParts(.reference, tokens, text) == ["$name", "${", "}", "${", "}", "${", "}"])
        #expect(kotlinParts(.keyword, tokens, text) == ["val", "val", "if", "else"])
        #expect(kotlinParts(.number, tokens, text) == ["1"])
        #expect(kotlinParts(.comment, tokens, text).isEmpty)
        kotlinRanges(tokens, text)
    }

    @Test func rawStringsKeepEscapesAndCommentsAsTextAndCloseOnTheLastQuote() throws {
        let text = "val r = \"\"\"\n  line \"quoted\" \\n $x ${y}\n  // not comment\n\"\"\"\"; return"
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.string, tokens, text) == ["\"\"\"\n  line \"quoted\" \\n ", " ", "\n  // not comment\n\"\"\"\""])
        #expect(kotlinParts(.reference, tokens, text) == ["$x", "${", "}"])
        #expect(kotlinParts(.keyword, tokens, text) == ["val", "return"])
        #expect(kotlinParts(.comment, tokens, text).isEmpty)
        kotlinRanges(tokens, text)
    }

    @Test func lineCommentsEndAtLineBreaksAndBlockCommentsNest() throws {
        let text = "// return \"x\"\rreturn /* outer /* inner */ return */ val /** doc */ x // tail"
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.comment, tokens, text) == ["// return \"x\"", "/* outer /* inner */ return */", "/** doc */", "// tail"])
        #expect(kotlinParts(.keyword, tokens, text) == ["return", "val"])
        #expect(kotlinParts(.string, tokens, text).isEmpty)
        kotlinRanges(tokens, text)
    }

    @Test func characterLiteralsHandleEscapesAndRecoverAtNewlines() throws {
        let characters = ["'a'", #"'\n'"#, #"'A'"#, #"'\''"#, "'本'", "'😀'", #"'$'"#]
        let text = characters.joined(separator: " ") + " return 'x\nreturn"
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.string, tokens, text) == characters + ["'x"])
        #expect(kotlinParts(.keyword, tokens, text) == ["return", "return"])
        #expect(kotlinParts(.reference, tokens, text).isEmpty)
        kotlinRanges(tokens, text)
    }

    @Test func numberFormsSuffixesAndRangeBoundaries() throws {
        let values = ["0", "42", "1_000_000", "0xFF_EC", "0XAB", "0b1010", "0B1_1", "123L", "0xFFL", "1u", "2U", "3uL", "4UL", "0xFFu", "1.5", ".5", "1.5e10", "1e-3", "2E+4f", "1.5F", "3f", "1_0.0_1"]
        let invalid = ["1_", "0x", "0x_1", "0b2", "1l", "1Lu", "01", "1d", "12abc", "12ç", "1e", "0b1.5"]
        let text = values.joined(separator: ", ") + "; " + invalid.joined(separator: ", ") + "; 1..2; x.toInt(); 1.toString(); a.b2; 0..<10; return"
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.number, tokens, text) == values + ["1", "2", "1", "0", "10"])
        #expect(kotlinParts(.keyword, tokens, text) == ["return"])
        kotlinRanges(tokens, text)
        #expect(kotlinParts(.number, try KotlinHighlighting.tokens(in: ".5"), ".5") == [".5"])
    }

    @Test func annotationsUseSiteTargetsAndLabelsAreReferences() throws {
        let text = #"@Suppress("x") @file:JvmName("N") @get:Rule @kotlin.Deprecated("d") @field : x return@forEach this@Outer.value loop@ for (e in l) break@loop"#
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.reference, tokens, text) == ["@Suppress", "@file:JvmName", "@get:Rule", "@kotlin.Deprecated", "@field", "@forEach", "@Outer", "@loop"])
        #expect(kotlinParts(.keyword, tokens, text) == ["return", "this", "for", "in", "break"])
        #expect(kotlinParts(.string, tokens, text) == [#""x""#, #""N""#, #""d""#])
        kotlinRanges(tokens, text)
    }

    @Test func unicodeTextBomAndShebangKeepUTF16Ranges() throws {
        let text = "val ç = \"👀 $ad🙂 ${'😀'}\" // 💥\nreturn"
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(kotlinParts(.string, tokens, text) == ["\"👀 ", "🙂 ", "'😀'", "\""])
        #expect(kotlinParts(.reference, tokens, text) == ["$ad", "${", "}"])
        #expect(kotlinParts(.comment, tokens, text) == ["// 💥"])
        #expect(kotlinParts(.keyword, tokens, text) == ["val", "return"])
        kotlinRanges(tokens, text)
        let script = "\u{FEFF}#!/usr/bin/env kotlin\nprintln(1) // #!"
        let scriptTokens = try KotlinHighlighting.tokens(in: script)
        #expect(scriptTokens.first?.range == NSRange(location: 1, length: 21))
        #expect(kotlinParts(.comment, scriptTokens, script) == ["#!/usr/bin/env kotlin", "// #!"])
        #expect(kotlinParts(.number, scriptTokens, script) == ["1"])
        kotlinRanges(scriptTokens, script)
    }

    @Test func incompleteDraftsRunToSensibleBoundaries() throws {
        let open = "\"open ${ x\nreturn"
        let openTokens = try KotlinHighlighting.tokens(in: open)
        #expect(kotlinParts(.string, openTokens, open) == ["\"open "])
        #expect(kotlinParts(.reference, openTokens, open) == ["${"])
        #expect(kotlinParts(.keyword, openTokens, open) == ["return"])
        let line = "\"abc\nreturn true"
        let lineTokens = try KotlinHighlighting.tokens(in: line)
        #expect(kotlinParts(.string, lineTokens, line) == ["\"abc"])
        #expect(kotlinParts(.literal, lineTokens, line) == ["true"])
        let comment = "/* a /* b */ return"
        #expect(kotlinParts(.comment, try KotlinHighlighting.tokens(in: comment), comment) == [comment])
        let raw = "\"\"\"abc $"
        #expect(kotlinParts(.string, try KotlinHighlighting.tokens(in: raw), raw) == [raw])
        for source in ["", "\"", "\"${", "\"${ \"inner", "\"\"\"", "/*", "'", "'\\", "@", "@file:", "`ret", "0x", ".", "$", "\"$", "\"\\", "}", "\u{FEFF}", "#!"] {
            kotlinRanges(try KotlinHighlighting.tokens(in: source), source)
        }
    }

    @Test func largeAndDeeplyNestedSourceStaysBounded() throws {
        let line = "val name = \"v $x ${y}\" // note\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        let tokens = try KotlinHighlighting.tokens(in: text)
        #expect(tokens.count > 50_000)
        kotlinRanges(tokens, text)
        for prefix in ["\"", "\"\"\"", "/*", "//"] {
            let long = prefix + String(repeating: "x", count: 100_000)
            let longTokens = try KotlinHighlighting.tokens(in: long)
            #expect(longTokens.count == 1)
            #expect(longTokens.first?.range == NSRange(location: 0, length: long.utf16.count))
        }
        let nested = String(repeating: "\"${", count: 50_000) + String(repeating: "}\"", count: 50_000)
        let nestedTokens = try KotlinHighlighting.tokens(in: nested)
        #expect(kotlinParts(.reference, nestedTokens, nested).count == 100_000)
        kotlinRanges(nestedTokens, nested)
        let comments = String(repeating: "/*", count: 50_000) + String(repeating: "*/", count: 50_000) + " return"
        let commentTokens = try KotlinHighlighting.tokens(in: comments)
        #expect(kotlinParts(.keyword, commentTokens, comments) == ["return"])
        #expect(commentTokens.count == 2)
    }
}

private func kotlinParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func kotlinRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
