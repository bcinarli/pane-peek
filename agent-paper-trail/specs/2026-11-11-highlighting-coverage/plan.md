# Highlighting coverage implementation plan

Status: Proposed

The [spec](spec.md) owns behaviour, [tasks](tasks.md) owns execution and [validation](validation.md) owns acceptance. Apply the [shared checklist](../../validation/checklist.md) to each atomic unit. Scope acceptance does not authorise coding, commit, push or merge. Present meaningful test evidence and the signed running app for manual acceptance before the next unit.

## Integration

Each unit registers names in `SyntaxDetection`, a tokenizer in `SyntaxGrammarCatalogue` and, where needed, a focused scanner beside the existing ones. Reuse `SyntaxScanning` primitives, the existing cancellation cadence and fixture style. The catalogue completeness test covers every new language ID. Update [usage documentation](../../../docs/usage.md) and the changelog with each unit that changes visible behaviour.

| Unit | Scope | Dependencies | Criteria |
| --- | --- | --- | --- |
| 1. [Alias registration](#alias-registration) | Aliases for existing tokenizers. | None | H1, H9 |
| 2. [Docker ignore](#docker-ignore) | Docker dialect of ignore highlighting. | Unit 1 reviewed | H2, H9 |
| 3. [Version files](#version-files) | rbenv, pyenv and asdf records. | Unit 1 reviewed | H3, H9 |
| 4. [Dotenv](#dotenv) | Dotenv tokenizer and scoped names. | Unit 1 reviewed | H4, H9 |
| 5. [Kotlin](#kotlin) | Kotlin tokenizer. | Unit 1 reviewed | H5, H9 |
| 6. [Ruby](#ruby) | Ruby tokenizer and conventional filenames. | Unit 1 reviewed | H6, H9 |
| 7. [Objective-C](#objective-c) | C-family Objective-C dialect. | Unit 1 reviewed | H7, H9 |
| 8. [Vimscript](#vimscript) | Vimscript tokenizer. | Unit 1 reviewed | H8, H9 |
| 9. [tmux](#tmux) | tmux configuration tokenizer. | Unit 1 reviewed | H8, H9 |

Units 2–9 are independent of each other and may be reordered by review; each remains a separate unit and PR.

## Alias registration

Add the aliases from the spec without changing any tokenizer. Cover each name, case rules, precedence over prefixes and fallback for lookalikes such as `.ignore.bak`, `.GITMODULES` and `notes.mkdx`. Confirm `.gitmodules` subsection fixtures and ripgrep/fd ignore semantics against the existing Git configuration and ignore fixtures.

## Docker ignore

Add a Docker dialect to the ignore tokenizer, or a sibling scanner if the shared state grows exceptions. Fixtures cover column-one comments, indented hashes, trimmed patterns, exception markers, backslashes and `**` patterns.

## Version files

Add focused handling per file rather than mapping them to `.nvmrc`. Confirm comment and multi-version behaviour against the rbenv, pyenv and asdf readers before fixing the pyenv comment rule in the spec.

## Dotenv

Add a dotenv tokenizer and the `.env.<name>` rule after extension lookup, so known extensions keep precedence. Fixtures cover `export`, quoting, multiline double quotes, inline comments, empty values, `${NAME}` text and malformed lines.

## Kotlin

Add a Kotlin scanner with nested block comments, raw strings and template references that keep balanced braces. Fixtures cover soft keywords used as identifiers, annotations, number suffixes and unterminated drafts.

## Ruby

Add a Ruby scanner. Regular expression and percent-literal recognition depends on whether an operand is expected; heredoc bodies start after the introducing line. Fixtures cover nested interpolation, heredoc variants, symbols, `=begin`/`=end` and ambiguous `/` and `%` uses.

## Objective-C

Add an Objective-C option to the C-family scanner, keeping C/C++ behaviour unchanged. Fixtures cover `@` directives, boxed literals, `@"…"` strings, `#import` and `.mm` C++ keywords.

## Vimscript

Add a Vimscript scanner with line-start continuation and command-position `"` comments, plus `vim9script` `#` comments. Fixtures cover `:set` options, mappings, scoped variables, strings and comments that resemble strings.

## tmux

Add a tmux scanner. Fixtures cover command and flag forms, quoted strings, `#{…}` formats, hash comments outside quotes, `%if` directives, brace blocks and continuations.

## Publication and acceptance

Each unit uses a feature branch and a PR targeting `main`. Use red/green fixtures for token categories, comments, quotes and escapes, incomplete drafts, Unicode ranges and lookalike fallback, plus real Preview/Edit/draft and BOM/CRLF Save checks. Compare native opening, editing and switching, resource use and bundle size against the previous accepted unit. Apply tighten then probe, record concise outcomes in `evidence/<task-slug>.md` and keep unexecuted native and accessibility checks Pending. Commit, push, merge and release remain separate gates. Earlier release waivers do not cover H1–H9.
