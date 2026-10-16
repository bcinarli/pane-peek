import Foundation
import Testing
import PanePeekCore
@testable import PanePeek

struct DirectoryEntryIconTests {
    @Test func itemIdentityTakesPrecedenceOverAMisleadingFilename() {
        let url = URL(fileURLWithPath: "/icons/photo.png")
        #expect(DirectoryEntryIcon(DirectoryEntry(url: url, isDirectory: true)) == .directory)
        #expect(DirectoryEntryIcon(DirectoryEntry(url: url, isDirectory: false, isPackage: true)) == .package)
        #expect(DirectoryEntryIcon(DirectoryEntry(url: url, isDirectory: true, isSymbolicLink: true)) == .symbolicLink)
        #expect(DirectoryEntryIcon(DirectoryEntry(url: url, isDirectory: false, isPackage: true, isSymbolicLink: true)) == .symbolicLink)
    }

    @Test(arguments: [
        ("main.SWIFT", DirectoryEntryIcon.sourceCode),
        ("component.TSX", .sourceCode),
        ("module.rs", .sourceCode),
        ("query.sql", .sourceCode),
        ("transport.ts", .sourceCode),
        ("settings.JSON", .configuration),
        ("project.yaml", .configuration),
        ("package.toml", .configuration),
        ("photo.HEIC", .image),
        ("artwork.SVG", .image),
        ("recording.MOV", .video),
        ("movie.mp4", .video),
        ("song.FLAC", .audio),
        ("backup.tar.gz", .archive),
        ("archive.zip", .archive),
        ("table.XLSX", .spreadsheet),
        ("data.csv", .spreadsheet),
        ("report.PDF", .document),
        ("letter.docx", .document),
        ("notes.TXT", .text),
        ("readme.md", .text)
    ])
    func recognisedTypesUseTheirCategoryWithoutReadingTheFile(name: String, expected: DirectoryEntryIcon) {
        #expect(icon(name) == expected)
    }

    @Test(arguments: [
        ("Dockerfile", DirectoryEntryIcon.sourceCode),
        ("Dockerfile.debug", .sourceCode),
        ("Makefile", .sourceCode),
        ("GNUmakefile", .sourceCode),
        (".zshrc", .sourceCode),
        (".env", .configuration),
        (".env.local", .configuration),
        (".gitignore", .configuration),
        ("README", .text),
        ("LICENSE", .text),
        ("unknown.panepeek-opaque", .file),
        ("extensionless", .file),
        (".unknown", .file)
    ])
    func extensionlessAndHiddenNamesHaveExplicitCategoriesOrAGenericFallback(name: String, expected: DirectoryEntryIcon) {
        #expect(icon(name) == expected)
    }

    private func icon(_ name: String) -> DirectoryEntryIcon {
        DirectoryEntryIcon(DirectoryEntry(url: URL(fileURLWithPath: "/icons/" + name), isDirectory: false))
    }
}
