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
}
