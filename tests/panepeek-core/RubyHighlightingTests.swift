import Foundation
import Testing
@testable import PanePeekCore

struct RubyHighlightingTests {
    @Test(arguments: ["app.rb", "tasks.RAKE", "gem.gemspec", "config.ru", "Gemfile", "Rakefile", "Podfile", "Brewfile", "Vagrantfile", "/project/Gemfile"])
    func rubyNamesReachTheRubyScanner(name: String) async throws {
        #expect(SyntaxDetection.language(forFileName: name) == .ruby)
        let text = "gem \"rails\", \"~> #{version}\" # pinned"
        #expect(try await SyntaxHighlighting.tokens(in: text, fileName: name) == (try RubyHighlighting.tokens(in: text)))
    }

    @Test(arguments: [("Gemfile.lock", SyntaxLanguage.plainText), (".gemrc", .yaml), ("gemfile", .plainText), ("Podfile.lock", .plainText)])
    func rubyLookalikesKeepTheirTreatment(name: String, expected: SyntaxLanguage) {
        #expect(SyntaxDetection.language(forFileName: name) == expected)
    }

    @Test func keywordsLiteralsAndMemberNamesKeepTheirBoundaries() throws {
        let text = "module Tools\n  class Greeter < Base\n    def greet(name)\n      return nil unless name and not name.empty?\n      yield self if block_given? || true\n    end\n  end\nend\nobj.class.end; raise Error; defined?(x); __method__; endless false\ndef end; def self.class; end"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.keyword, tokens, text) == ["module", "class", "def", "return", "unless", "and", "not", "yield", "if", "end", "end", "end", "defined?", "__method__", "def", "def", "end"])
        #expect(rubyParts(.literal, tokens, text) == ["nil", "self", "true", "false", "self"])
        rubyRanges(tokens, text)
    }

    @Test func symbolsLabelsTernariesAndScopeOperatorsStayDistinct() throws {
        let text = "call(key: 1, if: :sym, :\"quoted #{x}\" => :name?, :[]= => :<=>, :@iv => :$g, :'raw #{y}' => 2)\nflag ? :yes : :no\nflag ? left : right\nflag ? a :b\nflag ? c: d\nFoo::Bar::baz; ::Top; attr_reader :name, :age="
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.key, tokens, text) == ["key:", "if:"])
        #expect(rubyParts(.literal, tokens, text) == [":sym", ":\"quoted ", "\"", ":name?", ":[]=", ":<=>", ":@iv", ":$g", ":'raw #{y}'", ":yes", ":no", ":name", ":age="])
        #expect(rubyParts(.reference, tokens, text) == ["#{x}"])
        #expect(rubyParts(.number, tokens, text) == ["1", "2"])
        #expect(rubyParts(.keyword, tokens, text).isEmpty)
        rubyRanges(tokens, text)
    }

    @Test func quotedStringsInterpolateOnlyInDoubleQuotedForms() throws {
        let text = ##"a = 'it\'s #{not}'; b = "a #{h["c"] + "#{d}"} e"; c = "x #{list.map { |k| "}" }.join} y"; d = "tail #@iv and #$g and #@@cv #notref"; e = `ls #{dir}`; f = "esc \#{no}""##
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.string, tokens, text) == [#"'it\'s #{not}'"#, "\"a ", " e\"", "\"x ", " y\"", "\"tail ", " and ", " and ", " #notref\"", "`ls ", "`", ##""esc \#{no}""##])
        #expect(rubyParts(.reference, tokens, text) == [##"#{h["c"] + "#{d}"}"##, ##"#{list.map { |k| "}" }.join}"##, "#@iv", "#$g", "#@@cv", "#{dir}"])
        #expect(rubyParts(.keyword, tokens, text).isEmpty)
        rubyRanges(tokens, text)
    }

    @Test func percentLiteralsNestBracketsAndModuloStaysAnOperator() throws {
        let text = "a = %w[a [b] c], %i(x y), %q{it {nested} }, %Q<v #{x}>, %(plain #{y}), %r{a/b}im, %s(sym), %x(ls), %|pipe|\nputs %w[p q]\nx = 10 % 3; y = n%2; z %= 4; w = total %2"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.string, tokens, text) == ["%w[a [b] c]", "%q{it {nested} }", "%Q<v ", ">", "%(plain ", ")", "%r{a/b}im", "%x(ls)", "%|pipe|", "%w[p q]"])
        #expect(rubyParts(.literal, tokens, text) == ["%i(x y)", "%s(sym)"])
        #expect(rubyParts(.reference, tokens, text) == ["#{x}", "#{y}"])
        #expect(rubyParts(.number, tokens, text) == ["10", "3", "2", "4", "2"])
        rubyRanges(tokens, text)
    }

    @Test func heredocsStartAfterTheIntroducingLineInOrder() throws {
        let text = "a = <<~SQL, <<-'RAW', <<PLAIN\n  select #{cols}\n  SQLX\n  SQL\nraw #{x}\n    RAW\nplain\n  PLAIN\nPLAIN\nputs <<~\"Q\".strip\n  q\nQ\nitems << value; x <<y; class << self; end\n"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.string, tokens, text) == ["<<~SQL", "<<-'RAW'", "<<PLAIN", "  select ", "\n  SQLX\n  SQL", "raw #{x}\n    RAW", "plain\n  PLAIN\nPLAIN", "<<~\"Q\"", "  q\nQ"])
        #expect(rubyParts(.reference, tokens, text) == ["#{cols}"])
        #expect(rubyParts(.keyword, tokens, text) == ["class", "end"])
        #expect(rubyParts(.literal, tokens, text) == ["self"])
        rubyRanges(tokens, text)
    }

    @Test func regularExpressionsAppearOnlyWhereAnOperandIsExpected() throws {
        let text = "a = b / c / d\nx = /re\\/#{y}z/imx\nif line =~ /^\\s+$/ then end\ncase v when /a/ then split(/,/) end\nputs /ambiguous/\ntotal /2\nfoo.bar / 2\n/start/.match?(s)"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.string, tokens, text) == ["/re\\/", "z/imx", "/^\\s+$/", "/a/", "/,/", "/ambiguous/", "/start/"])
        #expect(rubyParts(.reference, tokens, text) == ["#{y}"])
        #expect(rubyParts(.number, tokens, text) == ["2", "2"])
        #expect(rubyParts(.keyword, tokens, text) == ["if", "then", "end", "case", "when", "then", "end"])
        rubyRanges(tokens, text)
    }

    @Test func commentsAndEmbeddedDocumentsRequireColumnZero() throws {
        let block = "=begin\nblock # comment\n  =end\n=end trailing words"
        let text = "# top\nx = 1 # trailing \"not string\"\n" + block + "\n  =begin\ny = \"#not comment\"\n=begins\nz = 2"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.comment, tokens, text) == ["# top", "# trailing \"not string\"", block])
        #expect(rubyParts(.string, tokens, text) == ["\"#not comment\""])
        #expect(rubyParts(.keyword, tokens, text) == ["begin"])
        #expect(rubyParts(.number, tokens, text) == ["1", "2"])
        rubyRanges(tokens, text)
    }

    @Test func variablesNumbersAndCharacterLiterals() throws {
        let text = "@x = @@count + $stdout.size + $0 + $! + $~ + $1 + $-w\n"
            + "n = [0, 1_000, 0xFF, 0b1010, 0o17, 0755, 0d99, 1.5, 1e10, 2.5E-3, 3r, 2i, 1.5ri, 1__0, 1_, 0b2, 12abc, 1.times, 1..5]\n"
            + "c = ?a; d = x ? 1 : 2; e = ?\\n"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.reference, tokens, text) == ["@x", "@@count", "$stdout", "$0", "$!", "$~", "$1", "$-w"])
        #expect(rubyParts(.number, tokens, text) == ["0", "1_000", "0xFF", "0b1010", "0o17", "0755", "0d99", "1.5", "1e10", "2.5E-3", "3r", "2i", "1.5ri", "1", "1", "5", "1", "2"])
        #expect(rubyParts(.string, tokens, text) == ["?a", "?\\n"])
        rubyRanges(tokens, text)
    }

    @Test func unicodeAndByteOrderMarkKeepUTF16Ranges() throws {
        let text = "\u{FEFF}=begin\nx\n=end\n\"héllo 👀 #{ünïcode}\" # 🚀 note\n:café; { café: 1 }; @ñ = 2; '👀'"
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(rubyParts(.comment, tokens, text) == ["=begin\nx\n=end", "# 🚀 note"])
        #expect(rubyParts(.string, tokens, text) == ["\"héllo 👀 ", "\"", "'👀'"])
        #expect(rubyParts(.reference, tokens, text) == ["#{ünïcode}", "@ñ"])
        #expect(rubyParts(.literal, tokens, text) == [":café"])
        #expect(rubyParts(.key, tokens, text) == ["café:"])
        #expect(rubyParts(.number, tokens, text) == ["1", "2"])
        rubyRanges(tokens, text)
    }

    @Test func incompleteDraftsExtendToTheEndOfText() throws {
        let cases: [(String, SyntaxToken.Kind, String)] = [
            ("x = \"open #{y", .reference, "#{y"),
            ("x = 'open\nmore", .string, "'open\nmore"),
            ("x = %w[a [b]\nc", .string, "%w[a [b]\nc"),
            ("x = <<~EOS\nbody\n  EOSX", .string, "body\n  EOSX"),
            ("=begin\nnever closed", .comment, "=begin\nnever closed"),
            ("x = /open\nregex", .string, "/open\nregex"),
            ("x = :\"open", .literal, ":\"open")
        ]
        for (source, kind, expected) in cases {
            let tokens = try RubyHighlighting.tokens(in: source)
            #expect(rubyParts(kind, tokens, source).last == expected)
            rubyRanges(tokens, source)
        }
        let fragments = ["", "\"", "\"#{", "\"#{\"", "%", "%w", "%q(", "<<~", "<<~'", "<<~A, <<~B\nonly a\nA\n", "=begin", "/", ":", "::", "?", "@", "@@", "$", "$-", "#", "\u{FEFF}", "\r\n=begin\r\nx\r\n=end\r\n"]
        for source in fragments { rubyRanges(try RubyHighlighting.tokens(in: source), source) }
        let deep = String(repeating: "\"#{", count: 200) + "x" + String(repeating: "}\"", count: 200)
        rubyRanges(try RubyHighlighting.tokens(in: deep), deep)
    }

    @Test func largeSourceHasSafeOrderedRanges() throws {
        let line = "def run(x) = x.map { |v| \"#{v}\" } if :ok && @x / 2 # note\n"
        let text = String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count)
        let tokens = try RubyHighlighting.tokens(in: text)
        #expect(tokens.count > 50_000)
        rubyRanges(tokens, text)
    }
}

private func rubyParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func rubyRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
