import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

struct SyntaxDetectionTests {
    @Test(arguments: [
        ("/project/Dockerfile.swift", SyntaxLanguage.dockerfile),
        ("DOCKERFILE.release", .dockerfile), ("build.DOCKERFILE", .dockerfile),
        ("Makefile.json", .makefile), ("GNUmakefile", .makefile), ("rules.MK", .makefile),
        (".bashrc", .shell), (".zshrc", .shell), (".profile", .shell),
        ("sample.MTS", .typescript), ("sample.cts", .typescript),
        ("sample.CJS", .javascript), ("sample.TSX", .tsx), ("sample.jsx", .jsx),
        ("sample.YML", .yaml), ("sample.svg", .xml), ("sample.HTM", .html),
        ("source.h++", .cFamily), ("source.CS", .cSharp),
        (".prettierrc.js", .javascript), (".prettierrc.mts", .typescript),
        (".prettierrc.toml", .toml), (".stylelintrc.yaml", .yaml),
        (".stylelintrc.json", .json), (".eslintrc.yml", .yaml),
        (".eslintrc.json", .jsonc), (".babelrc.json", .json5),
        (".babelrc.cts", .typescript), (".prettierrc.json5", .json5)
    ])
    func namesAndAliasesRetainTheirPrecedence(name: String, expected: SyntaxLanguage) {
        #expect(SyntaxDetection.language(forFileName: name) == expected)
    }

    @Test(arguments: ["DockerfileBackup", "Dockerfile.", "Makefile.", ".BASHRC", "notes.conf", ".customrc", "file.sass", ""])
    func unrelatedNamesRemainPlain(name: String) {
        #expect(SyntaxDetection.language(forFileName: name) == .plainText)
    }

    @Test @MainActor func editingAndModeChangesReuseTheLoadedFormat() async {
        let names = Mutex<[String]>([])
        let state = PreviewState(read: { _ in .text("let value = true") }, detect: { name in
            names.withLock { $0.append(name) }
            return SyntaxDetection.language(forFileName: name)
        })
        let selection = DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/formats/file.swift"), isDirectory: false), listingRevision: UUID())
        await state.load(selection)
        let document = state.documentID
        state.setMode(.edit)
        await state.updateText("var value = false")?.value
        state.setMode(.preview)
        state.setMode(.edit)
        await state.updateText("let value = false // draft")?.value
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/formats/rejected.yaml"), isDirectory: false), listingRevision: UUID()))
        #expect(state.documentID == document && state.isDirty)
        #expect(state.selection == selection && state.text == "let value = false // draft")
        #expect(state.tokens.contains { $0.kind == .comment })
        await state.discardChanges()?.value
        await state.load(selection)
        #expect(names.withLock { $0 } == ["file.swift"])
        #expect(state.text == "let value = true" && !state.isDirty)
        await state.load(nil)
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/formats/file.yaml"), isDirectory: false), listingRevision: UUID()))
        #expect(names.withLock { $0 } == ["file.swift", "file.yaml"])
    }
}
