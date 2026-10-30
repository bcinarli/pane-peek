enum SyntaxScanning {
    /// Decode at a valid UTF-16 index; an isolated surrogate consumes one unit without a scalar.
    static func scalar(in units: [UInt16], at position: Int) -> (value: Unicode.Scalar?, width: Int) {
        let unit = units[position]
        if (0xd800...0xdbff).contains(unit), position + 1 < units.count,
           (0xdc00...0xdfff).contains(units[position + 1]) {
            let value = 0x10000 + (UInt32(unit) - 0xd800) * 0x400 + UInt32(units[position + 1]) - 0xdc00
            return (Unicode.Scalar(value), 2)
        }
        return (Unicode.Scalar(unit), 1)
    }

    /// Match exact code units from a non-negative source offset.
    static func hasPrefix(_ prefix: [UInt16], in units: [UInt16], at position: Int) -> Bool {
        guard position <= units.count, prefix.count <= units.count - position else { return false }
        return units[position..<(position + prefix.count)].elementsEqual(prefix)
    }

    static func isASCIIDigit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
    static func isASCIIHexDigit(_ unit: UInt16) -> Bool {
        isASCIIDigit(unit) || (65...70).contains(unit) || (97...102).contains(unit)
    }
    static func isCRorLF(_ unit: UInt16) -> Bool { unit == 10 || unit == 13 }
    static func isSpaceOrTab(_ unit: UInt16) -> Bool { unit == 9 || unit == 32 }
    /// The scanners' ASCII spacing set includes vertical tab and form feed, but no line endings.
    static func isASCIIHorizontalWhitespace(_ unit: UInt16) -> Bool { [9, 11, 12, 32].contains(unit) }
}
