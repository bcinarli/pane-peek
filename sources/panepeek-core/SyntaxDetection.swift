import Foundation

/// A lexical format, independent of the filename used to recognise it.
public enum SyntaxLanguage: Sendable, Hashable, CaseIterable {
    case plainText, swift, json, jsonc, json5, yaml, yamlWithComments, toml, javascript, typescript, jsx, tsx
    case html, xml, css, scss, php, go, rust, java, python, markdown, shell, sql
    case cFamily, cSharp, dockerfile, makefile
}

public enum SyntaxDetection {
    private static let extensions: [String: SyntaxLanguage] = {
        let groups: [(SyntaxLanguage, [String])] = [
            (.swift, ["swift"]), (.json, ["json"]), (.jsonc, ["jsonc"]), (.json5, ["json5"]),
            (.yaml, ["yaml", "yml"]), (.toml, ["toml"]),
            (.javascript, ["js", "mjs", "cjs"]), (.typescript, ["ts", "mts", "cts"]),
            (.jsx, ["jsx"]), (.tsx, ["tsx"]), (.html, ["html", "htm"]), (.xml, ["xml", "svg"]),
            (.css, ["css"]), (.scss, ["scss"]), (.php, ["php"]), (.go, ["go"]), (.rust, ["rs"]),
            (.java, ["java"]), (.python, ["py"]), (.markdown, ["md"]), (.shell, ["sh", "bash", "zsh"]),
            (.sql, ["sql"]), (.cFamily, ["c", "h", "cc", "cpp", "cxx", "c++", "hh", "hpp", "hxx", "h++"]),
            (.cSharp, ["cs"]), (.dockerfile, ["dockerfile"]), (.makefile, ["makefile", "mk", "mak"])
        ]
        return Dictionary(uniqueKeysWithValues: groups.flatMap { language, aliases in aliases.map { ($0, language) } })
    }()

    private static let exactNames: [String: SyntaxLanguage] = {
        var names = Dictionary(uniqueKeysWithValues:
            [".profile", ".bashrc", ".bash_profile", ".bash_login", ".bash_logout", ".zshrc", ".zshenv", ".zprofile", ".zlogin", ".zlogout"].map { ($0, SyntaxLanguage.shell) })
        for name in [".prettierrc", ".stylelintrc", ".gemrc"] { names[name] = .yaml }
        names[".eslintrc"] = .yamlWithComments
        names[".eslintrc.json"] = .jsonc
        for name in [".babelrc", ".babelrc.json", "babel.config.json", ".prettierrc.json5"] { names[name] = .json5 }
        return names
    }()
    private static let foldedNames: [String: SyntaxLanguage] = ["dockerfile": .dockerfile, "makefile": .makefile, "gnumakefile": .makefile]
    private static let prefixes: [(String, SyntaxLanguage)] = [("dockerfile.", .dockerfile), ("makefile.", .makefile)]

    /// Select a supported format from a filename; unknown names remain plain text.
    public static func language(forFileName fileName: String) -> SyntaxLanguage {
        let name = (fileName as NSString).lastPathComponent
        if let language = exactNames[name] { return language }
        let folded = name.lowercased()
        if let language = foldedNames[folded] { return language }
        for (prefix, language) in prefixes where folded.hasPrefix(prefix) && folded != prefix { return language }
        return language(forExtension: (name as NSString).pathExtension)
    }

    /// Resolve a case-insensitive extension, without interpreting source content.
    public static func language(forExtension fileExtension: String) -> SyntaxLanguage {
        extensions[fileExtension.lowercased()] ?? .plainText
    }
}
