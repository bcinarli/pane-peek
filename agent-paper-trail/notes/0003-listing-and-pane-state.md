# Listing and pane state

## Listing timestamps and links

Read each listed link's own modification date and link flag without resolving its target. Target resolution is used separately to establish whether it navigates as a directory or represents a package. Reordering must retain the listed URL identity and apply the pane's current settings after an asynchronous read completes.

Name groups folders first; Modified compares raw timestamps across all kinds. Equal timestamps use ascending natural names, then paths, even in descending date order. Keep this in the existing comparator and filter the sorted listing for visibility; [A30](../specs/001-mvp/spec.md#breadcrumbs-and-sorting) owns the accepted rule. Kind grouping remains deferred.

Sample the current wall clock when rendering relative date labels. A minute timeline's context date can precede timestamps loaded by Refresh, briefly sending just-modified items into the future-date fallback. Keep the timeline for ageing labels and preserve raw timestamps for sorting.

## Background sorting

The filesystem reader returns entries without an ordering guarantee. `DirectoryPane` owns sorting through the existing comparator, avoiding a preliminary Name sort before applying the pane's current settings.

Apply a column and direction as one request, then sort an immutable snapshot away from the main actor. Retain the displayed rows while sorting. Publish only the latest sort; publishing a new listing invalidates sorts of the previous listing. If settings change while a loaded listing is being sorted, sort it again with the current settings before publishing its directory and rows together. Keep the existing navigation request guard across that extra asynchronous boundary.

A superseded worker can finish, but its result is discarded. Controlled completion-order tests cover these races; an optimised large-list probe checks UI-actor responsiveness without a timing threshold in the test suite. See [T03 evidence](../validation/t03-sorting-hidden-visibility.md#sorting-performance-follow-up-2026-10-06).

## Hidden visibility and Refresh

The core listing reads all immediate entries, including dot-prefixed and filesystem-hidden items. Each pane stores that sorted listing once and filters its exposed entries using its own visibility setting. Toggling uses the cached listing; new files or changed hidden flags appear after Refresh or navigation. No filesystem watcher is installed.

Refresh reuses navigation's latest-request/error handling and preserves sort/visibility settings. Shared actions capture the focused pane before starting asynchronous work. Selection is pane-owned and URL-based: retain surviving visible identities through sorting/Refresh and prune rows that become hidden or disappear. [T03 evidence](../validation/t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh) covers the native selection seam.

## Selection and primary item

Each pane owns the selected URL set and explicit primary URL; Details reads the focused pane. Keep only transient interaction state in the list and never infer a primary from unordered set iteration. [A19](../specs/001-mvp/spec.md#multiple-selection-and-drag-and-drop) owns reconciliation and fallback rules.

Report native click/keyboard endpoints after selection completes; reject deferred reports after directory changes. When the keyboard row disappears, track its surviving visible position so the next range shrink reports the endpoint. Programmatic pruning must not change pane focus; avoid focusing panes from a general selection-change observer. Return/double-click opens a directory only when it is the sole selected item.

`SelectionInteraction` contains the stateless keyboard endpoint and removed-row calculations used by the list. The view retains its transient interacted URL and native event timing; the pane remains the selection/primary owner. [M1 regression evidence](../validation/m1-selection-interaction.md) covers this boundary without emulating native gestures in tests.

## Context targeting and copied paths

Target the clicked row and focus its pane before entering menu tracking. SwiftUI menu-item `onAppear` did not publish selection/focus while the menu was open. A row-local AppKit context-click view targets synchronously, focuses the existing list, then starts native menu tracking on the next main-loop turn. Normal selection gestures pass through to the SwiftUI List. Keep this seam local when adding operation handlers; recheck dirty-preview guards with the editor. See [T14 evidence](../validation/t14-context-actions-copied-paths.md).

Copy pane-owned selection in displayed listing order. Use the same plain formatter for context actions, shared directory copy and the Details path. Listed item URLs preserve link identity; relative paths use the originating displayed directory. Canonical target resolution belongs to navigation, as defined in [decision 0005](../decisions/0005-finder-directory-symlink-navigation.md).

## Details metadata

Read attributes at the listed path without resolving links. Foundation's [attribute reader](https://developer.apple.com/documentation/foundation/filemanager/attributesofitem(atpath:)) returns the link's own attributes; its [link destination reader](https://developer.apple.com/documentation/foundation/filemanager/destinationofsymboliclink(atpath:)) preserves relative target text. Folder/package size is unavailable rather than a filesystem directory-entry size or recursive total.

Each successful listing publication changes the pane's revision, even when URL, size and modified date stay unchanged. Details uses the focused primary item plus this revision to reload on Refresh. Failed reads and sorting alone do not change the revision. Keep the latest-request/cancellation guard and mask metadata from a previous selection before the new view task starts.

SwiftUI GridRow did not reliably group accessibility labels with selectable values in the native tree. Each value has a local accessibility element with an explicit field name/value. Recheck VoiceOver reading and status perception when this layout changes. See [T05 evidence and accepted manual checks](../validation/t05-details-metadata-sidebar.md).

Keep the outer Details scroll area for long paths, link targets and enlarged text. Content-size-dependent vertical bounce avoids movement when everything fits, while overflow remains scrollable. The AppKit preview retains its own scroll view. See [T06 scroll evidence](../validation/t06-read-only-preview-highlighting.md#details-scroll-follow-up).

## Read-only preview

Preview uses the same focused primary item and listing revision as metadata, with an independent asynchronous task and result guard. Mask a previous selection before the new task starts. A successful Refresh must reread text even if URL, byte size and modified date are unchanged. Preview errors and unsupported content must not suppress available metadata.

Open read-only with nonblocking mode, then check the opened descriptor is a regular file before reading. A stale row or retargeted link can otherwise block on a named pipe. Bound the actual read to the 1 MiB file limit plus one boundary byte, including any BOM; listed size alone cannot enforce the bound if a file changes. Strict UTF-8 decoding avoids silently replacing invalid bytes. Preview target resolution does not change link-owned metadata or copied path identity.

The local AppKit text view owns native selection and scrolling. Do not reset either on metadata-only updates. Use installed font families in Bilal's requested order: Operator Mono Lig, JetBrains Mono, then native monospaced fallback, retaining the semantic body size. These optional fonts are not bundled; differently named Nerd Font variants are not aliases for the requested families. See [T06 Unit 1 evidence](../validation/t06-read-only-preview-highlighting.md).

## Preview highlighting

Tokens use ordered, non-overlapping UTF-16 ranges for native attributed text. Tokenise away from the main actor and retain the latest-request/cancellation guard after that extra asynchronous boundary. Publish text and its tokens together. Select the language from the listed filename, preserving link identity. Explicit startup names route to Shell; other files use their extension, with unsupported names staying plain.

Apply only foreground attributes to the existing text storage, retaining the font and native selection/scroll. Reset the full foreground range before adding tokens so plain fallback cannot retain old colours. The dynamic light/dark palette follows the accepted highlighting fragment. Recheck affected appearance and assistive-access behaviour with each palette change.

Swift highlighting is lexical: nested comments and raw/multiline strings are recognised; interpolation remains part of the containing string. Bound nested interpolation traversal and skip unquoted hash runs once to avoid repeated suffix scanning. See [T06 Unit 2 evidence](../validation/t06-read-only-preview-highlighting.md#unit-2-swift-and-json-highlighting).

YAML block text must suppress inner keys/comments until dedent; classify a plain scalar as a whole so `true story` and `12 monkeys` stay strings. TOML nested arrays must not become table headers. Multiline TOML delimiters can include adjacent content quotes. These scanners provide lexical colours without schema or whole-document validation. See [T06 Unit 3 evidence](../validation/t06-read-only-preview-highlighting.md#unit-3-yaml-and-toml-highlighting).

JavaScript/TypeScript template substitutions retain their containing string colour. Traverse nested expressions to find the closing backtick without mistaking quoted/comment/regex braces for substitution endings; cap nested templates at 32 and colour the remaining source as string at that bound. Regex-versus-division uses local expression/statement context, not a full parser, so unusual ambiguous syntax can have approximate colours. Block comments are non-nested. Keep source bytes, native selection and copy intact. See [T06 Unit 4 evidence](../validation/t06-read-only-preview-highlighting.md#unit-4-javascript-and-typescript-highlighting).

Markup attribute quotes do not use backslash escaping. Comments and CDATA suppress inner markup; declarations retain internal-subset brackets while ignoring quoted/comment delimiters. Generic XML processing instruction data ends at `?>` even inside quote characters; the XML declaration has its own attribute syntax. HTML text elements stay plain until their own case-insensitive closing tag, while XML elements retain normal child markup. These lexical boundaries do not implement browser tree construction, DTD validation or entity expansion. See [T06 Unit 5 evidence](../validation/t06-read-only-preview-highlighting.md#unit-5-html-and-xml-highlighting).

JSX uses the JavaScript scanner inside brace expressions, with an explicit closure result so an incomplete comment/string ending in `}` cannot produce overlapping tokens. Quoted JSX attributes and child text follow JSX boundaries, without HTML raw-text handling or backslash escapes. Keep code lookahead local; generic arrows/comparisons remain code and nested type-argument quotes/comments must not close a tag. Bound mixed recursion and leave remaining source readable. See [T06 Unit 6 evidence](../validation/t06-read-only-preview-highlighting.md#unit-6-jsx-and-tsx-highlighting).

CSS/SCSS classify each statement once, distinguishing declaration colons from pseudo-selectors before a rule block. Protect quoted values, unquoted URLs, custom-property value blocks and SCSS interpolation from structural delimiters. CSS has block comments; SCSS also has line comments. Interpolation inside a string or URL retains its containing value colour. Keep numeric hash colours whole and mixed string/interpolation recursion bounded. This remains lexical presentation, without compiling or applying styles. See [T06 Unit 7 evidence](../validation/t06-read-only-preview-highlighting.md#unit-7-css-and-scss-highlighting).

PHP line comments end at `?>`, while block comments and quoted/heredoc/nowdoc strings protect inner tags. Hash attributes are not comments. Heredoc markers inside interpolated quoted expressions must not close the containing string; nowdoc remains literal. Preserve member-name context across comments and bound mixed recursion. Standard PHP tags select code; surrounding text stays plain. See [T06 Unit 8 evidence](../validation/t06-read-only-preview-highlighting.md#unit-8-php-highlighting).

Go raw strings retain literal backslashes and newlines; interpreted strings/runes stop at LF, including after a backslash. Block comments are non-nested. Unicode identifier boundaries must classify supplementary letters without splitting native UTF-16 ranges. Predeclared selector names stay plain across comments; lexical colouring does not resolve shadowed names. See [T06 Unit 9 evidence](../validation/t06-read-only-preview-highlighting.md#unit-9-go-highlighting).

Rust single quotes can start characters, lifetimes or labels; avoid consuming following code as a string. Raw strings require the opening hash count at their terminator (up to 255), while byte/C prefixes retain the same string boundaries. Block comments nest; use iterative depth. Preserve Unicode XID boundaries and native UTF-16 ranges, and keep literal suffixes with their containing token. This remains lexical presentation without Cargo-edition or semantic inference. See [T06 Unit 10 evidence](../validation/t06-read-only-preview-highlighting.md#unit-10-rust-highlighting).

Java translates Unicode escapes before identifying comments, quotes and names. Track backslash eligibility and map token endpoints to the original UTF-16 source; displayed text and copied bytes stay unchanged. Text blocks require a newline after opening quotes/whitespace and protect escaped closing quotes. Ordinary strings/characters stop at CR/LF; block comments are non-nested. Contextual keyword colours are approximate, with member names kept plain across comments. See [T06 Unit 11 evidence](../validation/t06-read-only-preview-highlighting.md#unit-11-java-highlighting).

Python formatted/template replacements retain whole-string colour. Protect nested same-quote strings, comments and format fields before locating the outer delimiter. Raw strings still escape quote boundaries; formatted braces are not escaped by a backslash, while non-raw named Unicode escapes own their braces. Bound mixed recursion and retain UTF-16 source ranges. Soft keyword colours use approximate local member context. See [T06 Unit 12 evidence](../validation/t06-read-only-preview-highlighting.md#unit-12-python-highlighting).

Markdown code spans require matching backtick-run lengths; fences require their opening marker and at least its run length. Code and links own their contents before emphasis. Keep foreground ranges flat and ordered when constructs nest, with raw source intact. Collect simple reference definitions before resolving shortcuts, including forward references. Bound destination lookahead and delimiter depth; lexical colouring does not implement full block-container/dialect parsing or render Markdown. See [T06 Unit 13 evidence](../validation/t06-read-only-preview-highlighting.md#unit-13-markdown-highlighting).

Shell quoted strings protect nested substitutions; comments inside a command substitution must not close its containing quote. Heredoc quote removal includes empty labels, queued bodies keep their order and `<<-` strips tabs only when matching a terminator. Here-strings and arithmetic shifts do not queue bodies. Filename routing must pass the full listed last component so extensionless startup files reach the scanner. Keep mixed recursion bounded and dialect limits explicit. See [T06 Unit 14 evidence](../validation/t06-read-only-preview-highlighting.md#unit-14-shell-bash-and-zsh-highlighting).

SQL dollar strings require an exact case-sensitive delimiter and protect apparent inner syntax. Doubled quote/bracket delimiters belong to their containing token; ordinary strings use standard quote escaping, while explicit E strings also protect backslashes. Nested comments use iterative depth. Consume prefixed parameter/temporary names as a whole and classify ASCII keywords only, so Unicode uppercase lookalikes cannot become keywords. Keep the dialect union and unsupported configuration-dependent forms explicit. See [T06 Unit 15 evidence](../validation/t06-read-only-preview-highlighting.md#unit-15-sql-highlighting).

C/C++ line splicing changes lexical boundaries without changing source ranges. Raw bodies search their exact physical terminator; invalid delimiters recover through ordinary scanning. Comments are non-nested, and directive/header context resets at logical newlines or the next non-comment token. Keep escaped names whole to prevent keyword fragments. Source/header aliases share one lexical union; no macro evaluation or compiler-version inference. See [T06 Unit 16 evidence](../validation/t06-read-only-preview-highlighting.md#unit-16-cc-highlighting).

C# interpolation keeps whole-string colour while protecting nested quotes, comments and bracket pairs. Format recovery must return at an outer quote or ordinary line break when its closing brace is missing, so later source remains visible. Match raw quote runs exactly and account for dollar-controlled brace counts; keep escaped names whole without translating displayed text. Bound mixed recursion and avoid rescanning long delimiter runs. See [T06 Unit 17 evidence](../validation/t06-read-only-preview-highlighting.md#unit-17-c-highlighting).

Dockerfile comments begin physical lines; inline hashes are arguments. Continued instructions retain context through comment/blank lines. Keep parser-directive escape selection restricted to the opening block and use ASCII instruction classification to avoid Unicode lookalikes. Protect nested quoted parameter braces and queue heredoc bodies after the logical instruction. Retain separate colour ranges for comments within continued quoted values. See [T06 Unit 18 evidence](../validation/t06-read-only-preview-highlighting.md#unit-18-dockerfile-highlighting).

Makefile directives apply at statement heads; prerequisite words stay literal unless a target-specific assignment follows. Define bodies retain whole-string colour, including hashes and ordinary modifier words; only nested define/override define and endef affect depth. Make-level quotes do not escape a hash comment, while recipe quotes protect hashes. References protect nested delimiters and literal hashes. Infer only literal `.RECIPEPREFIX` characters, with an empty value resetting to tab; expansions and conditions are not evaluated. See [T06 Unit 19 evidence](../validation/t06-read-only-preview-highlighting.md#unit-19-makefile-highlighting).

## Draft editor and loss guards

[T07 Unit 1](../validation/t07-preview-editor-safe-saving.md) is manually accepted. BrowserState owns the draft, and pane callbacks guard proposed primary/reload changes before publication. Check again after asynchronous reads, because editing can begin while a listing is pending. Selection and focus change together after approval; inactive-pane reconciliation does not replace the current draft.

Capture the requested transition before presenting the Save/Discard/Cancel sheet. Cancel leaves it unapplied; successful Save or Discard resumes it once, only for the same document. Consume a Save answer before awaiting I/O; failed Save leaves the transition cancelled. Context menus need a continuation after target selection succeeds. A synchronous paths getter cannot open the menu after an asynchronous decision.

Keep one native text view through Preview/Edit, with native undo and presentation-only foreground attributes. Replace text only for a new document or explicit discard. Initialise and replace read-only. Clear undo history before disabling registration: removeAllActions resets registration depth, and a later enable can abort if the order is reversed. Skip colour updates during marked-text composition. Compare UTF-8 bytes for dirty state, since Swift String equality treats canonically equivalent Unicode as equal.

Draft editing performs no disk writes. Explicit Save preserves the original BOM/newlines and permissions, validates the on-disk identity/content, and retains the draft on failure. Include any retained BOM when checking the final file-size bound.

## Safe-save baseline

[T07 Unit 2](../validation/t07-preview-editor-safe-saving.md#unit-2-safe-saving) retains the bytes and file version from the same read that supplies the draft. Capture before stripping a BOM. Compare both identity/timestamps and bytes before staging and before atomic replacement; identical-content inode replacement still conflicts. Preserve the permission bits on the staged file and enforce its final BOM-inclusive size. Use only same-directory rename, retaining the source until commit. A simultaneous external write after the final check remains an MVP limit.

Successful Save changes the baseline and metadata revision without resetting native text/undo identity. Reject duplicate Save and draft replacement during the write; native preflight reads current document state before accepting text. Keep same-file selection revisions current. Late highlighting may populate the new clean baseline, so a subsequent Discard restores the saved colours.

## Native editor undo

Keep the editor's native UndoManager stable and route Undo/Redo through its responder actions. After applying native history, publish `didChangeText()` through the existing draft callback; changed visible text alone does not establish correct dirty/highlight state. Both actions and menu validation must check the live edit gate, because native undo can bypass the typing preflight. On a successful Save revision, break typing coalescing without clearing history so the next edit can undo to the saved baseline. Replacement and explicit Discard clear history before presentation registration is disabled. See the [T07 Undo correction](../validation/t07-preview-editor-safe-saving.md#undo-correction).
