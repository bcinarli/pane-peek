---
status: Proposed
date: 2026-11-11
supersedes: []
superseded_by: ""
---

# Highlighting coverage specification

## Scope

Extend [A15](../001-mvp/spec.md#details-sidebar-and-preview-editor) Preview, Edit and draft recolouring for the [#144](https://github.com/bcinarli/pane-peek/issues/144) inventory in reviewed priority order. Aliases for supported formats come first, Docker ignore and dotenv follow, and Kotlin, Ruby and Objective-C remain separate proposed units. Version files, Vimscript and tmux are deferred until a concrete editing need. The closed #133 inventory and the merged [#143](https://github.com/bcinarli/pane-peek/issues/143) scanner primitives keep their own records; new scanners reuse those primitives.

`SyntaxDetection` remains the one owner of filename rules. Detection uses filenames only and keeps the existing precedence: exact basenames, folded names, prefixes, then case-insensitive extensions. Markdown extensions outrank the `Dockerfile.` and `Makefile.` prefixes, so names such as `Makefile.notes.md` take one Markdown decision for rendered Preview and source highlighting. Unknown names, including unlisted `rc`/`conf` names, remain plain text. Source text stays inert: no configuration loading, environment change, version selection, interpolation or execution. Highlighting is lexical presentation, not validation. No new token kinds or colours are added.

Excluded: language services, semantic analysis, content sniffing, `.h` reclassification, fish, MDX, `.node-version` and other formats not listed here.

## Aliases for supported formats

Register these names with the existing tokenizers. Exact basenames are case-sensitive, like the existing dotfile rules.

| Names or extensions | Existing treatment | Format reference |
| --- | --- | --- |
| `.pyi`, `.pyw` | Python | [Stub files](https://typing.python.org/en/latest/spec/distributing.html#stub-files) |
| `.markdown`; `.mdown`, `.mkd`, `.mkdn` as compatibility aliases | Markdown source highlighting and rendered Preview, from the same filename decision | [CommonMark](https://spec.commonmark.org/), [VS Code Markdown aliases](https://github.com/microsoft/vscode/blob/main/extensions/markdown-basics/package.json) |
| `.ksh`, `.bash_aliases` | Basic shell highlighting; Korn-specific constructs stay plain where the shell lexer does not recognise them | [ksh](https://github.com/ksh93/ksh) |
| `.gitmodules` | Git configuration, including quoted `submodule` subsections | [Git modules](https://git-scm.com/docs/gitmodules) |
| `.ignore`, `.rgignore`, `.fdignore` | Git-ignore patterns | [ripgrep](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#automatic-filtering), [fd](https://github.com/sharkdp/fd#excluding-specific-files-or-directories) |

## Configuration follow-ups

| Names | Lexical treatment | Format reference |
| --- | --- | --- |
| `.dockerignore` | A Docker dialect of ignore highlighting using Docker's pattern rules. A hash in column one starts a comment. Leading and trailing whitespace stays outside the pattern, a leading `!` is an exception marker, and escaped trailing spaces receive no Git-specific treatment. | [Docker ignores](https://docs.docker.com/build/concepts/context/#dockerignore-files) |
| `.env`, `.env.<name>` | A named dotenv dialect: keys, an optional `export` prefix, `=` separators, unquoted single-line values, single- and double-quoted values that may span lines, and hash comments outside quotes. `${NAME}` stays value text. `.env.<name>` applies only when `<name>` has no known extension, so `.env.json` stays JSON. | [Node dotenv](https://nodejs.org/api/environment_variables.html#dotenv-files) |

## Proposed languages

Each language is a separate proposed unit with its own scope review before coding.

| Names or extensions | Lexical treatment | Format reference |
| --- | --- | --- |
| `.kt`, `.kts` | Hard, soft and modifier keywords, `true`/`false`/`null`, character literals, single-line and raw triple-quoted strings with `$name` and `${…}` templates as references, numbers with underscores, hexadecimal/binary forms and suffixes, annotations, and line and nested block comments. Gradle Kotlin scripts such as `build.gradle.kts` are the initial use case. | [Kotlin grammar](https://kotlinlang.org/docs/reference/grammar.html), [Gradle Kotlin DSL](https://docs.gradle.org/current/userguide/kotlin_dsl.html) |
| `.rb`, `.rake`, `.gemspec`, `.ru`; `Gemfile`, `Rakefile`, `Podfile`, `Brewfile`, `Vagrantfile` | Keywords, literals, symbols, interpolated and percent strings, heredocs, operand-aware regular expressions, variables as references, numbers and comments. The scanner's maintenance cost is part of its scope review. `.gemrc` remains YAML and `Gemfile.lock` remains plain. | [Ruby syntax](https://docs.ruby-lang.org/en/master/syntax_rdoc.html) |
| `.m`, `.mm` | A C-family dialect adding `@` directives, `@"…"` strings, literal markers and `YES`/`NO`/`nil`. Blocked on a decision for the shared `.m` extension, which MATLAB and other tools also use. `.h` remains C-family. | [Objective-C](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/) |

## Deferred candidates

Revisit these when there is a concrete editing need; each then needs its own scope review.

| Names | Reader-based notes | Format reference |
| --- | --- | --- |
| `.tool-versions` | The clearest version-file case: a tool name followed by versions, including `ref:`, `path:` and `system`, with hash comments. | [asdf](https://asdf-vm.com/manage/configuration.html#tool-versions) |
| `.ruby-version`, `.python-version` | rbenv reads the file's first word; pyenv reads each line's first word and skips lines whose first word starts with `#`. | [rbenv](https://github.com/rbenv/rbenv#choosing-the-ruby-version), [pyenv](https://github.com/pyenv/pyenv#understanding-python-version-selection) |
| `.vimrc`, `.gvimrc`, `.vim` | Vimscript commands, `:set` options, scoped variables, strings and context-dependent `"` comments, with `vim9script` `#` comments. | [Vim configuration](https://vimhelp.org/usr_05.txt.html) |
| `.tmux.conf`, `tmux.conf` | Commands, flags, options, quoted strings, `#{…}` formats, directives and hash comments outside quotes. | [tmux configuration](https://github.com/tmux/tmux/wiki/Getting-Started#configuration-file) |

## Shared contract

Each format produces ordered, non-overlapping UTF-16 ranges for complete files, incomplete drafts and Unicode source, keeps the loaded format through typing and Preview/Edit changes, stays cancellable on the existing background path and preserves source bytes, BOMs and line endings through native Undo and Save. Keep detection, grammar registration and scanning separate; reuse an existing tokenizer only where its lexical contract fits, reuse the shared scanner primitives, and keep new tokenizers focused rather than adding exceptions to a general scanner.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| H1 | Python, Markdown, shell, Git modules and ripgrep/fd ignore aliases use their existing treatment; Markdown names take one decision for Preview and source; precedence, case rules and plain-text fallback are otherwise unchanged. |
| H2 | `.dockerignore` highlights Docker comments, exception markers and trimmed patterns without Git-specific escape handling. |
| H3 | Deferred: version files highlight their documented records individually once a concrete need is reviewed. |
| H4 | `.env` and scoped `.env.<name>` files highlight dotenv keys, prefixes, values, quotes and comments without overriding known extensions. |
| H5 | Kotlin files highlight keywords, literals, strings, templates, numbers, annotations and nested comments. |
| H6 | Ruby files and conventional Ruby filenames highlight keywords, symbols, strings, interpolation, percent literals, heredocs, regular expressions, variables and comments. |
| H7 | After the `.m` decision, Objective-C and Objective-C++ files highlight `@` directives and literals over the C-family treatment; `.h` is unchanged. |
| H8 | Deferred: Vimscript and tmux configuration files highlight their documented syntax once a concrete need is reviewed. |
| H9 | Every addition satisfies the shared contract, stays inert and has measured opening, editing, highlighting, resource and bundle-size impact against the previous accepted unit. |

[Validation](validation.md) owns verdicts; accepted scope does not establish implementation or native acceptance.
