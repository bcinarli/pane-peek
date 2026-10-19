# Privacy

Last updated: 19 October 2026

PanePeek is a local macOS file browser and inline text editor. It does not send your file contents, paths or usage information to Bilal Cinarli or an app-operated service. The app has no accounts, advertising, analytics or app-operated crash-reporting service.

## Files and previews

PanePeek reads directory entries, file metadata and selected file contents to provide browsing, previews and editing. File operations, including saving edits, act on the locations selected in the app. macOS controls permission to protected locations.

Text and Markdown previews are processed on your Mac. Rendered Markdown does not automatically load embedded images; it shows their descriptions as links. Image and video previews use macOS frameworks, and Quick Look passes selected file URLs to the system preview service.

Folders visible in macOS can be backed by iCloud, another cloud provider or a mounted network volume. Accessing or changing those files can cause that provider or macOS to download, upload or synchronise data. PanePeek does not manage those services.

## Saved settings and drafts

PanePeek stores favourite folder paths and the most recently active window's directories and layout in local macOS preferences. These settings include absolute folder paths and persist between launches. Favourites can be removed in the app; remembered directories and layout update as you use it.

Unsaved text edits and undo history are held in memory. PanePeek does not restore unsaved drafts after quitting. Saved documents remain in their selected filesystem locations.

## Clipboard and sharing

Path-copy actions place paths on the macOS clipboard. Copying or cutting selected files places their file URLs on the clipboard; Paste and Move Item Here read clipboard file URLs to transfer files into the selected browser folder. Pending Cut move intent is held only in app memory for the matching clipboard contents. Text editing and file drag and drop also use macOS clipboard and pasteboard services. Other apps and clipboard tools may access this data, and system settings can allow clipboard synchronisation between devices.

PanePeek does not upload documents or send paths to AI services. If you paste a path or text, or upload a document in another app, that app or service handles what you share under its own privacy terms.

## Links and system services

Following a link in a preview can open your browser or another application. That destination may receive the URL and normal connection information. macOS preview services, backups and system diagnostics operate under your system settings and their own privacy practices.

## Questions

For privacy questions, [open an issue in the PanePeek repository](https://github.com/bcinarli/pane-peek/issues). Information submitted there is handled by GitHub and visible to people with access to the issue. Keep private documents and sensitive paths out of reports.
