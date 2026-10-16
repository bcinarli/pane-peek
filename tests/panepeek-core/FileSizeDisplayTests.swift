import Foundation
import Testing
@testable import PanePeekCore

struct FileSizeDisplayTests {
    @Test(arguments: [(UInt64(0), "0 bytes"), (1, "1 byte"), (1_000, "1 kB"),
                      (1_500_000, "1.5 MB"), (2_000_000_000, "2 GB")])
    func formatsListingSizes(example: (UInt64, String)) {
        #expect(FileSizeDisplay.string(for: example.0, locale: Locale(identifier: "en_US")) == example.1)
    }

    @Test func unknownAndUnrepresentableSizesUseADash() {
        #expect(FileSizeDisplay.string(for: nil) == "-")
        #expect(FileSizeDisplay.string(for: UInt64.max) == "-")
    }
}
