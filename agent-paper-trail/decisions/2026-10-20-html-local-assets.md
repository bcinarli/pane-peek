---
status: Accepted
date: 2026-10-20
supersedes: []
superseded_by: ""
---
# Local assets in HTML preview

## Decision and rationale

Extend static HTML preview to CSS, images and fonts in the selected HTML file's containing folder and subfolders. Resolve stylesheet imports and CSS-relative image/font URLs within that same boundary. Retain inline styles and data resources, current-draft rendering and the existing source editor.

Serve approved resources through an app-owned URL scheme. Open the containing directory once, read relative to its descriptor off the UI thread and reject symbolic links in every resource path component. Keep the folder grant alive through resource loading and pending reads. WebKit receives a generated origin, without the original file URL or a filesystem grant. Absolute file URLs, remote URLs and paths outside the opened directory are unavailable.

Limit each local asset to 8 MiB and each preview to 32 MiB across at most 128 local asset requests. Read regular files only, without blocking on special files. Missing, unsupported or over-limit assets remain unavailable. Source editing retains its UTF-8 / 1 MiB limit.

## Boundaries and alternatives

Keep content JavaScript disabled and install the resource blocker and Content Security Policy before source markup. Scripts, remote requests, frames, objects, form submission and automatic navigation remain blocked. Only deliberate HTTP/HTTPS links open externally; linked HTML pages do not navigate within the preview. Local media playback is outside this extension. Document-supplied base URLs cannot change the asset root.

Granting WebKit direct directory access would make containment and resource limits harder to enforce. Embedding every asset into rewritten HTML/CSS would require parsing and rewriting nested URLs and stylesheets. A bounded scheme handler preserves browser-relative URL behaviour while keeping file reads under app control. The [WebKit sandbox capability](2026-10-20-webkit-sandbox-capability.md) remains required; offline behaviour is enforced by preview policies.
