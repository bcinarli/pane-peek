import Foundation

struct TerminalProfile: Sendable {
    enum Failure: LocalizedError {
        case unsupportedPath, changed
        var errorDescription: String? {
            switch self {
            case .unsupportedPath: "This command location cannot be represented safely in PATH."
            case .changed: "The PanePeek entry in .zprofile was changed or duplicated. It has been left untouched."
            }
        }
    }
    private static let start = "# >>> PanePeek terminal command >>>"
    private static let end = "# <<< PanePeek terminal command <<<"
    private let block: Data

    init(directory: URL) throws {
        guard directory.isFileURL, !directory.path.utf8.contains(where: { [0, 10, 13, 58].contains($0) }) else {
            throw Failure.unsupportedPath
        }
        let quoted = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        block = Data("\n\(Self.start)\nexport PATH=\"${PATH:+$PATH:}\"\(quoted)\n\(Self.end)\n".utf8)
    }

    func installing(in text: String) throws -> String {
        let data = Data(text.utf8)
        if try withoutBlock(data) != nil { return text }
        return text + String(decoding: block, as: UTF8.self)
    }

    func removing(from text: String) throws -> String {
        guard let remainder = try withoutBlock(Data(text.utf8)) else { return text }
        return String(decoding: remainder, as: UTF8.self)
    }

    private func withoutBlock(_ data: Data) throws -> Data? {
        var remainder = data
        let range = data.range(of: block)
        if let range { remainder.removeSubrange(range) }
        guard remainder.range(of: Data(Self.start.utf8)) == nil,
              remainder.range(of: Data(Self.end.utf8)) == nil else { throw Failure.changed }
        return range == nil ? nil : remainder
    }
}
