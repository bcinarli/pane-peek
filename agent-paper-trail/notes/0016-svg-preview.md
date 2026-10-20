# SVG preview

Status: Active

SVG follows the text pipeline so its current draft, source highlighting and save safeguards share the existing editor. The UTF-8 / 1 MiB limit applies to both preview and source editing; symbolic links retain read-only source access.

Decode SVG as a base64 data-URL image in WebKit with content JavaScript disabled, a nonpersistent data store and a restrictive content policy. Keep the original file URL out of the decoder. The [SVG image processing mode](https://www.w3.org/TR/SVG/conform.html) keeps source scripts and referenced resources inactive; permitted navigation is limited to the generated blank document.

App-owned rasterisation runs in an isolated content world and returns a static PNG with a maximum 2048-pixel side. Release the decoder after completion, failure, cancellation or the ten-second deadline. Obsolete results cannot replace the current preview. The source editor remains alive beneath the image presentation so mode changes retain Undo.

Preserve the image element's intrinsic SVG viewport during rasterisation. Forcing it to a square changes the internal viewport and distorts shapes even when the output bitmap has the expected aspect ratio.

Rendering reflects the decoded image at snapshot time; animation playback and controls are outside scope. Features that cannot be decoded or copied to a canvas show an unavailable state while eligible source editing remains available. The [SVG criterion](../specs/001-mvp/spec.md#additional-file-previews) and [task evidence](../specs/001-mvp/evidence/svg-preview-source-editing.md) own acceptance.
