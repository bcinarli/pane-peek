enum SyntaxGrammarCatalogue {
    typealias Tokenizer = @Sendable (String) throws -> [SyntaxToken]

    // Register callables without initialising unused lexers.
    static let tokenizers: [SyntaxLanguage: Tokenizer] = [
        .swift: { try SwiftJSONHighlighting.tokens(in: $0, swift: true) },
        .json: { try SwiftJSONHighlighting.tokens(in: $0, swift: false) },
        .jsonc: { try JSONConfigurationHighlighting.tokens(in: $0, json5: false) },
        .json5: { try JSONConfigurationHighlighting.tokens(in: $0, json5: true) },
        .yaml: { try ConfigurationHighlighting.tokens(in: $0, yaml: true) },
        .yamlWithComments: { try ConfigurationHighlighting.tokens(in: $0, yaml: true, jsonComments: true) },
        .toml: { try ConfigurationHighlighting.tokens(in: $0, yaml: false) },
        .javascript: { try JavaScriptHighlighting.tokens(in: $0, typescript: false, jsx: false) },
        .typescript: { try JavaScriptHighlighting.tokens(in: $0, typescript: true, jsx: false) },
        .jsx: { try JavaScriptHighlighting.tokens(in: $0, typescript: false, jsx: true) },
        .tsx: { try JavaScriptHighlighting.tokens(in: $0, typescript: true, jsx: true) },
        .html: { try MarkupHighlighting.tokens(in: $0, html: true) },
        .xml: { try MarkupHighlighting.tokens(in: $0, html: false) },
        .css: { try StyleHighlighting.tokens(in: $0, scss: false) },
        .scss: { try StyleHighlighting.tokens(in: $0, scss: true) },
        .php: { try PHPHighlighting.tokens(in: $0) },
        .go: { try GoHighlighting.tokens(in: $0) },
        .rust: { try RustHighlighting.tokens(in: $0) },
        .java: { try JavaHighlighting.tokens(in: $0) },
        .python: { try PythonHighlighting.tokens(in: $0) },
        .markdown: { try MarkdownHighlighting.tokens(in: $0) },
        .shell: { try ShellHighlighting.tokens(in: $0) },
        .sql: { try SQLHighlighting.tokens(in: $0) },
        .cFamily: { try CFamilyHighlighting.tokens(in: $0) },
        .cSharp: { try CSharpHighlighting.tokens(in: $0) },
        .dockerfile: { try DockerfileHighlighting.tokens(in: $0) },
        .makefile: { try MakefileHighlighting.tokens(in: $0) },
        .gitConfig: { try GitConfigurationHighlighting.tokens(in: $0) },
        .editorConfig: { try EditorConfigurationHighlighting.tokens(in: $0) },
        .npmConfig: { try NPMConfigurationHighlighting.tokens(in: $0) },
        .yarnClassic: { try YarnConfigurationHighlighting.tokens(in: $0) },
        .ignorePatterns: { try IgnoreHighlighting.tokens(in: $0) },
        .gitAttributes: { try AttributesHighlighting.tokens(in: $0) },
        .nvmVersion: { try NvmHighlighting.tokens(in: $0) },
        .vimInfo: { try VimInfoHighlighting.tokens(in: $0) }
    ]
}
