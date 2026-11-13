# Highlighting coverage implementation plan

Status: Proposed

The [spec](spec.md) owns behaviour, [tasks](tasks.md) owns execution and [validation](validation.md) owns acceptance. Apply the [shared engineering and review rules](../../engineering-and-review.md) to each atomic unit. Scope acceptance does not authorise coding, commit, push or merge. Present meaningful test evidence and the signed running app for manual acceptance before the next unit.

## Integration

Each unit registers names in `SyntaxDetection`, a tokenizer in `SyntaxGrammarCatalogue` and, where needed, a focused scanner beside the existing ones. Reuse `SyntaxScanning` primitives, the existing cancellation cadence and fixture style. The catalogue completeness test covers every new language ID. Update [usage documentation](../../../docs/usage.md) and the changelog with each unit that changes visible behaviour.

| Unit | Scope | State | Dependencies | Criteria |
| --- | --- | --- | --- | --- |
| 1. [Alias registration](#alias-registration) | Aliases for existing tokenizers and one Markdown filename decision. | Current | None | H1, H9 |
| 2. [Docker ignore](#docker-ignore) | Docker dialect of ignore highlighting. | Prioritised follow-up | Unit 1 accepted and on `main` | H2, H9 |
| 4. [Dotenv](#dotenv) | Named dotenv dialect and scoped names. | Prioritised follow-up | Unit 1 accepted and on `main` | H4, H9 |
| 5. [Kotlin](#kotlin) | Kotlin tokenizer, starting from Gradle scripts. | Proposed | Unit 1 on `main`; scope review | H5, H9 |
| 6. [Ruby](#ruby) | Ruby tokenizer and conventional filenames. | Proposed | Unit 1 on `main`; scope review including maintenance cost | H6, H9 |
| 7. [Objective-C](#objective-c) | C-family Objective-C dialect. | Blocked | `.m` decision; Unit 1 on `main` | H7, H9 |
| 3. [Version files](#version-files) | `.tool-versions` first, then rbenv and pyenv files. | Deferred | A concrete editing need and scope review | H3, H9 |
| 8. [Vimscript](#vimscript) | Vimscript tokenizer. | Deferred | A concrete editing need and scope review | H8, H9 |
| 9. [tmux](#tmux) | tmux configuration tokenizer. | Deferred | A concrete editing need and scope review | H8, H9 |

Units keep their original numbers and task slugs for stable links. Each unit remains a separate PR; verify Unit 1 is accepted and on `main` before starting a dependent unit.

## Alias registration

Add the aliases from the spec without changing any tokenizer, and route rendered Markdown Preview through the same filename decision. Supported Markdown extensions are an explicit exception to build-file prefix priority, so `Makefile.notes.md` and `Dockerfile.notes.MD` render and highlight as Markdown, while `Makefile.json` and `Dockerfile.swift` stay build files. A Preview/Edit regression test covers both sides of the collision. Cover each name, case rules, precedence and fallback for lookalikes such as `.ignore.bak`, `.GITMODULES` and `notes.mkdx`. Confirm `.gitmodules` subsection fixtures and ripgrep/fd ignore semantics against the existing Git configuration and ignore fixtures.

## Docker ignore

Add a Docker dialect to the ignore tokenizer, or a sibling scanner if the shared state grows exceptions. Fixtures cover column-one comments, indented hashes, trimmed patterns including Unicode whitespace, exception markers, embedded carriage returns, backslashes and `**` patterns, with exact token ranges.

## Version files

Deferred until a concrete editing need; `.tool-versions` has the clearest case. Add focused handling per file rather than mapping them to `.nvmrc`. Fixtures follow the rbenv, pyenv and asdf readers: rbenv's first word, pyenv's per-line first word and comment lines, and asdf's multiple versions and inline comments.

## Dotenv

Add a dotenv tokenizer and the `.env.<name>` rule after extension lookup, so known extensions keep precedence. Fixtures cover `export`, quoting, multiline quoted values, inline comments, hashes inside quotes, empty values, `${NAME}` text and malformed lines.

## Kotlin

Start from Gradle Kotlin scripts such as `build.gradle.kts`. Add a Kotlin scanner with nested block comments, raw strings and template references that keep balanced braces. Fixtures cover soft keywords used as identifiers, annotations, number suffixes and unterminated drafts.

## Ruby

Add a Ruby scanner. Regular expression and percent-literal recognition depends on whether an operand is expected; heredoc bodies start after the introducing line. Fixtures cover nested interpolation, heredoc variants, symbols, `=begin`/`=end` and ambiguous `/` and `%` uses.

## Objective-C

Record a decision for the shared `.m` extension first. Then add an Objective-C option to the C-family scanner, keeping C/C++ behaviour unchanged. Fixtures cover `@` directives, boxed literals, `@"…"` strings, `#import` and `.mm` C++ keywords.

## Vimscript

Deferred until a concrete editing need. Add a Vimscript scanner with line-start continuation and command-position `"` comments, plus `vim9script` `#` comments. Fixtures cover `:set` options, mappings, scoped variables, strings and comments that resemble strings.

## tmux

Deferred until a concrete editing need. Add a tmux scanner. Fixtures cover command and flag forms, quoted strings, `#{…}` formats, hash comments outside quotes, `%if` directives, brace blocks and continuations.

## Publication and acceptance

Each unit uses a feature branch and a PR targeting `main`. Reuse the scanner primitives merged through [#143](https://github.com/bcinarli/pane-peek/issues/143). Use red/green fixtures for token categories, comments, quotes and escapes, incomplete drafts, Unicode ranges and lookalike fallback, plus real Preview/Edit/draft and BOM/CRLF Save checks. Run the [performance checks](../../engineering-and-review.md#performance-checks-for-feature-development) as a matched signed Release comparison against the previous accepted unit, covering native opening, editing and switching, elapsed time, CPU, RSS and unpacked app size. Apply tighten then probe, record concise outcomes in `evidence/<task-slug>.md` and keep unexecuted native and accessibility checks Pending. Commit, push, merge and release remain separate gates. Earlier release waivers do not cover H1–H9.
