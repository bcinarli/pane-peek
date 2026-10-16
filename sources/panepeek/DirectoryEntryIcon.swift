import SwiftUI
import UniformTypeIdentifiers
import PanePeekCore

enum DirectoryEntryIcon: String {
    case symbolicLink = "link"
    case package = "shippingbox"
    case directory = "icon-folder"
    case sourceCode = "icon-file-code"
    case configuration = "icon-file-cog"
    case image = "icon-file-image"
    case video = "icon-file-video-camera"
    case audio = "icon-file-music"
    case archive = "icon-file-archive"
    case spreadsheet = "icon-file-spreadsheet"
    case document = "icon-file-type"
    case text = "icon-file-text"
    case file = "icon-file"

    init(_ entry: DirectoryEntry) {
        if entry.isSymbolicLink { self = .symbolicLink; return }
        if entry.isPackage { self = .package; return }
        if entry.isDirectory { self = .directory; return }

        let name = entry.name.lowercased()
        let fileExtension = entry.url.pathExtension.lowercased()
        if Self.configurationNames.contains(name) || name.hasPrefix(".env.")
            || Self.configurationExtensions.contains(fileExtension) {
            self = .configuration
            return
        }
        if Self.sourceNames.contains(name) || name.hasPrefix("dockerfile.") || name.hasPrefix("makefile.")
            || Self.sourceExtensions.contains(fileExtension) {
            self = .sourceCode
            return
        }
        if ["readme", "license", "licence", "copying", "notice", "authors", "changelog"].contains(name) {
            self = .text
            return
        }
        if ["csv", "tsv", "xls", "xlsx", "ods", "numbers"].contains(fileExtension) {
            self = .spreadsheet
            return
        }
        if ["pdf", "doc", "docx", "odt", "pages", "ppt", "pptx", "odp", "key"].contains(fileExtension) {
            self = .document
            return
        }
        guard let type = UTType(filenameExtension: fileExtension) else { self = .file; return }
        if type.conforms(to: .image) { self = .image }
        else if type.conforms(to: .movie) || type.conforms(to: .video) { self = .video }
        else if type.conforms(to: .audio) { self = .audio }
        else if type.conforms(to: .archive) { self = .archive }
        else if type.conforms(to: .spreadsheet) { self = .spreadsheet }
        else if type.conforms(to: .pdf) { self = .document }
        else if type.conforms(to: .sourceCode) { self = .sourceCode }
        else if type.conforms(to: .text) { self = .text }
        else { self = .file }
    }

    private static let configurationNames: Set<String> = [
        ".env", ".gitignore", ".gitattributes", ".gitmodules", ".editorconfig", ".npmrc", ".nvmrc",
        "package.resolved", "go.mod", "go.sum"
    ]
    private static let configurationExtensions: Set<String> = [
        "json", "jsonc", "yaml", "yml", "toml", "ini", "cfg", "conf", "config", "plist", "properties", "xcconfig", "lock"
    ]
    private static let sourceNames: Set<String> = [
        "dockerfile", "makefile", "gnumakefile", ".profile", ".bashrc", ".bash_profile", ".bash_login", ".bash_logout",
        ".zshrc", ".zshenv", ".zprofile", ".zlogin", ".zlogout"
    ]
    private static let sourceExtensions: Set<String> = [
        "swift", "js", "mjs", "cjs", "ts", "mts", "cts", "jsx", "tsx", "py", "html", "htm", "xml", "css", "scss",
        "php", "go", "rs", "java", "sh", "bash", "zsh", "sql", "c", "h", "cc", "cpp", "cxx", "c++", "hh", "hpp",
        "hxx", "h++", "cs", "mk", "mak", "rb", "kt", "kts", "lua", "dart", "vue", "svelte"
    ]

    var image: Image {
        switch self {
        case .symbolicLink, .package: Image(systemName: rawValue)
        default: Image(rawValue)
        }
    }
}
