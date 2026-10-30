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
}
