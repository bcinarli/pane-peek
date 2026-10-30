import Testing
@testable import PanePeekCore

struct SyntaxGrammarCatalogueTests {
    @Test func everyHighlightedLanguageHasACatalogueEntry() {
        let languages = Set(SyntaxLanguage.allCases).subtracting([.plainText])
        #expect(Set(SyntaxGrammarCatalogue.tokenizers.keys) == languages)
    }
}
