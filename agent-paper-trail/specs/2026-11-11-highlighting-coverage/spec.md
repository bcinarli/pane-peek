---
status: Proposed
date: 2026-11-11
supersedes: []
superseded_by: ""
---

# Highlighting coverage specification

## Scope

Extend [A15](../001-mvp/spec.md#details-sidebar-and-preview-editor) Preview, Edit and draft recolouring with the inventory below. It completes the configuration candidates in [#144](https://github.com/bcinarli/pane-peek/issues/144), adds missing aliases for supported languages and adds Kotlin, Ruby and Objective-C. The closed #133 inventory and the scanner-helper work in [#143](https://github.com/bcinarli/pane-peek/issues/143) keep their own records; #143 reviews must include the scanners added here.

Detection uses filenames only and keeps the existing precedence: exact basenames, folded names, prefixes, then case-insensitive extensions. Unknown names, including unlisted `rc`/`conf` names, remain plain text. Source text stays inert: no configuration loading, environment change, version selection, history application, interpolation or execution. Highlighting is lexical presentation, not validation. No new token kinds or colours are added.

Excluded: language services, semantic analysis, content sniffing, MATLAB, `.h` reclassification, fish, MDX, `.node-version` and other formats not listed here.

## Aliases for supported formats

Register these names with the existing tokenizers. Exact basenames are case-sensitive, like the existing dotfile rules.

| Names or extensions | Existing treatment | Format reference |
| --- | --- | --- |
| `.pyi`, `.pyw` | Python | [Stub files](https://typing.python.org/en/latest/spec/distributing.html#stub-files) |
| `.markdown`, `.mdown`, `.mkd`, `.mkdn` | Markdown source highlighting and rendered Preview | [CommonMark](https://spec.commonmark.org/) |
| `.ksh`, `.bash_aliases` | Shell; Korn-specific constructs stay plain where the shell lexer does not recognise them | [ksh](https://github.com/ksh93/ksh) |
| `.gitmodules` | Git configuration, including quoted `submodule` subsections | [Git modules](https://git-scm.com/docs/gitmodules) |
| `.ignore`, `.rgignore`, `.fdignore` | Git-ignore patterns | [ripgrep](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#automatic-filtering), [fd](https://github.com/sharkdp/fd#excluding-specific-files-or-directories) |

## Configuration formats

| Names | Lexical treatment | Format reference |
| --- | --- | --- |
| `.dockerignore` | A Docker dialect of ignore highlighting. A hash in column one starts a comment. Leading and trailing whitespace stays outside the pattern, a leading `!` is an exception marker, and escaped trailing spaces receive no Git-specific treatment. | [Docker ignores](https://docs.docker.com/build/concepts/context/#dockerignore-files) |
| `.env`, `.env.<name>` | Dotenv keys, an optional `export` prefix, `=` separators, unquoted values, single-, double- and backtick-quoted values including multiline double quotes, and hash comments outside quotes. `${NAME}` stays value text. `.env.<name>` applies only when `<name>` has no known extension, so `.env.json` stays JSON. | [Node dotenv](https://nodejs.org/api/environment_variables.html#dotenv-files) |
| `.ruby-version` | The first whitespace-delimited word is the version literal; the rest of the file stays plain. | [rbenv](https://github.com/rbenv/rbenv#choosing-the-ruby-version) |
| `.python-version` | Each line's whitespace-delimited version words are literals. Comment handling follows the pyenv reader as verified in its unit. | [pyenv](https://github.com/pyenv/pyenv#understanding-python-version-selection) |
| `.tool-versions` | Per line, a tool name key followed by version literals, including `ref:`, `path:` and `system` values, with hash comments. | [asdf](https://asdf-vm.com/manage/configuration.html#tool-versions) |
| `.vimrc`, `.gvimrc`, `.vim` | Vimscript commands and keywords, option names after `:set` forms, scoped variables such as `g:name` as references, single- and double-quoted strings, numbers, line continuations and `"` comments. A leading `vim9script` command switches comments to `#`. Mappings and key notation stay literal text; nothing is sourced. | [Vim configuration](https://vimhelp.org/usr_05.txt.html), [Vim script](https://vimhelp.org/eval.txt.html) |
| `.tmux.conf`, `tmux.conf` | Command names, flags, option names, single- and double-quoted strings, `#{…}` formats as references, numbers, `%if`/`%endif` directives, braces, line continuations and hash comments outside quotes. | [tmux configuration](https://github.com/tmux/tmux/wiki/Getting-Started#configuration-file) |

## Languages

| Names or extensions | Lexical treatment | Format reference |
| --- | --- | --- |
| `.kt`, `.kts` | Hard, soft and modifier keywords, literals such as `true`, `false` and `null`, character literals, single-line and raw triple-quoted strings with `$name` and `${…}` templates as references, numbers with underscores, hexadecimal/binary forms and suffixes, annotations, and line and nested block comments. | [Kotlin grammar](https://kotlinlang.org/docs/reference/grammar.html) |
| `.rb`, `.rake`, `.gemspec`, `.ru`; `Gemfile`, `Rakefile`, `Podfile`, `Brewfile`, `Vagrantfile` | Keywords, `nil`/`true`/`false`/`self`, symbols, single- and double-quoted strings with `#{…}` interpolation, percent literals, heredocs including `<<~` and `<<-`, regular expression literals where an operand is expected, instance, class and global variables as references, numbers, `#` comments and `=begin`/`=end` blocks. `.gemrc` remains YAML and `Gemfile.lock` remains plain. | [Ruby syntax](https://docs.ruby-lang.org/en/master/syntax_rdoc.html) |
| `.m`, `.mm` | A C-family dialect adding `@` directives such as `@interface` and `@property`, `@"…"` strings, `@[`, `@{` and `@(` literal openers, `YES`, `NO`, `nil` and `Nil`, and `#import`. `.mm` keeps C++ keywords. `.h` remains C-family because the filename cannot distinguish the dialects; `.m` is not treated as MATLAB. | [Objective-C](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/) |

## Shared contract

Each format produces ordered, non-overlapping UTF-16 ranges for complete files, incomplete drafts and Unicode source, keeps the loaded format through typing and Preview/Edit changes, stays cancellable on the existing background path and preserves source bytes, BOMs and line endings through native Undo and Save. Keep detection, grammar registration and scanning separate; reuse an existing tokenizer only where its lexical contract fits, and keep new tokenizers focused rather than adding exceptions to a general scanner.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| H1 | Python, Markdown, shell, Git modules and ripgrep/fd ignore aliases use their existing treatment; precedence, case rules and plain-text fallback are unchanged. |
| H2 | `.dockerignore` highlights Docker comments, exception markers and trimmed patterns without Git-specific escape handling. |
| H3 | `.ruby-version`, `.python-version` and `.tool-versions` highlight their documented version records individually. |
| H4 | `.env` and scoped `.env.<name>` files highlight dotenv keys, prefixes, values, quotes and comments without overriding known extensions. |
| H5 | Kotlin files highlight keywords, literals, strings, templates, numbers, annotations and nested comments. |
| H6 | Ruby files and conventional Ruby filenames highlight keywords, symbols, strings, interpolation, percent literals, heredocs, regular expressions, variables and comments. |
| H7 | Objective-C and Objective-C++ files highlight `@` directives and literals over the C-family treatment; `.h` is unchanged. |
| H8 | Vimscript and tmux configuration files highlight their documented commands, options, strings, references and comments, with `vim9script` comment handling. |
| H9 | Every addition satisfies the shared contract, stays inert and has measured opening, editing, highlighting, resource and bundle-size impact against the previous accepted unit. |

[Validation](validation.md) owns verdicts; accepted scope does not establish implementation or native acceptance.
