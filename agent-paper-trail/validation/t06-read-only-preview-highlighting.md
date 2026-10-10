# T06 Read-only preview and highlighting

Current state: all 13 Preview units and the Details scroll follow-up are accepted. Bilal confirmed all five Markdown checks on 2026-10-10 and authorised its local commit. T06 is `done` for implementation/manual acceptance. The task branch is unpublished; live `main` remains `44872b0`. Push, PR and merge retain separate gates, and T07 requires T06 on `main` under [decision 0002](../decisions/0002-feature-branches-and-prs.md).

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

Bilal confirmed all manual tests and instructed “Commit the unit and continue to next” on 2026-10-10. This accepts the five checks and authorises Unit 7’s local commit and the next PHP unit. Unit 7 was committed as `bdd2ddf96da763650069930e847fbaabd8971325` (`Add CSS and SCSS preview highlighting`) before PHP code edits. Push and subsequent units retain separate gates. Nothing was pushed.


## Unit 8 PHP highlighting

Bilal confirmed all five Unit 7 manual checks and instructed “Commit the unit and continue to next” on 2026-10-10, authorising this next unit. The CSS/SCSS commit completed before PHP code edits on the existing task feature branch. PHP Preview highlighting is implemented and accepted after all five manual checks passed. It covers the PHP subset of A15, preserving A10 and single-window A31. No blocking product decision remains. Other languages retain later-unit gates; editing remains T07.

A focused PHP scanner reuses the guarded worker, token kinds and native palette. Standard `<?php` and `<?=` blocks distinguish language tags, keywords, variables, strings, comments, literals and numbers. Quoted/backtick strings and heredoc/nowdoc retain their containing string colour, including interpolation. Attributes are not mistaken for hash comments. Member and qualified names retain local identifier context. Surrounding markup and configuration-dependent `<?` short tags stay plain. Content is displayed as source without execution.

The [PHP tag reference](https://www.php.net/manual/en/language.basic-syntax.phptags.php), [comments](https://www.php.net/manual/en/language.basic-syntax.comments.php), [strings](https://www.php.net/manual/en/language.types.string.php) and [keywords](https://www.php.net/manual/en/reserved.keywords.php) inform these boundaries. The [PHP scanner source](https://github.com/php/php-src/blob/master/Zend/zend_language_scanner.l) confirms tag, member and heredoc marker boundaries. This is lexical presentation, without a complete PHP parser or runtime configuration. Mixed string/interpolation/heredoc recursion is capped at 32, retaining readable source at that limit. Uncommon contextual or malformed syntax can have approximate colours.

### Executed Unit 8 checks

Same macOS 27.0.1 environment as Unit 1; Swift 6.4, SDK 27 and Node 26.1.0 reconfirmed. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter PHPHighlightingTests`, before routing | Intentional red: seven compiling tests reported 25 issues because PHP returned no tokens. Initial implementation passed all seven. A Swift throwing-condition compilation error was corrected and excluded from behavioural red. |
| Standard probe regressions | Member names were coloured as keywords/literals, and a heredoc marker inside an interpolated quoted expression ended the string early. Two tests reported six intentional red issues. Fixed both boundaries; all nine focused tests passed. |
| Other boundary checks | Standard/short-echo tags, plain surrounding text, line/block comments, attributes, escapes, nested interpolation, indented heredoc/nowdoc markers, case/Unicode and incomplete source pass. Exact 1 MiB, 200 nested string/interpolation layers, 100 nested heredocs and 100,000-character labels/invalid numbers produce ordered, non-overlapping, in-bounds UTF-16 ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 120 tests in 14 suites, with four existing deliberate test-gate known issues. Final depth/long-input additions are included. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `fa9cd17ec60bcf725dd06f4c4e1a4387f2475f72a5e3f6eda6298bdcbe101fb5`. Native launch and PHP display pass. No source changes after the final suite/build. Existing Command Line Tools search-path warnings remain; no new Swift warnings. |
| `git diff --check` and changed-document checks | Pass: whitespace, 127 local links/anchors in five documents and ten Node snippets. The portable recipe runs in a separate disposable folder; all five files match the native fixtures byte for byte. |

Standard tighten retained the focused scanner and existing presentation owners, followed neighbouring initialisation style and skipped code whitespace directly. Standard probe added and fixed the two regressions above, plus mixed-depth and long-input checks. Light prose tighten and evidence probe verify the native observations and portable recipe while retaining pending manual checks. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 8

- PHP tags, keywords, variables and literals display in purple; quoted/backtick/heredoc/nowdoc strings are green, numbers orange and comments muted. Surrounding XML/HTML remains plain source. Native font and wrapped presentation are retained. The `.txt` twin has no residual colours.
- Whole PHP source copied into Go to Folder matches the preview, including Unicode, indentation and trailing newline (443 UTF-16 units, 445 UTF-8 bytes). The sheet was cancelled. Typing and paste are rejected; source remains unchanged.
- Exact 1 MiB PHP loads with metadata and the native preview scrollbar moves from 0 to 1. The large accessibility value is a visible excerpt; it is not a full-buffer byte check. No large-file keyboard-scroll claim.
- Right PHP supplies preview/path. Left PHP restores them; Command-clicking incomplete PHP makes it primary with readable text and metadata, deselecting returns to the earlier PHP selection, and clearing it removes preview/path while retaining right selection.
- Replacing `[true, null, 12]` with `['ok', null, 12]` retains the fixture’s 445-byte size and fixed modified timestamp. Before Refresh it retains purple `true`; Command-R displays green `'ok'`. Restoring the plain twin and Refresh returns the original source. PHP/plain/right twins match byte for byte. The app remains open with left PHP focused and right PHP selected, with no sheet.
- Native accessibility exposes named source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard source copy. Bilal confirmed the presented appearance, enlargement, focus and VoiceOver checks; no contrast measurement or full accessibility audit is claimed.

### Unit 8 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open its `left` and `right` folders in their corresponding panes; select `49-highlight.php`, `50-php-fallback.txt`, `51-limit.php` and `52-incomplete.php`. Build/run instructions remain above. Inspect these samples as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const php = [
  '<?xml version="1.0"?><h1>Plain $text</h1>', '<?php',
  'namespace Preview;', '#[Example("demo")]',
  'function greet(string $name): string {',
  '  $message = "Hello {$name} 👀";',
  '  $values = [true, null, 12]; // preview note',
  '  /* ?> and $fake stay inside this comment */',
  '  return $message;', '}',
  '$doc = <<<TEXT', '  quoted "return" ?> $name', '  TEXTMORE', '  TEXT;',
  "$raw = <<<'RAW'", '  $literal /* source text */', '  RAW;',
  '$command = `echo {$name}`;',
  '?>', "<p><?= greet('Bilal') ?></p>", ''
].join('\n');
const line = "$name = 'value'; // preview note\n";
const limit = 1_048_576;
for (const [name, text] of [
  ['left/49-highlight.php', php], ['left/50-php-fallback.txt', php],
  ['left/51-limit.php', '<?php\n' + line.repeat(Math.ceil(limit / line.length)).slice(0, limit - 6)],
  ['left/52-incomplete.php', '<?php $message = "unfinished 👀 {$data[\'key\']}'],
  ['right/right.php', php]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/49-highlight.php'), 1700000000, 1700000000);
JS
```

For Refresh, select `49-highlight.php`, replace `[true, null, 12]` with `['ok', null, 12]` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `50-php-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 8 manual review

- [x] Check PHP tags, keywords, variables, attributes and plain surrounding markup.
- [x] Check quoted/backtick strings, heredoc/nowdoc, interpolation and comments.
- [x] Check font, whole-source copy, rejected editing, incomplete input and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all five checks on 2026-10-10 and authorised the local PHP commit and next Go unit. No exact enlargement size, contrast measurement or additional setting check is inferred. T06 remains in review while other accepted languages are pending. Nothing was pushed.

The accepted PHP unit was locally committed as `c173b41012d492aacf0500aa90ed6227a0d043d9` with Bilal’s explicit approval, before Go code edits.

## Unit 9 Go highlighting

Bilal confirmed all five PHP manual checks and instructed “commit and continue to next” on 2026-10-10, authorising Go. The PHP commit completed first on the existing task feature branch. Go Preview highlighting is implemented and accepted after all five manual checks passed. It covers the Go subset of A15, preserving A10 and single-window A31. No blocking product decision remains; other languages retain later-unit gates and editing remains T07.

A focused Go scanner reuses the guarded worker, token kinds and native palette. It distinguishes reserved keywords, interpreted/raw strings, rune literals, line/block comments, predeclared literals and numeric forms. Identifier boundaries follow Unicode letters and decimal digits, including supplementary letters. Raw strings retain literal backslashes and line endings; interpreted strings/runes stop at a line feed, including after a backslash. Block comments end at the first terminator. Predeclared names after a selector dot stay plain across whitespace/comments.

The [official Go lexical grammar](https://go.dev/ref/spec#Lexical_elements) informs these boundaries. Colours remain lexical: types and ordinary identifiers stay plain, shadowed predeclared constants can have approximate colours, and this does not validate an entire program or execute source. Invalid numeric runs stay readable without partial number colours inside the run.

### Executed Unit 9 checks

macOS 27.0.1 (26A434), Swift 6.4, SDK 27 and Node 26.1.0 reconfirmed. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter GoHighlightingTests`, before routing | Intentional red: seven compiling tests reported 15 issues because Go returned no tokens. Initial implementation passed all seven. |
| Standard probe regressions | Selector names such as `value.true` were coloured as constants. One test reported one intentional red issue. Fixed local selector context across whitespace/comments; all nine focused tests pass. |
| Other boundary checks | Quoted/raw/rune escapes, non-nested comments, LF boundaries, case/Unicode identifiers, integers/floats/imaginary values and incomplete/plain fallback pass. Exact 1 MiB repeated code and single strings/comments, 100,000-digit valid/invalid numbers and supplementary-letter identifiers have ordered, non-overlapping, in-bounds UTF-16 ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 129 tests in 15 suites, with four existing deliberate test-gate known issues. |
| Final `node scripts/build-app.mjs` | Pass. Plist validates; compiled and bundled SHA-256 both equal `e196396fd4ec8da193ecea18700231a708cd1118151a64d1d64d101a557474da`. Native launch and Go display pass. No source changes after the final suite/build. Existing Command Line Tools search-path warnings only. |
| Whitespace and changed-document checks | Pass: 131 local links/anchors in five documents and eleven Node snippets. The portable Go recipe runs separately; all five files match the native fixtures byte for byte. |

Standard tighten removed repeated identifier classification inside the scan loop and clarified numeric-pattern composition, retaining a focused scanner and existing presentation owners. Standard probe added/fixed the selector regression and checked long single tokens. Light prose tighten and evidence probe verified the recorded native results and portable recipe, retaining pending manual checks. No remaining implementation blocker was identified. M2 remains incomplete, so its milestone quality checkpoint is not yet due.

### Agent native observations for Unit 9

- Keywords and predeclared literals display in purple, strings/runes green, numbers orange and comments muted. Raw string content retains whole-string colour. The font and wrapped presentation are retained; the `.txt` twin has no residual colours.
- Whole Go source copied into Go to Folder matches the preview, including Unicode, indentation and trailing newline (425 UTF-16 units, 427 UTF-8 bytes). The sheet was cancelled. Typing/paste are rejected and the source remains unchanged.
- Exact 1 MiB Go loads with metadata; the native preview scrollbar moves from 0 to 1. No full-buffer accessibility byte count or large-file keyboard-scroll claim.
- Right Go supplies preview/path. Left Go restores them; Command-clicking incomplete Go makes it primary with readable text/metadata, deselecting restores the previous primary, and clearing removes preview/path while retaining right selection.
- Replacing `enabled := true` with `enabled := "ok"` retains 427 bytes and timestamp `1700000000`. Before Refresh the preview retains purple `true`; Command-R displays green `"ok"`. Restoring from the plain twin and Refresh returns the original source. Go/plain/right twins match byte for byte. The app remains open with left Go focused and right Go selected, with no sheet.
- Native accessibility exposes named source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard source copy. Bilal confirmed the presented light/dark, enlargement, focus and VoiceOver checks; no contrast measurement or full accessibility audit is claimed.

### Unit 9 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open its `left` and `right` folders in their corresponding panes and inspect `53-highlight.go`, `54-go-fallback.txt`, `55-limit.go` and `56-incomplete.go`. Build/run instructions remain above. Inspect the samples as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const go = [
  'package main', '', 'import "fmt"', '',
  'type Example struct { Name string }',
  'func greet(name string) string {',
  '  message := "Hello " + name + " 👀"',
  '  enabled := true // preview note',
  '  numbers := []complex128{0x_2A, .25, 1e+2, 0x1p-2i}',
  '  raw := `line one', 'return "quoted" // still raw \\', '`',
  "  runeValue := '\\U0001F440'",
  '  /* return and "fake" stay inside this comment */',
  '  if enabled { fmt.Println(numbers, raw, runeValue) }',
  '  return message', '}', ''
].join('\n');
const line = 'var name = `value`; // preview note\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/53-highlight.go', go], ['left/54-go-fallback.txt', go],
  ['left/55-limit.go', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/56-incomplete.go', 'package main\nvar message = "unfinished 👀\\\nfunc greet() {\n  return `raw body\n'],
  ['right/right.go', go]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/53-highlight.go'), 1700000000, 1700000000);
JS
```

For Refresh, select `53-highlight.go`, replace `enabled := true` with `enabled := "ok"` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `54-go-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 9 manual review

- [x] Check Go keywords, identifier boundaries, literals and numbers.
- [x] Check quoted/raw strings, rune literals, comments and incomplete source.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all five checks on 2026-10-10 and authorised the local Go commit and next Rust unit. No exact enlargement size, contrast measurement or additional setting check is inferred. T06 remains in review while other accepted languages are pending. Nothing was pushed.


Go Unit 9 was committed locally with approval as `410681813f8a0813e615ce18713cedb8557f50ec` before Rust implementation. Nothing was pushed.

## Unit 10 Rust highlighting

Bilal confirmed all five Go manual checks and instructed “commit this unit and continue to next one” on 2026-10-10, authorising Rust. Rust Preview highlighting is implemented and accepted after all five manual checks passed. It covers the Rust subset of A15, preserving A10 and single-window A31. No blocking product decision remains; later languages and T07 retain their gates.

The focused `.rs` scanner reuses the existing worker, token kinds, palette and native renderer. It colours keywords, booleans, quoted/raw/byte/C strings, character literals, lifetimes, comments and numeric forms. Raw identifiers stay plain. Nested block comments use iterative depth; quoted strings can span lines, and raw strings require matching hashes. Characters and lifetimes have separate boundaries. Unicode identifiers and supplementary characters retain native UTF-16 ranges.

The official [Rust tokens](https://doc.rust-lang.org/reference/tokens.html), [comments](https://doc.rust-lang.org/reference/comments.html), [identifiers](https://doc.rust-lang.org/reference/identifiers.html) and [keywords](https://doc.rust-lang.org/reference/keywords.html) inform these boundaries. Colours are lexical: edition-sensitive keywords use the current keyword set; `union` and `macro_rules` are coloured without semantic context. Literal suffixes remain with their literal, including macro suffixes. Incomplete or invalid source remains readable; this does not validate a program, infer its Cargo edition or execute it.

### Executed Unit 10 checks

Environment reconfirmed: macOS 27.0.1 (26A434), Swift 6.4, SDK 27 and Node 26.1.0. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter RustHighlightingTests` before routing | Seven compiling tests report 17 intentional red issues because `.rs` returns no tokens. All seven pass after implementation. |
| Standard probe coverage | Nine focused tests pass, including literal suffixes, invalid numeric runs, maximum 255-hash strings, range/member boundaries and long single tokens. A Swift fixture delimiter typo was corrected before the probe run; compilation errors are excluded from behavioural red. |
| Large/incomplete boundaries | Exact 1 MiB repeated source and single strings/comments, 10,000 nested block comments, 100,000 hashes/digits and supplementary-letter identifiers produce safe ordered ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 138 tests in 16 suites, with four existing deliberate test-gate known issues. |
| Final `node scripts/build-app.mjs` | Pass after the full suite. Plist validates; compiled and bundled SHA-256 both equal `30a3fbcc3e997a93238fc926e5e48d4831268281d1a40e29d87f9d51cfd75663`. Native launch and Rust display pass. No source changes after final suite/build. Existing Command Line Tools search-path warnings only. |
| Whitespace and document checks | Pass: 135 local links/anchors across five maintained documents and twelve Node snippets. The portable Rust recipe runs separately; all five files match native fixtures byte for byte. |

Standard tighten retained local scanner functions and clarified the scalar variable name, avoiding a shared lexer or new presentation state. Standard probe verified suffixes, nested comments, literal/lifetime boundaries and long inputs. No implementation blocker remains. Light prose tighten and evidence probe keep executed observations separate from pending manual checks. M2 remains incomplete, so its milestone quality checkpoint is not due.

### Agent native observations for Unit 10

- Keywords/booleans and lifetimes display in purple, strings/characters green, numbers orange and comments muted. Raw string content and nested comments retain their containing colour. Font and wrapping are retained; the `.txt` twin has no residual colours.
- Whole Rust source copied through Go to Folder matches exactly, including Unicode, indentation and trailing newline (491 UTF-16 units, 493 UTF-8 bytes). The sheet was cancelled. Typing and paste are rejected; preview source is unchanged.
- Exact 1 MiB Rust loads with metadata; the native preview scrollbar moves from 0 to 1. No full-buffer accessibility byte count or large-file keyboard-scroll claim.
- Right Rust supplies preview/path. Left Rust restores them; Command-clicking incomplete Rust makes it primary with readable source and 74-byte metadata. Deselecting restores the previous primary; clear removes preview/path and retains right selection.
- Changing `enabled = true` to `enabled = "ok"` retains 493 bytes and timestamp `1700000000`. The old preview persists until Command-R, then displays green `"ok"`. Restoring from the plain twin and Refresh returns the original source. Rust/plain/right files match byte for byte. The app remains open with left Rust focused and right Rust selected, with no sheet.
- Native accessibility exposes named preview source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard copy. Bilal confirmed the presented light/dark, enlargement, focus and VoiceOver checks; no contrast measurement or full accessibility audit is claimed.

### Unit 10 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add the samples below, then Command-R. Open the `left` and `right` folders in their corresponding panes. Inspect `57-highlight.rs`, `58-rust-fallback.txt`, `59-limit.rs` and `60-incomplete.rs`. Build/run instructions remain above. Inspect these files as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const rust = [
  'use std::borrow::Cow;', '',
  "struct Example<'a> { name: &'a str }",
  "fn greet<'a>(name: &'a str) -> Cow<'a, str> {",
  '  let message = "Hello 👀";',
  '  let enabled = true; // preview note',
  '  let numbers = (0x2A_u8, 1..=3, 1.25e+2_f64);',
  '  let r#match = r##"line one',
  'return "quoted"# // still raw \\', '"##;',
  "  let byte = b'\\x52';",
  "  let rune = '\\u{1_f440}';",
  '  let bytes = br#"return "quoted" \\ "#;',
  '  /* outer /* nested */ return "fake" */',
  '  if enabled { return Cow::Borrowed(name); }',
  '  Cow::Owned(message.into())', '}', ''
].join('\n');
const line = 'let name = r#"value"#; // preview note\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/57-highlight.rs', rust], ['left/58-rust-fallback.txt', rust],
  ['left/59-limit.rs', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/60-incomplete.rs', 'fn greet<\'a>(name: &\'a str) {\n  let value = r##"unfinished 👀\nreturn "#\n'],
  ['right/right.rs', rust]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/57-highlight.rs'), 1700000000, 1700000000);
JS
```

For Refresh, select `57-highlight.rs`, replace `enabled = true` with `enabled = "ok"` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `58-rust-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 10 manual review

- [x] Check Rust keywords, raw identifiers, lifetimes and numbers.
- [x] Check quoted/raw/byte strings, characters, nested comments and incomplete source.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all five checks on 2026-10-10 and authorised the local Rust commit and next Java unit. No exact enlargement size or contrast measurement is inferred. T06 remains in review while other accepted languages are pending. Nothing was pushed.

## Unit 11 Java highlighting

Bilal confirmed all five Rust manual checks and instructed “all manual tests are OK, commit and continue to next unit” on 2026-10-10, authorising Java. Accepted Rust was committed as `076098f859809b83220459cb5920354a41b16e24` before Java edits. Bilal subsequently confirmed all five Java manual checks on 2026-10-10, accepting this unit and authorising its local commit plus Python Unit 12. It covers the Java subset of A15, preserving A10 and single-window A31. No blocking product decision remains.

The focused `.java` scanner reuses the existing cancellable worker, token kinds, palette and native renderer. It colours reserved/contextual keywords, booleans/null, strings/characters, text blocks, comments and numeric forms. Unicode escapes translate before lexical scanning; mapped ranges colour the original source without replacing its text. Identifiers retain supplementary-letter and combining-mark boundaries.

The official [Java lexical structure](https://docs.oracle.com/javase/specs/jls/se26/html/jls-3.html) and [Character identifier rules](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/lang/Character.html#isJavaIdentifierStart(int)) inform the boundaries. Contextual keyword colours use the current set with local member context; this is approximate without a parser or Java-version inference. Ordinary strings/characters stop at CR/LF, text blocks require an opening newline and protect escaped quotes, and block comments do not nest. Invalid/incomplete source stays readable without compiler validation or execution.

### Executed Unit 11 checks

Environment reconfirmed: macOS 27.0.1 (26A434), Swift 6.4, SDK 27 and Node 26.1.0. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter JavaHighlightingTests` before routing | Seven compiling tests report 20 intentional red issues because `.java` returns no tokens. All seven pass after implementation. |
| Standard probe coverage | Nine focused tests pass, including contextual member names across comments, Unicode backslash eligibility, non-recursive translation, escaped surrogate/ignorable identifier boundaries and raw-source range preservation. No probe behaviour fix was required. |
| Large/incomplete boundaries | Exact 1 MiB repeated source and single strings/comments/text blocks, 100,000-digit numbers, long valid/malformed Unicode markers and supplementary-letter identifiers produce safe ordered ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 147 tests in 17 suites, with four existing deliberate test-gate known issues. |
| Final `node scripts/build-app.mjs` | Pass after the full suite and quitting the previous app. Plist validates; compiled and bundled SHA-256 both equal `c9d2846306a01fc8cb8f7735c4157103f3e0700a014b527d25e3582904e452d9`. Native launch and Java display pass. No source changes after final suite/build. Existing Command Line Tools search-path warnings only. |
| Whitespace and document checks | Pass: 139 local links/anchors across five maintained documents and thirteen Node snippets. The portable Java recipe runs separately; all five files match native fixtures byte for byte. |

Standard tighten precomputed the `non-sealed` spelling, retaining local scanner functions and the existing presentation pipeline. Standard probe verified escaped boundaries, contextual names and long inputs. No implementation blocker remains. Light prose tighten and evidence probe distinguish executed observations from pending manual outcomes. M2 is incomplete, so its milestone quality checkpoint is not due.

### Agent native observations for Unit 11

- Keywords/booleans/null display in purple, strings/characters/text blocks green, numbers orange and comments muted. Escaped quotes retain text-block colour; the raw `ret\u0075rn` spelling is coloured as a keyword. Font/wrapping are retained. The `.txt` twin has no residual colours.
- Whole Java source copied through Go to Folder matches exactly, including Unicode, indentation and trailing newline (490 UTF-16 units, 492 UTF-8 bytes). The sheet was cancelled. Typing and paste are rejected; preview source is unchanged.
- Exact 1 MiB Java loads with metadata; the native preview scrollbar moves from 0 to 1. No full-buffer accessibility byte count or large-file keyboard-scroll claim.
- Right Java supplies its preview/path. Left Java restores them; Command-clicking incomplete Java makes it primary with readable source and 64-byte metadata. Deselecting restores the previous primary; clear removes preview/path and retains right selection.
- Changing `enabled = true` to `enabled = "ok"` retains 492 bytes and timestamp `1700000000`. The old preview persists until Command-R, then displays green `"ok"`. Restoring from the plain twin and Refresh returns original source. Java/plain/right files match byte for byte. The app remains open with left Java focused, right Java selected and no sheet.
- Native accessibility exposes named preview source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard copy. Bilal confirmed the light/dark, enlargement, focus and VoiceOver manual checks; no contrast measurement or full accessibility audit is claimed.

### Unit 11 fixture additions

Use the Unit 1 fixture recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add the samples below, then Command-R. Open `left` and `right` in their corresponding panes. Inspect `61-highlight.java`, `62-java-fallback.txt`, `63-limit.java` and `64-incomplete.java`. Build/run instructions remain above. Inspect the files as source in PanePeek.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const java = [
  'package sample;', 'import java.util.List;', '',
  'public record Example(String name) {',
  '  public static String greet(String name) {',
  '    var message = "Hello 👀";',
  '    boolean enabled = true; // preview note',
  "    char initial = '\\u0052';",
  '    long number = 0xCAFE_BABEL;',
  '    double fraction = 0x1.fp3 + .25e+2;',
  '    var block = """',
  '        return "quoted" // still text',
  '        \\\""" protected delimiter',
  '        """;',
  '    /* outer /* ends here */',
  '    if (enabled) ret\\u0075rn message;',
  '    return null;',
  '  }', '}', ''
].join('\n');
const line = 'var name = "value"; // preview note\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/61-highlight.java', java], ['left/62-java-fallback.txt', java],
  ['left/63-limit.java', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/64-incomplete.java', 'class Example {\n  String text = """\nreturn "unfinished" // 👀\n'],
  ['right/right.java', java]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/61-highlight.java'), 1700000000, 1700000000);
JS
```

For Refresh, select `61-highlight.java`, replace `enabled = true` with `enabled = "ok"` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `62-java-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 11 manual review

- [x] Check Java keywords, Unicode identifier/escape boundaries and numbers.
- [x] Check strings, characters, text blocks, comments and incomplete source.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal accepted all five checks and authorised the Java local commit and next Python unit. T06 remains open for the remaining languages and Edit. Push, PR and merge are not authorised.

## Unit 12 Python highlighting

Bilal accepted all five Java manual checks and authorised its local commit plus the next Python unit on 2026-10-10. Java was committed as `8ee332b32005b337ec9e39577ae9961cb2fee782` before Python edits. Bilal subsequently confirmed all five Python checks on 2026-10-10, accepting this unit and authorising its local commit plus Markdown Unit 13. It covers the Python subset of A15, preserving A10 and single-window A31. No blocking product decision remains.

The focused `.py` scanner reuses the cancellable worker, palette, fonts and native renderer. It colours keywords, booleans/None, quoted/raw/byte/triple-quoted strings, comments and numbers. Formatted and template strings retain their containing string colour, protecting nested expression quotes/comments and format fields. Mixed recursion is bounded at 32; remaining pathological source retains string colour.

The official [Python lexical reference](https://docs.python.org/3/reference/lexical_analysis.html) informs quote, prefix, identifier and numeric boundaries. Current soft keywords use approximate lexical colours with local member context; there is no version inference or semantic parsing. Unicode identifier boundaries use XID properties without changing displayed source. Comments end at CR/LF; short strings recover at unescaped newlines and retain escaped line continuations. The existing UTF-8 preview policy applies regardless of encoding declarations. Source is never executed.

### Executed Unit 12 checks

Environment reconfirmed: macOS 27.0.1 (26A434), Swift 6.4, SDK 27 and Node 26.1.0. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter PythonHighlightingTests` before routing | Seven compiling tests report 17 intentional red issues because `.py` returns no tokens. All seven pass after implementation. |
| Standard probe coverage | Nine focused tests pass, including escaped braces, named Unicode escapes, raw/formatted/template prefixes, nested same-quote expressions/comments, format fields and member boundaries. No probe behaviour fix was required. |
| Large/incomplete boundaries | Exact 1 MiB repeated source and single strings/comments/fields, 100,000-digit valid/invalid numbers, supplementary identifiers and deep bracket/string nesting produce safe ordered ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 156 tests in 18 suites, with four existing deliberate test-gate known issues. |
| Final `node scripts/build-app.mjs` | Pass after the full suite and quitting the previous app. Plist validates; compiled and bundled SHA-256 both equal `da36e10d77546a05c12cbe92ef7ebc62b3e0951e819510a5180fca3b423beec7`. Native launch and Python display pass. No source changes after final suite/build. Existing Command Line Tools search-path warnings only. |
| Whitespace and document checks | Pass: 143 local links/anchors across five maintained documents and fourteen Node snippets. The portable Python recipe runs separately; all five files match native fixtures byte for byte. |

Standard tighten precomputed accepted string prefixes and retained focused local scanner functions. Standard probe checked nested boundaries and long inputs, with no implementation blocker remaining. Light prose tighten and evidence probe keep manual outcomes pending. M2 remains incomplete; its milestone quality checkpoint is not due.

### Agent native observations for Unit 12

- Keywords/booleans/None display purple, ordinary/raw/byte/triple/formatted/template strings green, numbers orange and comments muted. Nested same-quote expressions remain within green strings. Font and wrapping are retained. The `.txt` twin has no residual colours.
- Whole-source copy through Go to Folder matches exactly, including Unicode, indentation and trailing newline (479 UTF-16 units, 481 UTF-8 bytes). The sheet was cancelled. Typing and paste are rejected; source stays unchanged.
- Exact 1 MiB Python loads with 1,048,576-byte metadata. Scrolling the native preview area moves its scrollbar from 0 to 1. No full-buffer accessibility byte count or large-file keyboard-scroll claim.
- Right Python supplies its source/path; left restores them. Command-clicking incomplete Python makes it primary with readable source and 56-byte metadata. Deselecting restores the previous primary; clear removes preview/path while retaining right selection.
- Replacing `enabled = True` with `enabled = "ok"` retains 481 bytes and timestamp `1700000000`. The old preview remains until Command-R, then displays green `"ok"`. Restoring from the plain twin and Refresh returns original source. Python/plain/right twins match byte for byte. The app remains open with left Python focused, right Python selected and no sheet.
- Native accessibility exposes named source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard copy. Bilal confirmed the light/dark, enlargement, keyboard focus and VoiceOver manual checks. No contrast measurement or full accessibility audit is claimed.

### Unit 12 fixture additions

Use the Unit 1 recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open `left` and `right` in their corresponding panes. Inspect `65-highlight.py`, `66-python-fallback.txt`, `67-limit.py` and `68-incomplete.py` as source in PanePeek. Build/run instructions remain above.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const python = [
  '#!/usr/bin/env python3', 'from pathlib import Path', '',
  'async def greet(name):',
  '    enabled = True # preview note',
  '    message = "Hello 👀"',
  '    path = r"C:\\Users\\name"',
  "    payload = b'bytes\\x21'",
  '    number = 0xCAFE_BABE + .25e+2 + 42j',
  '    block = """return "quoted" # still text',
  'next line"""',
  '    formatted = f"Hello {data["name"]} {{literal}}"',
  "    width = f'{number!r:>{size}.{precision}f}'",
  '    template = t"Template {name}"',
  '    match name:',
  '        case _: return None',
  '    return message', ''
].join('\n');
const line = 'if True: return "value" # preview note\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/65-highlight.py', python], ['left/66-python-fallback.txt', python],
  ['left/67-limit.py', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/68-incomplete.py', 'def example():\n    text = f"""unfinished {name # } 👀\n'],
  ['right/right.py', python]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/65-highlight.py'), 1700000000, 1700000000);
JS
```

For Refresh, select `65-highlight.py`, replace `enabled = True` with `enabled = "ok"` in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `66-python-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 12 manual review

- [x] Check Python keywords, Unicode name boundaries and numbers.
- [x] Check ordinary/raw/byte/triple/formatted/template strings, comments and incomplete source.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal accepted all five checks and authorised the Python local commit and next Markdown unit. Python was committed as `45aff4dbfe7f9c1c9cf582542ec7f1122ecc09d1` before Markdown edits. T06 remains open for Markdown manual acceptance; Edit belongs to T07. Push, PR and merge are not authorised.


## Unit 13 Markdown highlighting

Bilal accepted all five Python checks and authorised its local commit plus the next Markdown unit on 2026-10-10. Python was committed as `45aff4dbfe7f9c1c9cf582542ec7f1122ecc09d1` before Markdown edits. This unit covers the Markdown Preview portion of A15, preserving A10 and single-window A31. Bilal subsequently confirmed all five Markdown manual checks on 2026-10-10, accepting this unit and authorising its local commit. All accepted Preview languages now have implemented and accepted representative coverage. Edit remains T07. No blocking product decision remains.

The focused `.md` scanner reuses the cancellable worker, palette, fonts and native renderer. It colours ATX/setext headings, emphasis/strong emphasis, inline/reference links, images, URI/email autolinks and inline/fenced code. Code retains one containing colour, including its delimiters and fence info; inner-language colouring is optional and omitted. Escaped markers, intraword underscores and unmatched inline delimiters remain plain. Unclosed fences retain code colour to EOF. Displayed Markdown remains exact source text.

The [CommonMark lexical reference](https://spec.commonmark.org/0.31.2/) informs marker, flanking and delimiter boundaries. This is approximate lexical presentation: top-level heading/fence structure, single-line link destinations/titles and simple reference definitions. Explicit reference syntax can colour without resolving its definition; shortcuts require a recognised definition. Nested block containers, indented code, raw HTML blocks and dialect extensions are not parsed. Link lookahead is bounded at 4,096 UTF-16 units and bracket/emphasis depth at 32. No conformance, rendering or content execution is claimed.

### Executed Unit 13 checks

Environment reconfirmed: macOS 27.0.1 (26A434), Swift 6.4, SDK 27 and Node 26.1.0. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter MarkdownHighlightingTests` before routing | Seven compiling tests report 11 intentional red issues because `.md` returns no tokens. All seven pass after implementation. |
| Standard tighten and probe | Tighten hoisted token-kind mapping and combined code/link traversal. Probe added reference-definition/shortcut, destination-code/escape/Unicode and long-input checks. One regression test reports one red issue for missing reference definitions/shortcuts; fixed, then all nine focused tests pass. |
| Large/incomplete boundaries | Exact 1 MiB repeated source and single code/emphasis/fence tokens, 100,000-character delimiter/bracket runs and deep incomplete text produce safe ordered ranges. No timing threshold or slow-volume guarantee. |
| Final `node scripts/test.mjs` | Pass: 165 tests in 19 suites, with four existing deliberate test-gate known issues. |
| Final `node scripts/build-app.mjs` | Pass after the full suite and quitting the previous app. Plist validates; compiled and bundled SHA-256 both equal `a0db3151a577e50e43343ec5be9b47d24758d6b93f1af6b7ed345e5055db5711`. Native launch and Markdown display pass. No source changes after final suite/build. Existing Command Line Tools search-path warnings only. |
| Whitespace and document checks | Pass: 147 prose links/anchors across five maintained documents and fifteen Node snippets. The portable Markdown recipe runs separately; all five files match native fixtures byte for byte. Code examples are excluded from prose-link checks. |

Standard code tighten followed by standard probe is complete. Light prose tighten and evidence probe distinguish agent observations from Bilal’s accepted manual outcomes and preserve separate publication/dependency gates. M2 remains incomplete; its milestone quality checkpoint is not due.

### Agent native observations for Unit 13

- ATX/setext headings, emphasis and links display purple; inline code and both backtick/tilde fences display green. Fence bodies protect apparent headings/links/emphasis. Escaped markers and intraword underscores stay plain. The incomplete sample shows its heading and unclosed fence with readable remaining source. Font and wrapping are retained; the `.txt` twin clears colours.
- Whole-source copy through Go to Folder matches exactly, including Unicode, spacing and trailing newline (445 UTF-16 units, 447 UTF-8 bytes). The sheet was cancelled. Typing and paste are rejected; source stays unchanged.
- Exact 1 MiB Markdown loads with 1,048,576-byte metadata. Native preview scrolling moves its scrollbar from 0 to 1. No full-buffer accessibility byte count or large-file keyboard-scroll claim.
- Right Markdown supplies its source/path; left restores them. Command-clicking incomplete Markdown makes it primary with readable source and 59-byte metadata. Deselecting restores the previous primary; clear removes preview/path while retaining right selection.
- Replacing the opening `#` with a space retains 447 bytes and timestamp `1700000000`. Old text remains until Command-R, then the first line becomes plain while other Markdown colours remain. Restoring from the plain twin and Refresh returns original source. Markdown/plain/right twins match byte for byte. The app remains open with left Markdown focused, right Markdown selected and no sheet.
- Native accessibility exposes named source, scrolling and separate metadata. Agent checks cover dark presentation and keyboard copy. Bilal subsequently confirmed the presented light/dark, enlargement, keyboard focus and VoiceOver check. No contrast measurement or full accessibility audit is claimed.

### Unit 13 fixture additions

Use the Unit 1 recipe and export its printed `PANEPEEK_T06_FIXTURE` assignment. Add these samples, then Command-R. Open `left` and `right` in their corresponding panes. Inspect `69-highlight.md`, `70-markdown-fallback.txt`, `71-limit.md` and `72-incomplete.md` as source in PanePeek. Build/run instructions remain above.

```sh
node --input-type=module <<'JS'
import { writeFileSync, utimesSync } from 'node:fs';
import { join } from 'node:path';
const root = process.env.PANEPEEK_T06_FIXTURE;
const markdown = [
  '# PanePeek 👀', '',
  'Setext heading', '==============', '',
  'Plain text with *italic*, **bold**, _emphasis_ and ***both***.',
  'Inline `const value = "text";` and ``one ` two``.',
  '[Guide](https://example.test/a(b) "Guide") and ![Image](image.png).',
  '[Read Me] and [label][read me] and <hello@example.test>.', '',
  '[Read Me]: /guide.md "Read me"', '',
  '```swift', 'let value = "inside" // **literal**', '```', '',
  '~~~ text', '# still code [link](url)', '~~~', '',
  '\\*escaped\\* and snake_case stay plain.', ''
].join('\n');
const line = '**bold** `code` [link](url)\n\n';
const limit = 1_048_576;
for (const [name, text] of [
  ['left/69-highlight.md', markdown], ['left/70-markdown-fallback.txt', markdown],
  ['left/71-limit.md', line.repeat(Math.ceil(limit / line.length)).slice(0, limit)],
  ['left/72-incomplete.md', '# Partial 👀\n\n*unclosed [link](\n\n```swift\n**still code**\n'],
  ['right/right.md', markdown]
]) {
  writeFileSync(join(root, name), text);
}
utimesSync(join(root, 'left/69-highlight.md'), 1700000000, 1700000000);
JS
```

For Refresh, select `69-highlight.md`, replace the opening `#` with a space in this disposable fixture and retain timestamp `1700000000`. Command-R should update text and colours. Restore from `70-markdown-fallback.txt`, reset the timestamp and Refresh afterward.

### Bilal’s Unit 13 manual review

- [x] Check ATX/setext headings, emphasis, escaped markers and links.
- [x] Check inline/backtick/tilde code, protected fence contents and incomplete source.
- [x] Check font, whole-source copy, rejected editing and large-file scrolling.
- [x] Check pane switching, primary selection, clear, plain fallback and Refresh.
- [x] Check light/dark appearance, enlarged text, keyboard focus and VoiceOver.

Bilal confirmed all five checks on 2026-10-10 and authorised the local Markdown commit and next-unit continuation. No exact enlargement size or contrast measurement is inferred. T06 implementation/manual review is complete; A15 remains partial for Edit in T07 and M2 remains incomplete. Live `main` is `44872b0`, and the T06 branch is unpublished. Publication and merge are separately gated before T07 starts.

The acceptance-only documentation update and proposed [future rendered Markdown preview](../notes/0006-rendered-markdown-preview.md) change no shipped behaviour. Light tighten then evidence probe preserve the current source-text requirement and distinguish acceptance from publication. Existing final code/build evidence above remains applicable.

Acceptance documentation checks pass: seven maintained documents, 147 local prose links/anchors, fifteen Node snippets and five byte-identical portable recipe files. Whitespace passes; compiled and bundled hashes still match the accepted final build. No production code changed during acceptance recording.
