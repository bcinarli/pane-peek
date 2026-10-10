# T06 Read-only preview and highlighting

Current state: Units 1–6 and the Details scroll follow-up are accepted and locally committed as `e55c152`, `35bea90`, `78c9d5c`, `95ebc78`, `5b99bf1`, `dd6404d` and `100b0b8`. Unit 7 CSS/SCSS is accepted after all five manual checks passed. Bilal authorised its local commit and the next PHP unit. T06 is `in progress`; other languages retain later-unit gates. Push is not authorised.

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

Bilal explicitly approved Unit 2 after reviewing all five presented manual checks. Bilal then instructed "commit unit 2 and continue to the next unit", authorising its local commit and Unit 3 YAML/TOML work. Unit 2 was committed as `35bea902809a3dc53072b1022227621bf1affb70` (`Add Swift and JSON preview highlighting`). Push is not authorised.

## Language scope extension

On 2026-10-10, Bilal accepted the [additional language scope](../decisions/0006-extended-syntax-highlighting.md). The [spec](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor) owns the extended list, including YAML/YML, TOML, PHP, Go, Rust and Java. SCSS remains included; indented `.sass` is excluded. Suggested extra formats remain pending scope review.

This scope extension was a documentation update. No new language implementation or runtime checks were performed at that checkpoint; the 63-test/build evidence above was unchanged. Unit 2 was subsequently accepted, and its commit plus Unit 3 continuation were explicitly authorised. Later units and source-control actions retain separate gates.

## Unit 3 YAML and TOML highlighting

Bilal's instruction to commit Unit 2 and continue authorised this next bounded unit. Unit 2 was committed before Unit 3 edits on the existing task feature branch. YAML/YML and TOML Preview highlighting is implemented and accepted after Bilal confirmed all five manual review items passed on 2026-10-10. A15 remains partial. Other languages and editing retain their later-unit gates; no blocking product decision remains for this unit.

The focused configuration scanner adds keys, YAML document markers/anchors/aliases and TOML table headers to the existing token pipeline. Quoted and multiline strings, YAML literal/folded blocks, comments and scalar values retain their boundaries. Keys, references and headers reuse the existing purple colour; strings are green, numbers orange and comments muted. Native font, selection/scroll and PreviewState/Refresh ownership remain unchanged. Lexical highlighting does not resolve YAML tags, validate schemas or guarantee whole-document validity.

### Executed Unit 3 checks

Same OS/toolchain as Unit 1. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter ConfigurationHighlightingTests`, compiling empty-token stub | Intentional red: seven tests reported 24 issues. Implementation passed all seven after anchoring the YAML numeric alternatives to the whole scalar. |
| Probe regression tests before fixes | Intentional red: two tests reported four issues for YAML multiword plain scalars and TOML terminal content quotes. Both passed after fixing those boundaries. |
| Final configuration tests | Pass: ten tests, including Unicode/CRLF, uppercase extensions and YML alias, nested flow structures/arrays, block indentation, incomplete input, malformed numbers, 1 MiB files and long invalid scalar ranges. |
| Final `node scripts/test.mjs` | Pass: 73 tests in nine suites. Four existing deliberate test-gate known issues remain expected. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `708d1626af7db0a92773ed254bb8b750d62b09b02d53311ce5ada4afe4518614`. Native final launch succeeds without signature recovery. |
| `git diff --check` and changed-document checks | Pass: whitespace, local links/anchors and fixture Node syntax. |

Light code tighten retained the focused scanner and existing async/native pipeline, reused colours and removed repeated comment-line scanning. Standard evidence probe found and fixed the two scalar/string boundary regressions before the final suite. Large-input checks verify safe ranges without a timing threshold or slow-volume guarantee. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 3

- YAML and its identical YML sample show matching colours. Keys, document markers and anchors/aliases are purple; quoted/plain strings and indented block content are green. `true story` stays entirely green, the standalone boolean is purple, numbers orange and comments muted. Unicode and wrapped flow entries remain readable at the current 300-point Details width in dark appearance.
- TOML shows purple table/array-table headers and dotted keys, green quoted/multiline strings, orange decimal/base/exponent numbers and purple booleans/date-time text. Comment markers inside quoted/multiline strings stay green. The identical YAML `.txt` fixture is entirely plain, without residual token colours.
- Whole YAML source copied into the Go to Folder field preserves Unicode, quotes, indentation and block content; the sheet was cancelled. Typing and pasting are rejected. After the disposable Refresh change was restored, YAML, YML, plain-text twin and right-pane YAML are byte-identical.
- The exact 1 MiB TOML fixture loads and Command-Down moves its scrollbar to the end. Switching to the right YAML changes preview/path; clearing removes them while retaining the left selection. Command-clicking TOML alongside left YAML makes TOML primary; deselecting it restores YAML.
- With YAML selected, changing `enabled: true` to `enabled: "ok"`, preserving byte size and an exact fixed modified timestamp, then Command-R updates text and changes the value from purple to green. The initial fractional timestamp attempt was replaced with a fixed-date baseline before this check. Original text was restored and refreshed afterward.
- The accessibility tree exposes the named non-editable text area, source content and scrollbar beside separate metadata. Agent checks cover dark presentation and keyboard copy/scroll; Bilal confirmed all five presented manual checks passed, including light/dark appearance, enlargement, focus and VoiceOver. Exact enlargement sizes and a separate increased-contrast outcome were not reported. No contrast measurement or full accessibility audit is claimed.

### Unit 3 fixture additions

Use the existing fixture root from the Unit 1 recipe, export `PANEPEEK_T06_FIXTURE`, then add these samples and Command-R. Open its `left` and `right` folders in their corresponding panes. Run/build instructions remain above.

```sh
node --input-type=module <<'JS'
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const yaml = [
  '---', 'defaults: &defaults', '  name: "Türkçe 👀 # text"',
  '  enabled: true # comment', '  retries: 3', 'summary: true story',
  'message: |-', '  key: true # inside block', '  second line',
  "items: [{name: 'it''s fine', count: -12.5}, *defaults]", '...', ''
].join('\n');
const toml = [
  '# Configuration', 'title = "Türkçe 👀 # text"', '[server]',
  "host.name = 'localhost'", 'port = 8080', 'enabled = true',
  'stamp = 1979-05-27T07:32:00Z', 'description = """',
  '# text inside string', 'another line', '"""', '[[products]]',
  'name = "other"', 'samples = [0xDEAD_BEEF, 1_000, -1.2e+3]', ''
].join('\n');
const line = "name = 'value'\nflag = true\n";
const limit = 1_048_576;
for (const [name, text] of [
  ['left/22-highlight.yaml', yaml], ['left/23-highlight.yml', yaml],
  ['left/24-highlight.toml', toml], ['left/25-config-fallback.txt', yaml],
  ['left/26-limit.toml', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['right/right.yaml', yaml]
]) {
  writeFileSync(join(root, name), text);
}
JS
```

For the unchanged-size/date Refresh check, select `22-highlight.yaml`, set its modified date to an exact fixed timestamp and Refresh before changing the value. Replace `true` with `"ok"`, retaining that timestamp, then Refresh again. Restore `true` afterward. Use only the disposable fixture.

### Bilal's Unit 3 manual review

- [x] Check YAML/YML keys, anchors/aliases, comments and block text.
- [x] Check TOML headers, strings and scalar colours.
- [x] Check font, source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all review items passed on 2026-10-10, accepting Unit 3. Bilal then authorised its local commit before the approved Details scroll follow-up. Unit 3 was committed as `78c9d5cfaab187608d20e1768a857a9ee242565d` (`Add YAML and TOML preview highlighting`). Remaining languages require later coding-unit approval. Push is not authorised.

### Details scroll observation

After accepting Unit 3, Bilal supplied a screen recording and asked whether swiping outside the preview should move Details. Sampled recording frames show the filename, preview and metadata moving together briefly and returning, while the Details header stays fixed. The existing outer SwiftUI ScrollView wraps this content; the preview has its own native scroll view. This is outer scroll bounce, not a highlighting regression.

Approved follow-up: use [content-size-dependent bounce](https://developer.apple.com/documentation/swiftui/scrollbouncebehavior/basedonsize) for Details so fitting content stays still, retaining overflow scrolling for short windows, long paths and enlarged text. Keep preview scrolling and directory-list behaviour. Expected code change is local to BrowserWindow.swift. Validate with a build and native checks outside/inside the preview and with overflowing metadata. Bilal approved continuation and instructed committing Unit 3 first. No code change or new runtime check has been performed for this follow-up at this checkpoint.

## Details scroll follow-up

Bilal approved this unit with "continue", then instructed committing Unit 3 first. That commit completed before the one-line change to the outer Details ScrollView in BrowserWindow.swift: content-size-dependent vertical bounce. Preview scrolling retains its existing AppKit owner. No core or language code changed. This preserves the A10/A31 preview and A33 metadata surfaces. Bilal confirmed all presented manual tests passed on 2026-10-10, accepting the unit.

### Executed follow-up checks

Same OS/toolchain as Unit 1. UI-only layout uses build/native checks under the plan; no artificial test was added. The accepted Unit 3 result remains 73 tests in nine suites; that suite was not rerun for this view modifier.

| Check | Result |
| --- | --- |
| `node scripts/build-app.mjs` | Pass; rebuilt app launches. |
| Bundle plist and executable identity | Plist lint passes. Compiled and bundled SHA-256 both equal `bf70799c51ec4b97303ccaad6bb5696b7ad44ecbc02f40d9b70030c4b56676b0`. |
| Native fitting Details | Synthetic scrolling outside the preview leaves the settled layout in place; no outer scrollbar. This does not establish real trackpad elasticity. |
| Independent preview scrolling | The 1 MiB TOML preview keyboard-scrolls to the end; its scrollbar moves from 0 to 1 while outer metadata stays in place. |
| Native overflow | A disposable long-path symlink produces overflowing Details. The outer scrollbar moves 0 → 1 → 0; lower metadata and the complete target path become visible, then the preview/path-copy control returns. |
| `git diff --check` and document checks | Whitespace, local links/anchors and fixture Node syntax pass. |

Light tighten retains the single local modifier. Light probe checks independent preview scrolling and accessible overflow. Bilal subsequently accepted the real swipes, short-window/enlargement and keyboard/VoiceOver review items; exact enlargement sizes were not reported. Directory-list behaviour is unchanged. No milestone quality checkpoint is due while M2 remains incomplete.

### Follow-up run and fixture

Use the build/run instructions and retained fixture above. Select `left/26-limit.toml` for independent preview scrolling. For overflow, shorten the window or add this long-path link under the exported disposable fixture root. Open the printed directory with Command-L and select its link.

```sh
node --input-type=module <<'JS'
import { mkdirSync, symlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const targetDirectory = join(root, 'overflow-target', ...Array.from({length: 4}, (_, i) => `target-${i + 1}-` + 't'.repeat(140)));
const linkDirectory = join(root, 'overflow-link', ...Array.from({length: 4}, (_, i) => `folder-${i + 1}-` + 'l'.repeat(140)));
const target = join(targetDirectory, 'target-' + 't'.repeat(185) + '.txt');
const link = join(linkDirectory, 'link-' + 'l'.repeat(185) + '.txt');
mkdirSync(targetDirectory, {recursive: true});
mkdirSync(linkDirectory, {recursive: true});
writeFileSync(target, 'Preview remains read-only. Long path and target metadata must remain reachable.\n');
symlinkSync(target, link);
console.log(linkDirectory);
JS
```

### Bilal's follow-up manual review

- [x] Swipe up/down outside the preview while Details fits; content stays still.
- [x] Scroll/select/copy inside a large preview; metadata stays in place and editing remains rejected.
- [x] Shorten the window or enlarge text: scroll to lower metadata/link target and back to the path-copy control. Check keyboard focus and VoiceOver access, then confirm directory lists retain their existing behaviour.

Bilal confirmed all manual tests passed, authorised this unit’s local commit and instructed continuation to the next highlighting coding unit. The follow-up was committed as `100b0b8cc209286de42f148c68a18c04c182f866` (`Keep fitting Details content still while scrolling`). That continuation covers JavaScript/TypeScript under the plan; later units and push retain separate approval gates.

## Unit 4 JavaScript and TypeScript highlighting

Bilal's instruction to commit the accepted Details follow-up and continue authorised this unit. The follow-up was committed before Unit 4 edits on the existing task feature branch. JavaScript/TypeScript Preview highlighting is implemented and accepted after Bilal approved all five manual checks on 2026-10-10. This covers another A15 subset while preserving A10 and the single-window A31 behaviour. No blocking product decision remains; JSX/TSX, other languages and editing retain later-unit gates.

The focused scanner adds JavaScript keywords, TypeScript type words, quoted/template strings, comments, regex literals and numeric literals to the existing asynchronous token pipeline. It supports `.js`/`.mjs`/`.cjs` and `.ts`/`.mts`/`.cts`, consistent with the [TypeScript module extensions](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-7). Existing colours and optional fonts are reused; no native renderer or PreviewState change was needed.

Template substitutions keep the containing string colour. Nested expressions are traversed to find the template boundary, with nesting capped at 32; at that cap, remaining source keeps string colour. Regex-versus-division depends on syntax context in the [ECMAScript lexical grammar](https://tc39.es/ecma262/2022/multipage/ecmascript-language-lexical-grammar.html). This scanner recognises common expression/statement contexts locally; unusual ambiguous syntax can have approximate colours. It provides lexical presentation without parsing, type checking or source execution. Indented Sass and suggested extra formats remain outside accepted scope.

### Executed Unit 4 checks

Same OS/toolchain as Unit 1. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter JavaScriptHighlightingTests`, before JS/TS routing | Intentional red: seven tests reported 15 issues. Initial implementation passed all seven. |
| Unary-plus probe regression before its fix | Intentional red: one test reported two issues. The scanner had skipped the quote following unary plus because a Swift switch guard applied only to minus. Correcting the shared operator branch passed the regression and EOF operator probes. |
| Final JavaScript/TypeScript tests | Pass: nine tests covering Unicode UTF-16 ranges, non-nested comments, nested templates, regex classes/escapes, division/control boundaries, type words, module aliases, hashbang/Unicode line ends, incomplete input, number boundaries, property/escaped/private identifiers and unsupported fallback. |
| Large/adversarial inputs | Pass: exact 1 MiB repeated source with more than 50,000 tokens, 80-level template input handled by the nesting cap, and a 100,000-character invalid numeric candidate. Ordered, non-overlapping ranges stay within the source; no timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 82 tests in ten suites. Four existing deliberate test-gate known issues remain expected. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `604d762a7406de4c61635125e7c6d173dd07fcf2f4547d91065a8344fe48760f`. Rebuilt app launches. No source change after final tests/build. |
| JavaScript review fixture | Node syntax check passes; source was not executed. No TypeScript compiler check is claimed for its lexical fixture. |
| `git diff --check` and changed-document checks | Pass: whitespace, 111 local links/anchors in five documents and six Node fixture snippets. The documented Unit 4 recipe runs in a separate disposable folder; all seven generated files match the native review fixtures byte for byte. |

Standard tighten retained a focused scanner and reused token kinds, the native palette and guarded worker. Standard probe added large/incomplete/boundary inputs and found the unary-plus regression above. Light prose tighten and evidence probe keep observed checks separate from pending manual acceptance and verify the portable fixture against the running-app samples. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 4

- JavaScript shows purple keywords/literals, green quoted/template strings and regex literals, orange numbers and muted comments/hashbang. Nested template substitutions remain green. TypeScript shows purple interface/type words with the same string/comment boundaries. The `.mjs` twin displays matching JavaScript colours. Current dark appearance retains Operator Mono Lig and wrapping at the 300-point Details width.
- Copying the whole JavaScript preview into Go to Folder preserves the original Unicode, escapes, nested backticks and first/last lines; the sheet was cancelled. Typing and pasting are rejected. JS/module/plain twins and TS/module/right twins are byte-identical after restoring the disposable Refresh change.
- The identical `.txt` fixture displays entirely plain text. The exact 1 MiB TypeScript fixture loads; Command-Down moves its preview scrollbar from 0 to 1 while metadata stays in place.
- Selecting the right TypeScript sample changes preview/path. Returning to left JavaScript restores its preview; Command-clicking TypeScript makes it primary, deselecting it restores JavaScript, and clearing the final left selection removes preview/path while retaining the right selection.
- Changing JavaScript `ready: true` to `ready: "ok"` preserves its byte size and fixed modified timestamp. Preview retains old text before Command-R; Refresh loads the new text with the quoted value green. Restoring the source and Refresh returns `true`. The app remains open with left JavaScript focused at the top and right TypeScript selected.
- The accessibility tree exposes the named read-only text area, source content and scrollbar beside separate metadata. Agent checks cover dark presentation and keyboard copy/scroll. Bilal accepted all five presented Unit 4 checks, including light/dark appearance, enlarged text, focus and VoiceOver; exact enlargement sizes and a separate increased-contrast outcome were not reported; no contrast measurement or full accessibility audit is claimed.

### Unit 4 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open the fixture's `left` and `right` folders in their corresponding panes. Build/run instructions remain above.

```sh
node --input-type=module <<'JS'
import { execFileSync } from 'node:child_process';
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const js = [
  '#!/usr/bin/env node', '// Keywords in comment: const return',
  'export async function greet(name) {',
  '  const escaped = "Türkçe 👀 \\"quoted\\"";',
  '  const pattern = /[/*]hello\\/world/gi;',
  '  const ratio = 42 / 2;',
  '  const message = `Hello ${format({value: `nested ${name}`})} 👀`;',
  '  /* Non-nested block comment: let return */',
  '  if (name) /hello/.test(name);',
  '  return {escaped, pattern, ratio, message, ready: true};', '}', ''
].join('\n');
const ts = [
  'export interface Person {', '  readonly name: string;', '  count: number;', '}',
  'type Keys<T> = keyof T;', 'const person = {name: "Türkçe 👀", count: 3} satisfies Person;',
  'let value: unknown = true;', 'const message = `Hello ${person.name}`;',
  '// interface and string stay comments', ''
].join('\n');
execFileSync('node', ['--input-type=module', '--check'], {input: js});
const line = 'const value = `text ${name}`; // comment\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/27-highlight.js', js], ['left/28-highlight.ts', ts], ['left/29-js-fallback.txt', js],
  ['left/30-limit.ts', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/31-module.mjs', js], ['left/32-module.cts', ts], ['right/right.ts', ts]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/27-highlight.js'), 1700000000, 1700000000);
JS
```

For Refresh, select `27-highlight.js`, replace `ready: true` with `ready: "ok"` in this disposable fixture and retain timestamp `1700000000`. Command-R should update and recolour the value. Restore from `29-js-fallback.txt`, reset the same timestamp and Refresh afterward.

### Bilal's Unit 4 manual review

- [x] Check JavaScript/TypeScript keywords, strings/templates, regex boundaries and comments.
- [x] Check pane switching, primary selection, clear, module aliases and plain-text fallback.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check Refresh of highlighted content.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal approved all five manual review checks, authorised Unit 4’s local commit and instructed continuation to the next unit. Unit 4 was committed as `95ebc7848f51242cbb698682d9798a30e1190981` (`Add JavaScript and TypeScript preview highlighting`). This authorises HTML/XML under the plan; later units and push retain separate approval gates.

## Unit 5 HTML and XML highlighting

Bilal's instruction to commit accepted Unit 4 and continue authorised this unit. That commit completed before HTML/XML code edits on the existing task feature branch. HTML/XML Preview highlighting is implemented and accepted after Bilal confirmed all five manual reviews passed on 2026-10-10. This covers their A15 Preview subset while preserving A10 and single-window A31. No blocking product decision remains. JSX/TSX and remaining languages require later units; embedded HTML script/style colouring is optional and omitted here.

The focused scanner supports `.html`/`.htm` and `.xml`, reusing the existing asynchronous worker, guarded PreviewState and native foreground palette. Tags and attributes are purple, quoted/unquoted values green and comments muted. XML declarations and complete DTD declarations are purple; quoted XML declaration values are green. CDATA remains a green source span, and generic processing instruction data stays purple until `?>`. Text/entities remain literal source.

The [HTML tokenizer](https://html.spec.whatwg.org/multipage/parsing.html#tokenization) and [XML syntax](https://www.w3.org/TR/xml/) inform quote/comment and text boundaries. HTML script/style and other text-element bodies stay plain until their own case-insensitive closing tag; XML elements continue scanning child markup. This is a local lexical scanner, without full browser parsing, namespace/DTD validation, entity expansion or content rendering/execution. Malformed and context-sensitive syntax can have approximate colours.

### Executed Unit 5 checks

Same OS/toolchain as Unit 1. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter MarkupHighlightingTests`, before markup routing | Intentional red: seven tests reported 21 issues. Initial scanner/routing passed all seven. |
| Probe regressions before fixes | Intentional red: two tests reported four issues for Unicode HTML name continuation and generic XML processing instruction terminators inside quote characters. Correcting those boundaries passed all nine tests. |
| Final markup tests | Pass: nine tests covering tags, attributes, quote/unquoted value boundaries, Unicode UTF-16 ranges, HTM alias, comments/CDATA, namespaces, XML declaration/processing instructions, internal DTD subsets, HTML raw/text-element endings, incomplete input and unsupported fallback. |
| Large/adversarial inputs | Exact 1 MiB HTML/XML and 100,000 repeated less-than signs produce ordered, non-overlapping, in-bounds ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 91 tests in 11 suites. Four existing deliberate test-gate known issues remain expected. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `6d7c7b9e9dcb630e5caa086d690af9925f83b114d76f392d2e988fa972e6afd0`. Rebuilt app launches. No source change after final tests/build. |
| `git diff --check` and changed-document checks | Pass: whitespace, 115 local links/anchors in five documents and seven Node fixture snippets. Unit 5's documented recipe runs in a separate disposable folder; all six generated files match the native review fixtures byte for byte. |

Standard tighten retained the local scanner and existing palette/state owners, skipped ordinary text directly and removed repeated string conversion for the CDATA prefix. Standard probe found the two regressions above and verified declaration/raw-text and incomplete/large boundaries. Light prose tighten and evidence probe keep manual acceptance pending and check the portable fixture against the actual review samples. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 5

- HTML shows purple tags/attributes and declaration, green values and muted comments. Tag-like text inside quoted values stays green; script/style/textarea content stays plain. Entities display as literal source, without rendering. XML shows namespace names/attributes and processing/declaration spans purple, quoted values and whole CDATA green, comments muted. Current dark appearance retains Operator Mono Lig and wrapped source at the 300-point Details width.
- Whole HTML source copied into Go to Folder preserves Unicode, entities, quotation marks, indentation and first/last lines; the sheet was cancelled. Typing and pasting are rejected. After the disposable Refresh change was restored, HTML/HTM/plain twins and XML/right twins match byte for byte.
- The identical `.txt` fixture displays entirely plain text. Exact 1 MiB HTML loads and its native preview scrollbar moves from 0 to 1 while metadata stays in place.
- Right XML selection changes preview/path; returning to left HTML restores them. Command-click XML becomes primary, deselecting it returns to HTML, and clearing removes preview/path while retaining right selection.
- With HTML selected, replacing `<!-- note -->` with `<b>note</b>  ` retains its byte size and fixed modified timestamp. Preview retains the comment before Command-R; Refresh shows purple tags around plain text. Restoring and Refresh returns the muted comment. App remains open with left HTML focused and right XML selected.
- The native accessibility tree exposes named read-only source, scrollbar and separate metadata. Agent checks cover dark presentation and keyboard copy/scroll. Bilal accepted all five Unit 5 checks, including appearance, enlargement, focus and VoiceOver. Exact enlargement sizes and a separate increased-contrast outcome were not reported. No contrast measurement or full accessibility audit is claimed.

### Unit 5 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open the fixture's `left` and `right` folders in their corresponding panes. Build/run instructions remain above. Inspect these files only as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const html = [
  '<!DOCTYPE html>', '<!-- note -->',
  '<main id="preview" data-note="Türkçe 👀 > &amp;" hidden>',
  '  <h1>Raw source &lt;tag&gt; &amp; text</h1>',
  "  <input value='<!-- string -->' disabled/>",
  '  <script>const markup = "<fake>"; if (a < b) greet();</script>',
  '  <style>a::before { content: "<fake>"; }</style>',
  '  <textarea><fake> stays text</textarea>', '</main>', ''
].join('\n');
const xml = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<!DOCTYPE ns:note [<!ENTITY label "Türkçe > text">]>',
  '<ns:note xmlns:ns="urn:demo" xml:lang="tr">',
  '  <!-- <fake attr="value"> -->',
  '  <ns:title active="true">&label;</ns:title>',
  '  <![CDATA[<fake> & literal 👀]]>',
  '  <?review data="<fake>"?>', '</ns:note>', ''
].join('\n');
const line = '<item name="text">value</item>\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/33-highlight.html', html], ['left/34-highlight.xml', xml],
  ['left/35-markup-fallback.txt', html],
  ['left/36-limit.html', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/37-alias.htm', html], ['right/right.xml', xml]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/33-highlight.html'), 1700000000, 1700000000);
JS
```

For Refresh, select `33-highlight.html`, replace `<!-- note -->` with `<b>note</b>  ` (two trailing spaces) in this disposable fixture and retain timestamp `1700000000`. Command-R should update both text and colours. Restore from `35-markup-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal's Unit 5 manual review

- [x] Check HTML tags, attributes, quoted values/comments and plain script/style bodies.
- [x] Check XML namespaces, declarations, comments, CDATA and processing instructions.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, HTM/plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all manual reviews passed, accepting the exact five checks above, and instructed “commit and continue to next” on 2026-10-10. Unit 5 was committed as `5b99bf16a91fadff906b3fadb0a4e07ded5d723d` (`Add HTML and XML preview highlighting`) before the authorised Unit 6 JSX/TSX work. Further units and push retain separate gates. Nothing was pushed.


## Unit 6 JSX and TSX highlighting

Bilal accepted Unit 5 and instructed “commit and continue to next” on 2026-10-10, authorising this next unit. The HTML/XML commit completed before JSX/TSX code edits on the existing task branch. JSX/TSX Preview highlighting is implemented and accepted after all five manual checks passed on 2026-10-10. This covers their A15 Preview subset and preserves A10 and single-window A31. No blocking product decision remains. CSS/SCSS and other languages retain later-unit gates; editing remains T07.

A focused JSX extension uses the existing JavaScript scanner for embedded expressions. Tags, attributes and expression braces are purple; quoted values and code strings green, numbers orange and comments muted. JSX text and entities stay literal/plain. Fragments, member/namespace names, boolean/spread attributes, direct element attribute values and nested expressions are supported. TypeScript words retain existing code colours; common generic arrows and comparisons stay code. Component type arguments remain plain while their quote/comment/function-arrow boundaries are skipped safely.

The [JSX grammar](https://react.github.io/jsx/) and [TypeScript JSX documentation](https://www.typescriptlang.org/docs/handbook/jsx.html) inform the boundaries. JSX quoted attributes have no backslash escapes; text does not use JavaScript comments or HTML script/style raw-text rules. Templates retain whole-string colour, including JSX inside substitutions. Recognition uses local expression context rather than a full parser. Unusual ambiguous/malformed syntax can have approximate colours; names are not validated against matching closing tags. Mixed element/expression/template recursion is capped at 32, leaving the remaining JSX source plain at that limit (a containing template retains its string colour). Source remains readable, without rendering, entity expansion or execution.

### Executed Unit 6 checks

Same macOS 27.0.1 / SDK 27 environment as Unit 1; Swift 6.4 and Node 26.1.0 reconfirmed. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter JSXHighlightingTests`, before JSX routing | Intentional red: seven compiling tests reported 28 issues. A multiline test-fixture syntax error was corrected first and does not count as behavioural red. Initial implementation passed all seven. |
| Probe regressions before fixes | Intentional red: three additional tests reported 14 issues. Direct JSX attribute values lost their outer tag boundary, quoted/function type arguments closed early, and incomplete comment/string/template braces produced overlapping tokens. Fixes passed all ten JSX tests. |
| `node scripts/test.mjs --filter 'JSXHighlightingTests\|JavaScriptHighlightingTests\|MarkupHighlightingTests'` | Pass: 28 tests in three suites. Existing JS/TS and markup behaviour is retained; old unsupported TSX assertions now exercise excluded `.sass`. |
| Large/incomplete/Unicode inputs | Exact 1 MiB JSX/TSX, 200 nested mixed elements/expressions, Unicode names and partial tags/expressions produce ordered, non-overlapping, in-bounds UTF-16 ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 101 tests in 12 suites, with four existing deliberate test-gate known issues. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `0bc774ada6f661fbbdcb0bd50de8a27cbdbc8ab1d45f256d8cc7e908b2f62c60`. Rebuilt app launches; no source change after final tests/build. Existing Command Line Tools search-path warnings remain. |
| `git diff --check` and changed-document checks | Pass: whitespace, 119 local links/anchors in five documents and eight Node fixture snippets. The documented Unit 6 recipe runs in a separate disposable folder; all six generated files match the native review fixtures byte for byte. |

Standard tighten retained the local scanner extension and existing palette/state owners, removed repeated string conversion in generic lookahead and cut a redundant test comment. Standard probe added the three regressions above; an explicit expression-closure result prevents overlapping colours on incomplete input. Light prose tighten and evidence probe separate observed checks from pending manual acceptance and verify the portable fixture against native samples. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 6

- JSX displays purple tags/attributes/braces, green strings, orange numbers and muted code comments. Text resembling `return // plain` stays plain; entities remain source. TSX displays type words and nested/direct component values correctly, while generic arrows, type arguments and comparisons retain code/plain boundaries. Dark presentation retains Operator Mono Lig and wrapped source in the existing Details area.
- Whole JSX source copied into Go to Folder matches the preview exactly, including Unicode, entities, indentation and the trailing newline; the sheet was cancelled. Typing and paste are rejected. JSX/plain twins and TSX/right twins match byte for byte after fixture restoration.
- Plain `.txt` displays without residual colours. Exact 1 MiB TSX loads and native preview scrolling moves its scrollbar from 0 to 1. AX clicking the large text element failed because its reported bounds extended off screen; scrolling the containing preview area succeeded. No keyboard large-file scroll claim from that failed click.
- Right TSX selection supplies preview/path. Left JSX selection restores them; Command-click TSX becomes primary and deselecting it returns to JSX. Clearing the final left selection removes preview/path while the right TSX selection remains. An unfinished JSX expression/comment stays readable with metadata.
- Replacing `ready = true` with `ready = 'ok'` retains the JSX fixture’s 329-byte size and fixed modified timestamp. Before Refresh the preview retains `true`; Command-R shows green `'ok'`. Restoring the plain twin and Refresh returns `true`. App remains open with left JSX focused and right TSX selected.
- Native accessibility exposes named source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard source copy. Bilal accepted all five presented checks, including appearance, enlargement, focus and VoiceOver. Exact enlargement sizes and a separate increased-contrast outcome were not reported; no contrast measurement or full accessibility audit is claimed.

### Unit 6 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open the fixture’s `left` and `right` folders in their corresponding panes; select `38-highlight.jsx`, `39-highlight.tsx`, `40-jsx-fallback.txt`, `41-limit.tsx` and `42-incomplete.jsx`. Build/run instructions remain above. Inspect samples only as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const jsx = [
  'const ready = true; // preview note', 'const view = (', '  <>',
  '    <Panel.Header title="Türkçe 👀 &amp;" count={12} {...props}>',
  '      return // plain &lt;tag&gt;', '      {/* comment with } <fake/> */}',
  "      {ready ? <Row name={'yes'} /> : null}",
  '      {items.map(item => <span>{`item ${item.id}`}</span>)}',
  '    </Panel.Header>', '  </>', ');', ''
].join('\n');
const tsx = [
  'interface Props { readonly title: string; count: number }',
  'const identity = <T,>(value: T): T => value;',
  'const constrained = <T extends object>(value: T) => value;',
  'const less = a < b; // comparison',
  "const view = <Box<Props> title={null as unknown} icon=<Icon name='yes'/>/>;", ''
].join('\n');
const line = "const view = <Box title='text'>{true ? <Row/> : null}</Box>;\n";
const limit = 1_048_576;
for (const [name, text] of [
  ['left/38-highlight.jsx', jsx], ['left/39-highlight.tsx', tsx],
  ['left/40-jsx-fallback.txt', jsx],
  ['left/41-limit.tsx', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/42-incomplete.jsx', '<Panel title="Türkçe 👀">{ /* unfinished }'],
  ['right/right.tsx', tsx]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/38-highlight.jsx'), 1700000000, 1700000000);
JS
```

For Refresh, select `38-highlight.jsx`, replace `ready = true` with `ready = 'ok'` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `40-jsx-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 6 manual review

- [x] Check JSX tags/fragments/attributes, plain text/entities and embedded strings/comments/expressions.
- [x] Check TSX types, generic arrows/comparisons and nested/direct component values.
- [x] Check font, whole-source copy, rejected editing, incomplete input and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all five manual checks passed and instructed “commit this unit and continue to next one” on 2026-10-10. Unit 6 was committed as `dd6404d299d2c4127747616b1e006c6a346980f0` (`Add JSX and TSX preview highlighting`) before the authorised CSS/SCSS unit. Further units and push retain separate gates. Nothing was pushed.


## Unit 7 CSS and SCSS highlighting

Bilal accepted all five Unit 6 checks and instructed “commit this unit and continue to next one” on 2026-10-10, authorising this next unit. The JSX/TSX commit completed before CSS/SCSS code edits on the existing task feature branch. CSS/SCSS Preview highlighting is implemented and accepted after all five manual checks passed. This covers their A15 Preview subset and preserves A10 and single-window A31. No blocking product decision remains. Other languages retain later-unit gates; editing remains T07.

A focused style scanner reuses the guarded worker, token kinds and native palette. Selectors, properties and identifier/hash values are purple; strings and unquoted URLs green, numeric dimensions/percentages orange and comments muted. SCSS variables, directives and interpolation are purple. Nested rules, at-rules, custom properties, empty nested property groups and escaped names retain local lexical context. Strings, comments, URLs and SCSS interpolation suppress structural delimiters inside them. Interpolation in a string or URL retains its containing value colour; comments remain whole. Indented `.sass` stays plain.

The [CSS syntax specification](https://www.w3.org/TR/css-syntax-3/), [SCSS syntax](https://sass-lang.com/documentation/syntax/), [Sass comments](https://sass-lang.com/documentation/syntax/comments/) and [interpolation documentation](https://sass-lang.com/documentation/interpolation/) inform these boundaries. Classification uses statement delimiters rather than a full CSS/Sass parser; ambiguous, malformed or uncommon syntax can have approximate colours. Mixed string/interpolation recursion is capped at 32; the containing value remains readable at that limit. There is no compilation, style application, URL fetching or execution.

### Executed Unit 7 checks

Same macOS 27.0.1 environment as Unit 1; Swift 6.4, SDK 27 and Node 26.1.0 reconfirmed. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter StyleHighlightingTests`, before routing | Intentional red: seven compiling tests reported 25 issues because CSS/SCSS returned no tokens. Initial implementation passed all seven. |
| Standard probe regressions | Numeric hashes such as `#123456` split into number tokens: one regression test reported three intentional red issues. Fixed whole-hash scanning; all ten focused tests passed. A Swift raw-string fixture delimiter error was corrected before this red result and is excluded. |
| Other boundary checks | Custom-property value blocks, newline string recovery, escaped CRLF continuation, interpolation with nested quoted expressions/URLs and comments between property names and colons pass. Exact 1 MiB CSS/SCSS, 200 nested rules, 200 nested string/interpolation layers and a 100,000-character name produce ordered, non-overlapping, in-bounds UTF-16 ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 111 tests in 13 suites, with four existing deliberate test-gate known issues. Final depth/long-name coverage is included. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `546d2743bbc66a3db306a1446258bb05742a042471baa563f512d981ce68d0ba`. Final package launches and displays CSS with right SCSS selected. No source changes after the final suite/build. Existing Command Line Tools search-path warnings remain; no new Swift warnings. |
| `git diff --check` and changed-document checks | Pass: whitespace, 123 local links/anchors in five documents and nine Node snippets. The Unit 7 recipe runs in a separate disposable folder; all seven files match the native review fixtures byte for byte. |

Standard tighten retained one local scanner and a single classification pass per statement, removed force unwraps and simplified token-kind selection. Standard probe added the numeric-hash regression and the protected-value, recovery, depth and long-name checks above. The hash fix is included in the final full suite. Light prose tighten and evidence probe verify the native observations and portable fixture while retaining pending manual checks. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 7

- CSS displays selectors/properties/hash and identifier values in purple, dimensions in orange, strings/URLs in green and comments muted. SCSS displays variables/directives, nested properties/selectors and interpolation while retaining the same font and source presentation. Dark presentation uses the existing Operator Mono Lig font and wrapped preview.
- Whole CSS source copied into Go to Folder matches the source, including Unicode, the escaped URL, indentation and trailing newline (337 UTF-16 units). The sheet was cancelled. Typing and paste are rejected; source remains unchanged.
- `.txt` and excluded `.sass` twins display without residual colours. Exact 1 MiB SCSS loads and the native preview scrollbar moves from 0 to 1. An initial observation still showed Loading text preview; scrolling was checked only after the text appeared. No large-file keyboard-scroll claim.
- Right SCSS selection supplies preview/path. Left CSS restores them; Command-click SCSS becomes primary, deselecting it returns to CSS, and clearing the final left selection removes content/path while retaining right SCSS selection. Incomplete SCSS remains readable with metadata.
- Replacing `padding: 12px` with `padding: 'ok'` retains the CSS fixture's 341-byte size and fixed modified timestamp. Before Refresh the preview retains orange `12px`; Command-R shows green `'ok'`. Restoring the plain twin and Refresh returns `12px`. CSS/plain and SCSS/right/excluded twins match byte for byte.
- Native accessibility exposes named source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard source copy. Bilal accepted the presented appearance, enlargement, focus and VoiceOver check. No exact enlargement sizes, contrast measurement or full accessibility audit are claimed.

### Unit 7 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open the fixture's `left` and `right` folders in their corresponding panes; select `43-highlight.css`, `44-highlight.scss`, `45-style-fallback.txt`, `46-limit.scss`, `47-incomplete.scss` and `48-excluded.sass`. Build/run instructions remain above. Inspect samples as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const css = [
  '/* preview note: .fake { color: red; } */',
  '#app, .card:hover > a[data-title="Türkçe 👀"] {',
  '  --accent: #123456;', '  color: var(--accent);',
  '  padding: 12px 20%;', '  content: "literal } ; /* text */";',
  '  background: url(https://example.test/a\\)b.png);',
  '  &:focus { display: grid !important; }', '}',
  '@media (min-width: 40rem) { .card { color: red; } }', ''
].join('\n');
const scss = [
  '@use "sass:math";', '$gap: 1rem !default; // preview note',
  '@mixin spacing($size) {', '  padding: $size;',
  '  font: { size: 12px; weight: bold; }', '}',
  '.card-#{$name} {', '  @include spacing($gap);',
  '  border-#{$side}: solid;', '  content: "#{map.get($theme, \'key\')} 👀";',
  '  &:hover { color: $theme; }', '}', ''
].join('\n');
const line = ".card:hover { color: #123456; padding: 12px; content: 'text'; }\n";
const limit = 1_048_576;
for (const [name, text] of [
  ['left/43-highlight.css', css], ['left/44-highlight.scss', scss],
  ['left/45-style-fallback.txt', css],
  ['left/46-limit.scss', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/47-incomplete.scss', '.card { content: "unfinished 👀 #{map.get($theme, \'key\')}'],
  ['left/48-excluded.sass', scss], ['right/right.scss', scss]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/43-highlight.css'), 1700000000, 1700000000);
JS
```

For Refresh, select `43-highlight.css`, replace `padding: 12px` with `padding: 'ok'` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `45-style-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 7 manual review

- [x] Check CSS selectors/pseudo-selectors, nested rules, properties, values, comments and URLs.
- [x] Check SCSS variables/directives, interpolation, nested properties and quoted values.
- [x] Check font, whole-source copy, rejected editing, incomplete input and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain/excluded fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all manual tests and instructed “Commit the unit and continue to next” on 2026-10-10. This accepts the five checks and authorises Unit 7’s local commit and the next PHP unit. Commit will precede PHP code edits; push and subsequent units retain separate gates. Nothing was pushed.
