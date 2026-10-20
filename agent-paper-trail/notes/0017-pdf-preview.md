# PDF preview

Status: Active

PDF uses a separate read-only Details path, with native continuous page scrolling, zoom and automatic Fit Width. It does not enter the text editor or expose Save. System Quick Look remains independent.

Read regular local files through a nonblocking descriptor with a 32 MiB cap. Parse in a serial background actor, then transfer the document to the UI without sharing mutable PDFKit objects across actors. Limit presentation to 500 pages with finite, positive media/crop boxes no larger than 14,400 points per side. Native parsing is synchronous and cannot be interrupted mid-call; cancellation checks between operations and selection ownership prevent stale publication.

Retain the selection's folder grant through pending reads, including cancellation and selection replacement. Sandbox review rejects listed file links and uses no-follow descriptor opening to reject a path replaced by a link.

Create the PDF document from bytes, without its original file URL. Preserve visible annotations while removing their actions, additional actions and direct link destinations; widget fields are read-only. Clearing an action does not clear a separately stored destination. `PDFAnnotation.type` reports `Widget` without the slash present in `PDFAnnotationSubtype.widget.rawValue`. The inline viewer suppresses external-link and remote-document opening and has no write path.

Keep continuous display mode when using PDFKit automatic scaling: it fits width in continuous mode and fits the whole page in non-continuous mode. Re-presenting the same document retains its page and zoom. Selection replacement, view removal and window closure release the displayed document.

The [PDF criterion](../specs/001-mvp/spec.md#additional-file-previews) and [task evidence](../specs/001-mvp/evidence/pdf-preview.md) own acceptance.
