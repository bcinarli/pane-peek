import Foundation
import Testing
@testable import PanePeekCore

struct MakefileHighlightingTests {
    @Test func prerequisiteWordsAndDefineBodyPrefixesStayLiteral() async throws {
        let source = "all: include override export ifdef\nall: private export FLAGS := value\ndefine BODY\noverride literal\noverride define INNER\ntext\nendef\nendef\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.keyword, tokens, source) == ["private", "export", "define", "override", "define", "endef", "endef"])
        #expect(makeParts(.string, tokens, source) == ["override literal", "text"])
        makeRanges(tokens, source)
        let quoted = "VALUE = \"$(subst #,x,$(NAME))\" # comment\nall: ; echo \"$(subst \",x,$(NAME))\" # shell\n"
        let result = try await SyntaxHighlighting.tokens(in: quoted, fileName: "Makefile")
        #expect(makeParts(.string, result, quoted) == ["\"$(subst #,x,$(NAME))\"", "\"$(subst \",x,$(NAME))\""])
        #expect(makeParts(.comment, result, quoted) == ["# comment", "# shell"])
        makeRanges(result, quoted)
    }

    @Test func longTokensNestedReferencesAndPrefixResetStayBounded() async throws {
        for prefix in ["#", "NAME = \"", "NAME = $(", "define BODY\n"] {
            let source = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
            #expect(!tokens.isEmpty && NSMaxRange(tokens.last!.range) == source.utf16.count)
            makeRanges(tokens, source)
        }
        for source in [String(repeating: "x", count: 100_000) + ": input", "NAME = $(" + String(repeating: "(", count: 100_000), "NAME = " + String(repeating: "$", count: 100_000), String(repeating: " ", count: 100_000) + "NAME = value", "all: " + String(repeating: "x", count: 100_000)] {
            makeRanges(try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile"), source)
        }
        let source = ".RECIPEPREFIX = >\nall:\n>echo \"one\"\n.RECIPEPREFIX =\nnext:\n\techo \"two\" # tail\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.string, tokens, source) == ["\"one\"", "\"two\""])
        #expect(makeParts(.section, tokens, source) == ["all", "next"])
        makeRanges(tokens, source)
    }

    @Test func targetsAndAssignmentsHaveDifferentHeaderRoles() async throws {
        let source = "CC := clang\nFLAGS ?= -O2\nCOUNT :::= value\nall Türkçe\\ name: main.o\n%.o: %.c\n.PHONY: all\nall: CFLAGS += -g\nX != echo value\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.section, tokens, source) == ["all", "Türkçe\\ name", "%.o", ".PHONY", "all"])
        #expect(makeParts(.key, tokens, source) == ["CC", "FLAGS", "COUNT", "CFLAGS", "X"])
        makeRanges(tokens, source)
    }

    @Test func directivesNeedWholeWordsOutsideRecipes() async throws {
        let source = "include config.mk\n-include optional.mk\nsinclude extra.mk\noverride export private FLAGS := value\nifdef FLAGS\nelse ifeq (x,y)\nendif\ninclude: input\n\texport FLAGS=value; echo ifdef\nexported = plain\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.keyword, tokens, source) == ["include", "-include", "sinclude", "override", "export", "private", "ifdef", "else", "ifeq", "endif"])
        #expect(makeParts(.section, tokens, source) == ["include"])
        #expect(makeParts(.key, tokens, source) == ["FLAGS", "exported"])
        makeRanges(tokens, source)
    }

    @Test func makeReferencesProtectLiteralHashesAndNestedDelimiters() async throws {
        let nested = "$(subst #,x,$(NAME))"
        let source = "VALUE = " + nested + " ${outer${inner}} $@ $< $x $$HOME $$$$\nall: $(OBJECTS)\n\techo $$HOME $@ $(VALUE)\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.reference, tokens, source) == [nested, "${outer${inner}}", "$@", "$<", "$x", "$(OBJECTS)", "$@", "$(VALUE)"])
        #expect(makeParts(.comment, tokens, source).isEmpty)
        makeRanges(tokens, source)
    }

    @Test func makeCommentsAndRecipeQuotesRespectTheirContexts() async throws {
        let source = "VALUE = \"a# make comment\nESCAPED = a\\#b # tail\nall: ; echo \"# quoted 👀\" word#literal # shell comment\n\techo '$(NAME) # literal' \"unfinished\nnext: input\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.comment, tokens, source) == ["# make comment", "# tail", "# shell comment"])
        #expect(makeParts(.string, tokens, source) == ["\"a", "\"# quoted 👀\"", "'$(NAME) # literal'", "\"unfinished"])
        #expect(makeParts(.section, tokens, source) == ["all", "next"])
        makeRanges(tokens, source)
    }

    @Test func defineBodiesAndLiteralRecipePrefixesKeepTextLiteral() async throws {
        let source = "define MESSAGE\n# literal\nall: literal\ndefine INNER\n$(VALUE)\nendef\n\tendef\nendef\n.RECIPEPREFIX := >\nall:\n>ifdef shell; echo \"value\" # recipe\nnext: input\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.keyword, tokens, source) == ["define", "define", "endef", "endef"])
        #expect(makeParts(.key, tokens, source) == ["MESSAGE", "INNER", ".RECIPEPREFIX"])
        #expect(makeParts(.section, tokens, source) == ["all", "next"])
        #expect(makeParts(.string, tokens, source) == ["# literal", "all: literal", "$(VALUE)", "\tendef", "\"value\""])
        #expect(makeParts(.comment, tokens, source) == ["# recipe"])
        makeRanges(tokens, source)
    }

    @Test func continuationsAndUnfinishedSourceRecoverAtLogicalLines() async throws {
        let source = "# comment \\\r\nall: still comment\r\nVALUE = one \\\n  two # tail\nall:\n\techo \\\ninclude argument\nnext: $(unfinished\nlast: input\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(makeParts(.comment, tokens, source) == ["# comment \\\r\nall: still comment", "# tail"])
        #expect(makeParts(.section, tokens, source) == ["all", "next", "last"])
        #expect(makeParts(.keyword, tokens, source).isEmpty)
        #expect(makeParts(.reference, tokens, source) == ["$(unfinished"])
        makeRanges(tokens, source)
    }

    @Test @MainActor func filenameVariantsAndLargeSourceReachThePreviewPipeline() async throws {
        let source = "# 👀\nNAME := \"value\"\nall: $(NAME)\n\techo $@\n"
        let expected = try await SyntaxHighlighting.tokens(in: source, fileName: "Makefile")
        #expect(!expected.isEmpty)
        for name in ["Makefile", "makefile", "MAKEFILE", "GNUmakefile", "Makefile.dev", "build.Makefile", "rules.mk", "rules.MK", "build.mak", "/preview/Makefile"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileName: name) == expected)
        }
        let state = PreviewState(read: { _ in .text(source) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/Makefile.dev"), isDirectory: false), listingRevision: UUID()))
        #expect(state.preview == .text(source) && state.tokens == expected)
        for name in ["MakefileBackup", "Makefile.", "CMakeLists.txt", "build.ninja", "notes.txt", "file.sass"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileName: name).isEmpty)
        }
        let line = "all: $(NAME)\n\techo \"value\"\n"
        let large = String(String(repeating: line, count: TextPreview.maximumBytes / line.count + 1).prefix(TextPreview.maximumBytes))
        let tokens = try await SyntaxHighlighting.tokens(in: large, fileName: "Makefile")
        #expect(large.utf8.count == TextPreview.maximumBytes && !tokens.isEmpty)
        makeRanges(tokens, large)
        for text in ["", "#", "$", "$(", "NAME = \"", "define NAME\n👀", "all:", "all: ; echo '\\"] {
            makeRanges(try await SyntaxHighlighting.tokens(in: text, fileName: "Makefile"), text)
        }
    }
}

private func makeParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func makeRanges(_ tokens: [SyntaxToken], _ text: String) {
    let length = text.utf16.count
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
