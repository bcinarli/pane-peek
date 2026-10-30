# PanePeek notes

| Note | Status | Scope |
| --- | --- | --- |
| [2026-10-30 Code-quality analysis](2026-10-30-code-quality-analysis.md) | Proposed | Nine findings on workload, ownership, preview boundaries, test coordination and bundle metadata; linked cluster plan. |
| [0016 SVG preview](0016-svg-preview.md) | Active | Inert image decoding, static snapshots, source editing and resource limits. |
| [0017 PDF preview](0017-pdf-preview.md) | Active | Bounded background loading, native fit/zoom, inactive forms/actions and document cleanup. |
| [0018 HTML preview](0018-html-preview.md) | Active | Self-contained rendering, policy-before-source/resource blocking, deliberate links and native editor identity. |
| [0001 Build and bundle](0001-build-and-bundle.md) | Active | Directory naming, CLT support, development icon and generated-executable recovery. |
| [0002 Directory navigation and breadcrumbs](0002-directory-navigation.md) | Active | Canonical links, child URL identity, scrolling and native keyboard focus. |
| [0003 Listing and pane state](0003-listing-and-pane-state.md) | Active | Link metadata, relative dates, background sorting, selection/context targeting and copied paths, hidden visibility, Refresh and bounded preview. |
| [0004 Protected-folder permission requests](0004-protected-folder-permissions.md) | Active | Observed consent prompts and the unresolved startup/denied-access follow-up. |
| [0005 Details width follow-up](0005-details-width-follow-up.md) | Superseded | Superseded by the accepted layout decision; native implementation belongs to T19. |
| [0006 Rendered Markdown preview](0006-rendered-markdown-preview.md) | Active | Native rendering, literal YAML front matter and source/draft/resource boundaries. |
| [0007 Native Details sizing](0007-native-details-sizing.md) | Active | Native bounds, preferred-width capture, browser identity and retained list/editor scroll. |
| [0008 Item creation](0008-item-creation.md) | Active | Exclusive creation, literal names, dot-file visibility, captured targeting and guarded result refresh. |
| [0009 Item rename](0009-item-rename.md) | Active | Exclusive rename, source/link identity, deferred Discard, saved baselines and directory/preview recovery. |
| [0010 Item copy](0010-item-copy.md) | Active | Captured identities, link/ancestry preflight, incomplete destinations and draft-preserving copy refresh. |
| [0011 Item move](0011-item-move.md) | Active | Exclusive move, private cross-volume staging, failure/cleanup outcomes and preview/directory recovery. |
| [0012 Item Trash](0012-item-trash.md) | Active | Listed-link identity, deferred Discard, source-removal outcomes and accessible-parent recovery. |
| [0013 Drag and drop](0013-drag-and-drop.md) | Active | Whole payload/source capture, dirty drag retry, source locks, operation permissions and unlisted move recovery. |
| [0014 Window lifecycle and prompts](0014-window-lifecycle.md) | Active | Owning-window sheets/announcements, lifecycle cleanup, deferred Quit discards and byte-exact draft revalidation. |
| [0015 Shared operation coordination](0015-shared-operation-coordination.md) | Active | Shared mutation/Save/drag guards, native registration timing, all-window pane/path recovery and actual-removal preview closure. |
| [App Store sandbox and file access](2026-10-20-app-store-sandbox-design.md) | Active | Folder grants, saved-access design and sandbox compatibility limits. |

Record durable implementation gotchas in focused note files and link them here. Reuse a related note when the topic fits; keep this README as the index. Decisions belong in [decisions](../decisions/README.md), and requirements and filesystem/Finder limitations belong in [the spec](../specs/001-mvp/spec.md).

Keep environment setup observations and private session details outside the repository. Record only facts that change how future project work should proceed.
