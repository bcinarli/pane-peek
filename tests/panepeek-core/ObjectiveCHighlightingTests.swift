import Foundation
import Testing
@testable import PanePeekCore

struct ObjectiveCHighlightingTests {
    @Test(arguments: [("AppDelegate.m", SyntaxLanguage.objectiveC), ("Bridge.MM", .objectiveC), ("AppDelegate.h", .cFamily)])
    func objectiveCNamesReachTheirDialect(name: String, expected: SyntaxLanguage) async throws {
        #expect(SyntaxDetection.language(forFileName: name) == expected)
        let text = "@interface Box : NSObject @property id value; @end // note"
        let dialect = try CFamilyHighlighting.tokens(in: text, objectiveC: expected == .objectiveC)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileName: name) == dialect)
    }

    @Test func directivesAndLanguageTypesAreKeywords() throws {
        let source = "@interface Thing : NSObject <Proto>\n@property (nonatomic) BOOL ready;\n@end\n@implementation Thing\n@synthesize ready = _ready;\n- (instancetype)init { self = [super init]; return self; }\n@end"
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        #expect(objcParts(.keyword, tokens, source) == ["@interface", "@property", "BOOL", "@end", "@implementation", "@synthesize", "instancetype", "self", "super", "return", "self", "@end"])
        objcRanges(tokens, source)

        let directives = ["@protocol", "@optional", "@required", "@class", "@dynamic", "@selector", "@encode", "@try", "@catch", "@finally", "@throw", "@autoreleasepool", "@public", "@private", "@protected", "@package", "@available", "@synchronized", "@import"]
        let list = directives.joined(separator: " ") + " id SEL IMP Class"
        let listTokens = try CFamilyHighlighting.tokens(in: list, objectiveC: true)
        #expect(objcParts(.keyword, listTokens, list) == directives + ["id", "SEL", "IMP", "Class"])
        objcRanges(listTokens, list)
    }

    @Test func atStringsKeepEscapesAndCommentMarkersInside() throws {
        let strings = [#"@"say \"hi\" // not a comment""#, #"@"tab\t\\""#, #""plain""#]
        let source = "NSString *s = " + strings.joined(separator: ", ") + "; // real"
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        #expect(objcParts(.string, tokens, source) == strings)
        #expect(objcParts(.comment, tokens, source) == ["// real"])
        objcRanges(tokens, source)
    }

    @Test func boxedLiteralsAndCollectionOpeners() throws {
        let source = #"NSArray *a = @[@1, @2.5f, @0x1F, @YES]; NSDictionary *d = @{@"k": @(value + 1), @"n": @NO};"#
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        // Boxed numbers mark only their `@`, matching the uncoloured C number path.
        #expect(objcParts(.keyword, tokens, source) == ["@", "@", "@", "@", "@", "@"])
        #expect(objcParts(.number, tokens, source).isEmpty)
        #expect(objcParts(.literal, tokens, source) == ["@YES", "@NO"])
        #expect(objcParts(.string, tokens, source) == [#"@"k""#, #"@"n""#])
        objcRanges(tokens, source)
    }

    @Test func messageSendsImportsAndNilLiterals() throws {
        let source = "#import <Foundation/Foundation.h>\n#import \"Local.h\"\n[obj doThing:@\"x\" with:nil]; if (flag == NO || ok == YES) return Nil;"
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        #expect(objcParts(.reference, tokens, source) == ["#", "import", "#", "import"])
        #expect(objcParts(.string, tokens, source) == ["<Foundation/Foundation.h>", "\"Local.h\"", "@\"x\""])
        #expect(objcParts(.literal, tokens, source) == ["nil", "NO", "YES", "Nil"])
        #expect(objcParts(.keyword, tokens, source) == ["if", "return"])
        objcRanges(tokens, source)
    }

    @Test func objectiveCPlusPlusKeepsCPlusPlusKeywords() throws {
        let source = "template <typename T> class Box { public: static constexpr bool ok = true; }; auto p = nullptr; @interface Box2 @end"
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        #expect(objcParts(.keyword, tokens, source) == ["template", "typename", "class", "public", "static", "constexpr", "bool", "auto", "@interface", "@end"])
        #expect(objcParts(.literal, tokens, source) == ["true", "nullptr"])
        objcRanges(tokens, source)
    }

    @Test func plainCAndCPlusPlusIgnoreObjectiveCSyntax() async throws {
        let source = "#include <vector>\n@interface X @end @\"text\" @[@1] YES NO nil self id BOOL\nint main() { return R\"(raw)\" == 'c'; } // tail"
        let defaultTokens = try CFamilyHighlighting.tokens(in: source)
        #expect(try CFamilyHighlighting.tokens(in: source, objectiveC: false) == defaultTokens)
        #expect(try await SyntaxHighlighting.tokens(in: source, fileExtension: "cpp") == defaultTokens)
        #expect(objcParts(.string, defaultTokens, source) == ["<vector>", "\"text\"", "R\"(raw)\"", "'c'"])
        #expect(objcParts(.keyword, defaultTokens, source) == ["int", "return"])
        #expect(objcParts(.literal, defaultTokens, source).isEmpty)
        #expect(objcParts(.number, defaultTokens, source).isEmpty)
    }

    @Test func unknownAtWordsAndIncompleteDraftsStaySafe() throws {
        let source = "@foo @interfaceX @ interface @\"unterminated\nreturn @\\\nend @"
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        #expect(objcParts(.keyword, tokens, source) == ["return", "@\\\nend"])
        #expect(objcParts(.string, tokens, source) == ["@\"unterminated"])
        objcRanges(tokens, source)
        for text in ["@", "@\"", "@\"\\", "@[", "@(", "@\\\n", "@1e", "@\"" + String(repeating: "x", count: TextPreview.maximumBytes - 2)] {
            let result = try CFamilyHighlighting.tokens(in: text, objectiveC: true)
            objcRanges(result, text)
        }
        let long = "@\"" + String(repeating: "x", count: 10_000)
        #expect(try CFamilyHighlighting.tokens(in: long, objectiveC: true).first?.range == NSRange(location: 0, length: long.utf16.count))
    }

    @Test func unicodeAndEmojiKeepUTF16Ranges() throws {
        let source = "@\"Türkçe 👀\" 👀@end ç @YES 👀"
        let tokens = try CFamilyHighlighting.tokens(in: source, objectiveC: true)
        #expect(objcParts(.string, tokens, source) == ["@\"Türkçe 👀\""])
        #expect(objcParts(.literal, tokens, source) == ["@YES"])
        #expect(tokens.first?.range == NSRange(location: 0, length: "@\"Türkçe 👀\"".utf16.count))
        objcRanges(tokens, source)
    }
}

private func objcParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func objcRanges(_ tokens: [SyntaxToken], _ text: String) {
    let length = text.utf16.count
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
