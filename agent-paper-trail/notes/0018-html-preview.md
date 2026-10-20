# Static HTML preview

Status: Active

HTML Preview uses the current UTF-8 / 1 MiB draft, with the native source editor retained underneath for Preview/Edit and Save/Undo identity. Render `.html` and `.htm` through a nonpersistent WebKit view with content JavaScript disabled. Source editing remains available when rendering fails.

Install a compiled content rule list before loading any source: block resource URLs by default, permitting data URLs and the app-owned resource scheme. Prepend a trusted Content Security Policy before source markup; allow inline/data styles, app-mediated CSS/images/fonts and existing data media, while blocking scripts, frames, objects, connections, base URLs and form submission. Policy preparation failure shows an unavailable state. The renderer receives a generated origin without the original file URL or a filesystem grant.

The [local asset policy](../decisions/2026-10-20-html-local-assets.md) confines CSS, images and fonts to the HTML file's containing folder and subfolders. CSS imports and relative image/font URLs use that same root. Retain an opened directory descriptor and its folder grant, reject symbolic links in every path component and read bounded regular files off the UI thread. Limit assets to 8 MiB each, 32 MiB total and 128 requests per preview; unavailable assets remain missing. Linked HTML navigation and local media playback are excluded.

Navigation policy permits only the initial generated document and deliberate same-document fragment links. Deliberate HTTP/HTTPS links open outside the inline viewer; automatic navigation, form submissions, other schemes and web popups are cancelled. Disable link previews and require user action for embedded media playback.

Latest-request ownership covers asynchronous policy preparation and navigation. Cancelled/obsolete work cannot publish a web view or error; navigation has a ten-second deadline. Stop and release content on replacement or disappearance, and key the native bridge by web-view identity so coalesced draft updates cannot keep the previous native view.

The [HTML criterion](../specs/001-mvp/spec.md#additional-file-previews) and [task evidence](../specs/001-mvp/evidence/html-preview.md) own acceptance. WebKit's [content blocker format](https://webkit.org/blog/3476/content-blockers-first-look/) and Apple's [content JavaScript setting](https://developer.apple.com/documentation/webkit/wkwebpagepreferences/allowscontentjavascript) describe the underlying boundaries.

Sandbox builds require the [WebKit network-client capability](../decisions/2026-10-20-webkit-sandbox-capability.md) even for local rendering. Resource policies enforce offline preview behaviour; the OS entitlement permits outgoing connections.
