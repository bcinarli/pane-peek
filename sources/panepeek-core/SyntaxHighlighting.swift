import Foundation

/// A presentation-only UTF-16 range for native attributed text.
public struct SyntaxToken: Sendable, Equatable {
    public enum Kind: Sendable { case keyword, string, comment, number, literal, key, section, reference }
    public let range: NSRange
    public let kind: Kind
}

public enum SyntaxHighlighting {
    /// Detect a filename's format and return its lexical presentation tokens.
    public static func tokens(in text: String, fileName: String) async throws -> [SyntaxToken] {
        try await tokens(in: text, language: SyntaxDetection.language(forFileName: fileName))
    }

    /// Return ordered, non-overlapping tokens for supported extensions, leaving other text plain.
    public static func tokens(in text: String, fileExtension: String) async throws -> [SyntaxToken] {
        try await tokens(in: text, language: SyntaxDetection.language(forExtension: fileExtension))
    }

    /// Highlight a retained format without repeating detection or changing source bytes.
    public static func tokens(in text: String, language: SyntaxLanguage) async throws -> [SyntaxToken] {
        try Task.checkCancellation()
        guard language != .plainText, let tokenize = SyntaxGrammarCatalogue.tokenizers[language] else { return [] }
        let worker = Task.detached(priority: .userInitiated) {
            try tokenize(text)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
