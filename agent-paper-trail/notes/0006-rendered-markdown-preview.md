# Rendered Markdown scope

Status: Active

The [accepted preview scope](../decisions/2026-10-20-additional-file-previews.md) and [A36](../specs/001-mvp/spec.md#additional-file-previews) govern rendered Markdown and highlighted YAML front matter. Acceptance is tracked in [validation](../specs/001-mvp/validation.md#additional-file-previews).

Foundation Markdown parsing treats front-matter delimiters as Markdown structure. Extract only a leading, closed metadata block before parsing the body and render it as literal attributed text with the existing YAML highlighter. Delimiter detection must retain internal indentation/newlines and leave unclosed blocks, later thematic breaks and fenced code to Markdown parsing.

Keep the native source editor alive beneath rendered Preview so switching modes retains selection and undo. Render the current draft without changing source bytes or implicitly saving. Raw HTML remains literal; images remain descriptions without fetching resources. Links and image descriptions open only HTTP/HTTPS targets with a host; other targets remain plain text. Native text presentation does not promise browser-equivalent Markdown layout.
