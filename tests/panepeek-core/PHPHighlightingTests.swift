import Foundation
import Testing
@testable import PanePeekCore

struct PHPHighlightingTests {
    @Test func tagsSeparateCodeFromPlainMarkupAndIdentifierParts() async throws {
        let text = "<?xml version='1.0'?><p>return $plain</p><?PHP\r\nfunction greet($isim) { RETURN 'Türkçe 👀'; } $returning = true; ?> <?= $isim ?> <?phpish echo 1; ?> <? echo 'short'; ?>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "PHP")
        #expect(phpParts(.section, tokens, text) == ["<?PHP", "?>", "<?=", "?>"])
        #expect(phpParts(.keyword, tokens, text) == ["function", "RETURN"])
        #expect(phpParts(.reference, tokens, text) == ["$isim", "$returning", "$isim"])
        #expect(phpParts(.string, tokens, text) == ["'Türkçe 👀'"])
        #expect(phpParts(.literal, tokens, text) == ["true"])
        phpRanges(tokens, text)
    }

    @Test func lineCommentsEndAtClosingTagsAndAttributesAreNotComments() async throws {
        let text = "<?php // echo $fake ?>plain $out <?php # return ?>tail <?php /* ?> /* nested */ #[Example('value')] function f() { return null; }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(phpParts(.comment, tokens, text) == ["// echo $fake ", "# return ", "/* ?> /* nested */"])
        #expect(phpParts(.section, tokens, text) == ["<?php", "?>", "<?php", "?>", "<?php"])
        #expect(phpParts(.keyword, tokens, text).contains("function"))
        #expect(phpParts(.keyword, tokens, text).contains("return"))
        #expect(phpParts(.reference, tokens, text).isEmpty)
        #expect(phpParts(.string, tokens, text) == ["'value'"])
        phpRanges(tokens, text)
    }

    @Test func quotedAndBacktickStringsProtectTagsAndNestedInterpolation() async throws {
        let single = #"'it\'s ?> // $literal'"#
        let double = #""hello {$data["key"]} ${name} \" ?> /* text */ 👀""#
        let command = #"`echo {$data['key']} ?> \` text`"#
        let text = "<?php $a = " + single + "; $b = " + double + "; $c = " + command + "; echo $b; ?>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(phpParts(.string, tokens, text) == [single, double, command])
        #expect(phpParts(.section, tokens, text) == ["<?php", "?>"])
        #expect(phpParts(.comment, tokens, text).isEmpty)
        #expect(phpParts(.reference, tokens, text) == ["$a", "$b", "$c", "$b"])
        #expect(phpParts(.keyword, tokens, text) == ["echo"])
        phpRanges(tokens, text)
    }

    @Test func heredocAndNowdocProtectTheirBodiesAndResumeAfterIndentedMarkers() async throws {
        let heredoc = "<<<TEXT\r\n  quoted \" ?> // $name\r\n  TEXTMORE\r\n  TEXT"
        let nowdoc = "<<<'RAW'\n  'return' $literal ?> /* body */\n  RAW"
        let quoted = "<<<\"END\"\nbody\nEND"
        let text = "<?php $a = " + heredoc + "; $b = " + nowdoc + "; $c = [" + quoted + ", 'tail']; echo $a; ?>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(phpParts(.string, tokens, text) == [heredoc, nowdoc, quoted, "'tail'"])
        #expect(phpParts(.reference, tokens, text) == ["$a", "$b", "$c", "$a"])
        #expect(phpParts(.comment, tokens, text).isEmpty)
        #expect(phpParts(.section, tokens, text) == ["<?php", "?>"])
        #expect(phpParts(.keyword, tokens, text) == ["echo"])
        phpRanges(tokens, text)
    }

    @Test func variablesNamesAndNumericLiteralsKeepWholeBoundaries() async throws {
        let text = "<?php namespace App\\Example; readonly class Example { public function matchValue(): string { $çocuk = $$return; $a = [0xFF, 0b1010, 0o755, 1_000, .5, 1.2e+3, 12abc, 1__0]; return FALSE; } }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(phpParts(.keyword, tokens, text) == ["namespace", "readonly", "class", "public", "function", "string", "return"])
        #expect(phpParts(.reference, tokens, text) == ["$çocuk", "$return", "$a"])
        #expect(phpParts(.number, tokens, text) == ["0xFF", "0b1010", "0o755", "1_000", ".5", "1.2e+3"])
        #expect(phpParts(.literal, tokens, text) == ["FALSE"])
        phpRanges(tokens, text)
    }

    @Test func incompleteUnicodeSourceAndPlainFallbackRemainReadable() async throws {
        for text in ["", "<?php", "<?php $", "<?php $name = 'unfinished 👀", "<?php /* unfinished ?>", "<?php echo \"{$data['unfinished}", "<?php $a = <<<TEXT\nunterminated ?> 👀", "<?php $a = <<<'", "<?php $a = <<<TEXT "] {
            phpRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "php"), text)
        }
        let plain = "return $name; <?php echo 'text'; ?>"
        #expect(try await SyntaxHighlighting.tokens(in: plain, fileExtension: "txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: plain, fileExtension: "sass").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: "return $name;", fileExtension: "php").isEmpty)
    }

    @Test func largeAndDeepSourceHasOrderedBoundedRanges() async throws {
        let line = "$name = 'value'; // comment\n"
        let text = "<?php\n" + String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes - 6))
        #expect(text.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(tokens.count > 50_000)
        phpRanges(tokens, text)
        let deep = "<?php echo " + String(repeating: "\"{$a[", count: 200) + "'key'" + String(repeating: "]}\"", count: 200)
        phpRanges(try await SyntaxHighlighting.tokens(in: deep, fileExtension: "php"), deep)
        let label = String(repeating: "A", count: 100_000)
        let long = "<?php $a = <<<" + label + "\nbody ?>\n" + label + "; return $a;"
        let longTokens = try await SyntaxHighlighting.tokens(in: long, fileExtension: "php")
        #expect(phpParts(.string, longTokens, long).count == 1)
        #expect(phpParts(.keyword, longTokens, long) == ["return"])
        phpRanges(longTokens, long)
        let nestedDocs = "<?php $a = " + String(repeating: "<<<TEXT\n{$data[", count: 100) + "'key'" + String(repeating: "]}\nTEXT", count: 100)
        phpRanges(try await SyntaxHighlighting.tokens(in: nestedDocs, fileExtension: "php"), nestedDocs)
        let invalidNumber = "<?php $a = " + String(repeating: "1", count: 100_000) + "x; return $a;"
        let invalidTokens = try await SyntaxHighlighting.tokens(in: invalidNumber, fileExtension: "php")
        #expect(phpParts(.number, invalidTokens, invalidNumber).isEmpty)
        #expect(phpParts(.keyword, invalidTokens, invalidNumber) == ["return"])
        phpRanges(invalidTokens, invalidNumber)
    }

    @Test func heredocMarkersInsideInterpolationStringsDoNotCloseTheOuterString() async throws {
        let heredoc = "<<<TEXT\n{$data[\"line\nTEXT\nkey\"]}\nTEXT"
        let text = "<?php $a = " + heredoc + "; echo $a; ?>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(phpParts(.string, tokens, text) == [heredoc])
        #expect(phpParts(.reference, tokens, text) == ["$a", "$a"])
        #expect(phpParts(.keyword, tokens, text) == ["echo"])
        #expect(phpParts(.section, tokens, text) == ["<?php", "?>"])
        phpRanges(tokens, text)
        let nowdoc = "<<<'RAW'\n{$data[\"unclosed\nRAW"
        let plain = "<?php $a = " + nowdoc + "; echo $a;"
        let plainTokens = try await SyntaxHighlighting.tokens(in: plain, fileExtension: "php")
        #expect(phpParts(.string, plainTokens, plain) == [nowdoc])
        #expect(phpParts(.keyword, plainTokens, plain) == ["echo"])
        phpRanges(plainTokens, plain)
    }

    @Test func memberAndQualifiedNamesDoNotBecomeKeywordsOrLiterals() async throws {
        let text = "<?php $obj-> /* note */ match('x'); $obj?->return; $obj->true; \\App\\return(); namespace\\match(); echo TRUE;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "php")
        #expect(phpParts(.keyword, tokens, text) == ["echo"])
        #expect(phpParts(.literal, tokens, text) == ["TRUE"])
        #expect(phpParts(.reference, tokens, text) == ["$obj", "$obj", "$obj"])
        #expect(phpParts(.comment, tokens, text) == ["/* note */"])
        phpRanges(tokens, text)
    }
}

private func phpParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func phpRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
