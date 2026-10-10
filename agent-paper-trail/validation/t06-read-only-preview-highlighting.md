# T06 Read-only preview and highlighting

Current state: Unit 1 is accepted and locally committed as `e55c152`. Unit 2 Swift/JSON Preview highlighting is accepted; Bilal authorised its local commit and Unit 3 YAML/TOML continuation. T06 is `in progress`; other languages remain later units. Push is not authorised.

## Unit 1 scope and review state

Bilal approved Unit 1 implementation and confirmed all five presented manual checks on 2026-10-10, accepting the unit. Bilal then authorised its local commit and continuation to the next unit. Bounded asynchronous UTF-8 loading and selectable read-only plain-text preview are implemented; editing remains T07. Push is not authorised.

The feature branch is `bcinarli/t06-read-only-preview-highlighting`, created from clean `main` at `44872b0d8ba8a5bd78fa2b98bfd5f3466ef6fe82` after confirming live remote equality and T05 implementation/approval ancestry. No blocking product decision remains for this unit.

The 1 MiB file-byte cap includes a UTF-8 BOM. Reads check the opened descriptor type and request at most the cap plus one boundary byte. Strict decoding supports Unicode and preserves newline sequences; NUL means binary. Folder/package, non-regular, oversized, invalid UTF-8, empty and read-failure states are explicit. Regular text links read their target while preserving listed path and link-owned metadata. Preview and metadata load independently, using existing primary selection and listing revision; old or cancelled results cannot publish.

Bilal's font request is included: installed Operator Mono Lig, then JetBrains Mono, then the system monospaced font. The native body size is retained. Fonts are optional and are not bundled.

A10 has passing automated and accepted manual evidence. This unit adds the single-window content portion of A31; independent windows remain T16. Existing A17/A19/A33 owners are reused. A15 was pending at the Unit 1 checkpoint.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4, SDK 27.0, Node 26.1.0. Command Line Tools build/test; installed Xcode asset compiler packages the app. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter PreviewTests`, compiling stubs | Intentional red: 27 issues across eight tests. A fixture timestamp precision mismatch was corrected before this red run. Sandbox compiler-cache failures are excluded. |
| Targeted preview tests after implementation | Pass: eight tests. |
| `node scripts/test.mjs` | Pass: 53 tests in seven suites. Four deliberate known issues belong to existing test-gate failure tests. |
| Real filesystem behaviours | UTF-8/BOM/BOM-only/empty and mixed newlines; unchanged source bytes; exact/over-limit multibyte and BOM-inclusive files; NUL and invalid/truncated UTF-8; folders/packages, stale kind flags, relative/absolute text links, broken targets and a named pipe. |
| State and integration behaviours | Controlled stale success/error, clear while pending, failure clearing old content, cancellation/retry, focused multiple-selection primary and unchanged-listing same-URL Refresh. |
| Final font adjustment | UI-only change after the passing full core suite. Final package rebuild and native checks pass; no core change after the suite. AppKit resolves installed Operator Mono Lig to `OperatorMonoLig-Book` at the preferred 13-point body size. Standard JetBrains Mono is absent on this machine. A missing-family lookup falls back to the native monospaced font. |
| `node scripts/build-app.mjs` | Pass. Bundle plist validates; compiled and bundled executable SHA-256 both equal `582ed69a6fc14b66f2017b61124c292d0f33ab9915e80406a890e4fdfbec8639`. Native launch succeeds without signature recovery. |
| `git diff --check` | Pass. |
| Changed-document checks | Local links/anchors and fixture Node syntax pass. |

Standard tighten retained small local loader/state/view boundaries and existing selection/Refresh ownership, avoiding generic provider or gate extraction. It removed redundant font updates and kept comments about intent. Standard probe checked opened-file type and actual byte bounds, independent metadata publication, stale/cancelled state and native copy/scroll/Refresh seams. No implementation blocker was identified. Slow-volume latency and a deterministic grow-during-read race were not exercised; the actual read remains byte-bounded. M2 is incomplete, so its milestone analysis checkpoint is not yet due.

## Agent native observations

- Plain/BOM content displays Unicode and mixed newlines; empty, NUL, invalid UTF-8, oversized, folder/package and non-regular states are explicit. The exact-limit file renders in a scrollable preview. Metadata remains visible for unsupported content and broken links.
- Relative/absolute text links preview the target and retain the listed path, own size and stored target. A broken link reports a preview error while available link metadata remains visible. A named pipe returns an unavailable state without waiting for a writer.
- The final font build shows readable wrapped text at the current 300-point Details width in dark appearance. Clicking the native preview and Command-Down moves its scrollbar to the end; Command-Shift-Up selects content and Command-C copies it. Typing and pasting cannot edit it; source bytes remain unchanged. A real paste into the Go to Folder field confirmed copied first and last lines; the sheet was cancelled. Long-line text wraps and its end remains keyboard-accessible.
- Switching between the fixture panes changes preview and path to the focused primary. Command-click multiple selection previews the latest primary; deselecting it returns to the surviving item. Clearing the final selection removes content and path while retaining the other pane's selection.
- Changing `10-refresh.txt` from `before` to `after!`, retaining six bytes and the original modified timestamp, then Command-R updates preview. Moving `11-unavailable.txt` outside the stale listing shows a read error and retains its path. Restoring it and Refresh clears the error. Both fixture changes were restored.
- The accessibility tree exposes a non-editable `Read-only text preview` text area, its content and scrollbar, plus existing named path/metadata fields and textual unavailable/error states. Bilal confirmed appearance, enlarged text, keyboard focus and VoiceOver checks on 2026-10-10. Exact enlargement sizes, contrast measurements and a separate increased-contrast outcome were not reported; no complete accessibility audit is claimed.

## Run and fixture

From the repository root, quit the app before rebuilding:

```sh
node scripts/test.mjs
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create an isolated fixture with the recipe below. Copy its printed assignment into the shell. In PanePeek, use Command-L to open the printed root's `left` and `right` folders in the corresponding panes. Retain the fixture until review is accepted; cleanup requires separate approval.

```sh
node --input-type=module <<'JS'
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, realpathSync, symlinkSync, utimesSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = realpathSync(mkdtempSync(join(tmpdir(), 'panepeek-t06-review-')));
for (const name of ['left', 'right', 'left/folder', 'left/Example.app']) {
  mkdirSync(join(root, name));
}
const plain = Buffer.from('PanePeek read-only preview\r\nTürkçe 👀 and spaces\n\tA tabbed line\rLast line\n');
const limit = 1_048_576;
const line = 'Bounded preview line with readable text.\n';
const exact = Buffer.from(line.repeat(Math.ceil(limit / line.length))).subarray(0, limit);
for (const [name, bytes] of [
  ['01-plain.txt', plain],
  ['02-bom.txt', Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), plain])],
  ['03-empty.txt', ''], ['04-nul.bin', Buffer.from([0x61, 0x00, 0x62])],
  ['05-invalid.txt', Buffer.from([0xC3, 0x28])],
  ['06-exact-limit.txt', exact], ['07-oversized.txt', Buffer.concat([exact, Buffer.from('x')])],
  ['08-long-line.txt', 'Long line: ' + 'text '.repeat(1500) + '\nEND OF LONG LINE\n'],
  ['09-scroll.txt', Array.from({length: 200}, (_, i) => `Line ${i + 1}: native read-only scrolling and selection`).join('\n')],
  ['10-refresh.txt', 'before'], ['11-unavailable.txt', 'Read failure fixture']
]) {
  writeFileSync(join(root, 'left', name), bytes);
}
writeFileSync(join(root, 'right/right.txt'), 'Right pane primary preview\nIndependent pane selection\n');
utimesSync(join(root, 'left/10-refresh.txt'), 1700000000, 1700000000);
for (const [name, target] of [
  ['12-relative-link', '01-plain.txt'], ['13-absolute-link', join(root, 'right/right.txt')],
  ['14-broken-link', 'missing.txt'], ['15-folder-link', 'folder'], ['16-package-link', 'Example.app']
]) {
  symlinkSync(target, join(root, 'left', name));
}
execFileSync('mkfifo', [join(root, 'left/17-named-pipe')]);
console.log(`PANEPEEK_T06_FIXTURE='${root}'`);
JS
```

With `10-refresh.txt` selected, change its content without changing size or modified date, then Command-R in PanePeek:

```sh
node --input-type=module <<'JS'
import { statSync, utimesSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const file = join(process.env.PANEPEEK_T06_FIXTURE, 'left/10-refresh.txt');
const before = statSync(file);
writeFileSync(file, 'after!');
utimesSync(file, before.atime, before.mtime);
JS
```

Export the printed assignment first so Node receives it: `export PANEPEEK_T06_FIXTURE`. To repeat recovery, select another row, move `left/11-unavailable.txt` to `held-unavailable.txt` under the same fixture root without refreshing, then select the stale row. Move it back and Command-R. Use only the disposable fixture.

## Bilal's manual review

Bilal marked each presented check `OK` on 2026-10-10:

- [x] Check text, font, copy/scroll and rejected editing.
- [x] Switch panes, change primary selection and clear.
- [x] Check unsupported files and links with metadata.
- [x] Check Refresh and missing-file recovery.
- [x] Check appearance, enlarged text, keyboard focus and VoiceOver.

Unit 1 is accepted and its local commit is authorised. Bilal separately instructed continuation to the next coding unit; A15 Preview highlighting remains unimplemented at this checkpoint. Push is not authorised.

## Unit 2 Swift and JSON highlighting

Bilal instructed "commit this unit and continue to next one" on 2026-10-10. Unit 1 was locally committed as `e55c152`; the next bounded unit was presented as Swift/JSON Preview highlighting. Bilal reviewed Unit 2 and confirmed all five manual checks passed on 2026-10-10, accepting the unit. No blocking product decision remains. Other A15 languages and T07 editing are outside this unit.

Swift keywords, strings and comments have distinct colours; JSON strings, numbers and literals do too. The scanner recognises nested Swift block comments, escaped/raw/multiline strings and quoted expressions in interpolation. It returns ordered, non-overlapping UTF-16 ranges without changing source text. Interpolation retains its containing string colour; this is lexical presentation, with no compiler or whole-document validity claim. Unsupported extensions remain plain. Language detection uses the listed path's extension.

Tokenisation runs away from the main actor. Preview retains its request/cancellation guard after highlighting and publishes text and tokens together. Native foreground attributes use the accepted fragment's dynamic light/dark palette, retaining the existing optional fonts and selection/scroll ownership. A15 is partially validated; A10 and the existing single-window A31 evidence remain intact.

### Executed Unit 2 checks

Same OS/toolchain as Unit 1. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter SyntaxHighlightingTests`, compiling empty-token stub | Intentional red: six tests failed with 15 issues. After scanner implementation, all six passed. |
| New stale-highlight/plain-clear tests against a state stub that did not call highlighting | Intentional red: two test methods failed with five issues, including bounded missing-request diagnostics. After integration they passed. |
| `node scripts/test.mjs --filter 'SyntaxHighlightingTests\|PreviewTests'` | Pass: 16 tests in two suites before the large-input probe additions. |
| Final `node scripts/test.mjs` | Pass: 63 tests in eight suites, with four existing deliberate test-gate known issues. A default-sandbox compiler-cache denial was retried with cache access; it is not behavioural red evidence. |
| Scanner and state behaviours | Unicode UTF-16 offsets, token boundaries, strings/nested comments/escaped identifiers, valid and malformed JSON numbers/literals, incomplete/empty source, unsupported extensions, cancellation and superseded highlighting success/error. |
| Large/adversarial inputs | 1 MiB repeated source with more than 50,000 tokens, deeply nested interpolation and long unquoted hash runs produce safe ranges. No timing threshold or slow-volume performance guarantee. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `a02a62135182aca0ce301e10221f1e63a5514b9f702e1e025258d9510137ed4e`. Final native launch and Swift/JSON selection succeed without signature recovery. |
| `git diff --check` and changed-document checks | Pass: whitespace, local links/anchors and fixture Node syntax. |

Standard tighten kept the scanner local, reused the existing controlled test gate and limited native updates to foreground attributes. Standard evidence probe added large/deep inputs, bounded interpolation depth at 32 and found repeated scanning of unquoted hash runs. Those runs now advance once in both top-level and interpolation traversal; the large-input regression passes. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 2

- Swift shows purple keywords, green strings and muted comments; nested comment keywords stay muted and raw-string quotes/comment markers stay green. JSON shows green keys/values, purple literals and orange negative/decimal/exponent numbers. The current dark appearance uses the retained Operator Mono Lig font and wrapped text at the 300-point Details width.
- Whole-text copy pasted into the Go to Folder field preserves the original Unicode/raw-string source; the sheet was cancelled. Typing and pasting remain rejected. The Swift source still matches its plain-text fixture byte for byte.
- The 1 MiB highlighted Swift fixture loads and keyboard-scrolls to the end. The identical `.txt` fixture displays entirely plain text, with no residual token colours.
- Selecting the right pane's JSON changes preview and listed path; returning to the left Swift row restores its preview. Clearing the left selection removes preview/path while preserving the right selection. Command-R restores the selected Swift preview. Core tests retain unchanged-size/date Refresh coverage.
- The native accessibility tree still exposes the named read-only text area, source content, scroll controls and separate metadata. Bilal confirmed the presented Unit 2 light/dark appearance, enlarged text, keyboard focus and VoiceOver check passed. Exact enlargement sizes, contrast measurements and a separate increased-contrast outcome were not reported; no complete accessibility audit is claimed.

### Unit 2 fixture additions

Use the Unit 1 recipe above and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add the samples below, then Command-R in PanePeek. Open the fixture's `left` and `right` folders in their corresponding panes.

```sh
node --input-type=module <<'JS'
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const swift = [
  'import Foundation', '', '// Keyword text in a comment: let return',
  'struct Greeting {', '    let name = "Türkçe 👀"',
  '    /* outer /* nested let */ comment */', '    func message() -> String {',
  '        return #"Raw "quotes" and // text"#', '    }', '}', ''
].join('\n');
const json = JSON.stringify({name: 'Türkçe 👀', enabled: true, missing: null,
  count: 42, decimal: -12.5, exponent: 1e-8, text: 'true "quotes"'}, null, 2) + '\n';
const line = 'let value = "text" // comment\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/18-highlight.swift', swift], ['left/19-highlight.json', json],
  ['left/20-fallback.txt', swift],
  ['left/21-limit.swift', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['right/right.json', json]
]) {
  writeFileSync(join(root, name), text);
}
JS
```

### Bilal's Unit 2 manual review

- [x] Check Swift strings/comments and JSON colours.
- [x] Check pane switching, primary selection, clear and plain-text fallback.
- [x] Check font, copy, rejected editing and large-file scrolling.
- [x] Check Refresh of highlighted content.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal explicitly approved Unit 2 after reviewing all five presented manual checks. Bilal then instructed "commit unit 2 and continue to the next unit", authorising its local commit and Unit 3 YAML/TOML work. Push is not authorised.

## Language scope extension

On 2026-10-10, Bilal accepted the [additional language scope](../decisions/0006-extended-syntax-highlighting.md). The [spec](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor) owns the extended list, including YAML/YML, TOML, PHP, Go, Rust and Java. SCSS remains included; indented `.sass` is excluded. Suggested extra formats remain pending scope review.

This scope extension was a documentation update. No new language implementation or runtime checks were performed at that checkpoint; the 63-test/build evidence above was unchanged. Unit 2 was subsequently accepted, and its commit plus Unit 3 continuation were explicitly authorised. Later units and source-control actions retain separate gates.
