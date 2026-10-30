import Testing
@testable import PanePeekCore

struct SyntaxScanningTests {
    @Test func decodesScalarsAtTheirUTF16Offsets() {
        let units = Array("aç𐐀👀".utf16)
        for (position, value, width) in [(0, UInt32(0x61), 1), (1, 0xe7, 1), (2, 0x10400, 2), (4, 0x1f440, 2)] {
            let decoded = SyntaxScanning.scalar(in: units, at: position)
            #expect(decoded.value?.value == value)
            #expect(decoded.width == width)
        }
    }

    @Test func decodesLowestAndHighestSurrogatePairs() {
        let lowest = SyntaxScanning.scalar(in: [0xd800, 0xdc00], at: 0)
        #expect(lowest.value?.value == 0x10000)
        #expect(lowest.width == 2)
        let highest = SyntaxScanning.scalar(in: [0xdbff, 0xdfff], at: 0)
        #expect(highest.value?.value == 0x10ffff)
        #expect(highest.width == 2)
    }

    @Test func isolatedSurrogatesConsumeOnlyTheirOwnCodeUnit() {
        let invalid: [[UInt16]] = [[0xd800], [0xdbff, 0x61], [0xdc00, 0xd800], [0xdfff], [0xd800, 0xdbff]]
        for units in invalid {
            let decoded = SyntaxScanning.scalar(in: units, at: 0)
            #expect(decoded.value == nil)
            #expect(decoded.width == 1)
        }
        let following = SyntaxScanning.scalar(in: [0xdbff, 0x61], at: 1)
        #expect(following.value?.value == 0x61)
        #expect(following.width == 1)
    }

    @Test func prefixMatchingUsesExactUTF16OffsetsAndCase() {
        let units = Array("👀Aa/*".utf16)
        #expect(SyntaxScanning.hasPrefix(Array("Aa".utf16), in: units, at: 2))
        #expect(!SyntaxScanning.hasPrefix(Array("aa".utf16), in: units, at: 2))
        #expect(!SyntaxScanning.hasPrefix(Array("Aa".utf16), in: units, at: 1))
        #expect(SyntaxScanning.hasPrefix([47, 42], in: units, at: 4))
    }

    @Test func prefixesRespectEndOfSourceAndEmptyMatches() {
        #expect(SyntaxScanning.hasPrefix([47, 42], in: [47, 42], at: 0))
        #expect(!SyntaxScanning.hasPrefix([47, 42], in: [47], at: 0))
        #expect(!SyntaxScanning.hasPrefix([47], in: [47], at: 1))
        #expect(SyntaxScanning.hasPrefix([], in: [47], at: 1))
        #expect(SyntaxScanning.hasPrefix([], in: [], at: 0))
        #expect(!SyntaxScanning.hasPrefix([], in: [47], at: 2))
    }

    @Test func asciiDigitsRejectUnicodeAndNearBoundaryLookalikes() {
        for unit in "0123456789".utf16 {
            #expect(SyntaxScanning.isASCIIDigit(unit))
            #expect(SyntaxScanning.isASCIIHexDigit(unit))
        }
        for unit in "abcdefABCDEF".utf16 {
            #expect(!SyntaxScanning.isASCIIDigit(unit))
            #expect(SyntaxScanning.isASCIIHexDigit(unit))
        }
        for unit in "/:gG٠０Ｆ".utf16 {
            #expect(!SyntaxScanning.isASCIIDigit(unit))
            #expect(!SyntaxScanning.isASCIIHexDigit(unit))
        }
    }

    @Test func spacingAndLineEndingSetsRemainDistinct() {
        let cases: [(UInt16, Bool, Bool, Bool)] = [
            (9, true, true, false), (32, true, true, false),
            (11, false, true, false), (12, false, true, false),
            (10, false, false, true), (13, false, false, true),
            (0x85, false, false, false), (0xa0, false, false, false),
            (0x2028, false, false, false), (0x2029, false, false, false),
            (0xfeff, false, false, false)
        ]
        for (unit, spaceOrTab, horizontal, newline) in cases {
            #expect(SyntaxScanning.isSpaceOrTab(unit) == spaceOrTab)
            #expect(SyntaxScanning.isASCIIHorizontalWhitespace(unit) == horizontal)
            #expect(SyntaxScanning.isCRorLF(unit) == newline)
        }
    }
}
