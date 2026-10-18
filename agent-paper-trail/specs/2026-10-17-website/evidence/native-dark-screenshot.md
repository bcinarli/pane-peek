---
task: native-dark-screenshot
verdict: Passed
closed: 2026-10-18
---

# Native Macchiato and light screenshots

## Capture provenance

2026-10-18: Native captures use PanePeek 0.1.0 (build 3), from source snapshot `396807c` plus working-tree control changes following Macchiato commit `61cc1b1`. The packaged executable was reused without rebuilding; both isolated capture copies matched SHA-256 `7820c22a661d6509e07bbb38225a193a5410dfcbf37b2a7f7f612ae323135655`. Bundle identifiers/preferences were isolated; Light was forced only in its copied bundle. Native source and global appearance were unchanged.

| Asset | Native state | Dimensions |
| --- | --- | --- |
| `app-browse-dark.png` | Two folders and a rendered Markdown preview in Macchiato | 2436 × 1460 |
| `app-edit-dark.png` | One folder and expanded Details with an unsaved Markdown draft in Macchiato | 2436 × 1460 |
| `app-edit-light.png` | One folder and expanded Details showing Markdown source in native Light | 2200 × 1300 |

Only fictional shared demo files were captured. The research file remained unchanged after the in-memory edit; no Save action was used. Both capture copies were quit afterwards. Original JPEGs retain unchanged capture bytes. Served PNGs have local cursor/glow cleanup as described below. CSS still omits the 104-pixel title bar containing the light capture’s system control badge; full-size links open the cursor-free PNGs. Final release screenshot selection remains separate.

The light hero and logo remain unchanged [design-source copies](../../../design/001-mvp/README.md). The light hero retains its illustrative label. The old illustrative dark asset is retained unused; native editing images are identified as sample-file captures.

## Website checks

2026-10-18, agent-observed: The actual system-dark page selects the native dark hero. Paired CSS appearance fixtures select the light hero in Latte and dark hero in Macchiato; both editing images remain visible in either theme. Both themes reflow without horizontal overflow at 1280, 851, 850 and 320 pixels; the comparison stacks at 850. Loaded images and native full-size dimensions match the table; all four full-size destinations were opened successfully.

Keyboard traversal skips the hidden hero, follows hero → dark editor → light editor, and works in reverse. Focus is a visible 3-pixel outline in both themes. Image alternatives, intrinsic dimensions, lazy loading and captions are present. All 73 HTML references/fragments resolve; no JavaScript or remote runtime dependencies were added. Browser warning/error logs are empty. VoiceOver, actual browser zoom and actual system-appearance switching remain unexecuted.

Tighten keeps one shared static gallery and theme-specific hero links so each full-size destination matches its image. Probe covers hidden-link focus, retained light imagery, loaded assets, narrow reflow, title-bar crop and capture provenance. Native app tests/build were not rerun because app code was unchanged. Final verification: 131 local Markdown targets resolve; three original design assets and all three retained native JPEG sources match their originals byte for byte. Privacy/path checks on 25 changed files, Gitleaks and whitespace pass. Home, Support, Privacy and CSS respond HTTP 200.

## Cursor cleanup

2026-10-18: Only the rectangle `(320, 0)` to `(480, 104)` was replaced with matching title-bar pixels from the same isolated native app in the same appearance/window geometry, with its cursor positioned elsewhere. No generated imagery was used. Lossless PNG exports retain 2436 × 1460 for the dark images and 2200 × 1300 for Light.

Decoded RGB comparisons found zero changed pixels outside that rectangle in each PNG. All app content below the title bar is identical to its JPEG source. Magnified dark/light title-bar inspection confirms removal of the cursor and glow with the title retained. The original JPEGs remain unused sources; full-size links and inline images use the cleaned PNGs. All three cleaned full-size PNG destinations were opened in the browser and loaded at their native dimensions. The homepage uses the new PNGs, retains both editing appearances and has no horizontal overflow; browser warning/error logs are empty. Existing layout/CSS and image dimensions are unchanged. All 73 HTML references and 131 Markdown target paths resolve; 28-file privacy/path checks, Gitleaks and whitespace pass.

Tighten retains the existing layout and CSS. Probe checks the actual exported PNGs, their dimensions, bounded pixel differences and full-size destinations rather than relying on the edit operation alone.
