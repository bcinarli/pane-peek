# Privacy

Last updated: 24 October 2026

PanePeek is a local macOS file browser and inline text editor. File contents and paths stay on your Mac. GitHub-distributed builds can contact GitHub only for the update checks and requested downloads described below. The app has no accounts, advertising, analytics or app-operated crash-reporting service.

## Files and previews

PanePeek reads directory entries, file metadata and selected file contents to provide browsing, previews and editing. File operations, including saving edits, act on the locations selected in the app. macOS controls permission to protected locations.

Text and Markdown previews are processed on your Mac. Rendered Markdown does not automatically load embedded images; it shows their descriptions as links. Image and video previews use macOS frameworks, and Quick Look passes selected file URLs to the system preview service.

SVG previews are decoded locally into static images. SVG scripts and external resources remain inactive; the decoder receives the source text without access to the original file location.

PDF previews are read locally into a read-only native viewer. Forms cannot be edited, and the inline viewer does not open document links or companion files.

HTML previews use a nonpersistent local web view with scripts and remote resource loads disabled. PanePeek reads bounded local CSS, images and fonts from the HTML file's folder and subfolders, rejecting symbolic links and paths outside that folder. The renderer receives a generated local origin without direct filesystem access. Deliberately opening an HTTP/HTTPS link passes that link to your default browser, which can make network requests under its own privacy settings.

Sandbox builds include outgoing-network permission because WebKit requires it to start even for local SVG/HTML content. Preview resource policies enforce these restrictions; the OS permission itself permits outgoing connections.

Folders visible in macOS can be backed by iCloud, another cloud provider or a mounted network volume. Accessing or changing those files can cause that provider or macOS to download, upload or synchronise data. PanePeek does not manage those services.

## GitHub update checks and downloads

In GitHub-distributed builds, Check for Updates contacts `api.github.com` for public release information. Choosing Download requests the DMG from `github.com`, which redirects the download to `release-assets.githubusercontent.com`. Mac App Store builds do not run or expose this updater.

Automatically Check for Updates is off by default. When enabled in the app menu, it checks at most daily while PanePeek is running; downloads still require choosing Download. The preference, last-attempt time, reminder postponement and skipped release are saved locally.

Update requests use fixed headers and send no file contents, paths, installed version, identifiers, device or system profile, locale, cookies or credentials. GitHub and its download infrastructure necessarily receive your IP address, connection information and request timing under [GitHub’s Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). Online checks cannot provide zero third-party processing.

Downloads stream to bounded local app storage. PanePeek verifies the download and publisher signature, retains quarantine and asks macOS to open the DMG for manual installation. It does not replace itself or quit automatically. macOS trust and installation services operate under their own settings. Completed installers are retained for reopening; failed and cancelled partial downloads are removed.

## Saved settings and drafts

PanePeek stores favourite folder paths and the most recently active window's directories and layout in local macOS preferences. These settings include absolute folder paths and persist between launches. Favourites can be removed in the app; remembered directories and layout update as you use it.

Unsaved text edits and undo history are held in memory. PanePeek does not restore unsaved drafts after quitting. Saved documents remain in their selected filesystem locations.

## Clipboard and sharing

Path-copy actions place paths on the macOS clipboard. Copying or cutting selected files places their file URLs on the clipboard; Paste and Move Item Here read clipboard file URLs to transfer files into the selected browser folder. Pending Cut move intent is held only in app memory for the matching clipboard contents. Text editing and file drag and drop also use macOS clipboard and pasteboard services. Other apps and clipboard tools may access this data, and system settings can allow clipboard synchronisation between devices.

PanePeek does not upload documents or send paths to AI services. If you paste a path or text, or upload a document in another app, that app or service handles what you share under its own privacy terms.

## Links and system services

Following a link in a preview can open your browser or another application. That destination may receive the URL and normal connection information. macOS preview services, backups and system diagnostics operate under your system settings and their own privacy practices.

Apple can share app analytics and crash reports through its optional services. Your Mac’s sharing settings control what Apple shares; see [Apple’s analytics guide](https://support.apple.com/guide/mac-help/mh27990/mac). If you download PanePeek from the Mac App Store, Apple also handles the download and any purchase.

## Website

Cloudflare hosts [panepeek.app](https://panepeek.app) and processes technical request information, including your IP address, to deliver and protect the website. See [Cloudflare’s Privacy Policy](https://www.cloudflare.com/privacypolicy/) for details.

The website saves your theme choice in your browser. Choose System to follow your device’s theme and clear the saved choice.

## Support and privacy questions

Bilal Cinarli receives your email address and what you choose to include in messages or attachments sent to [support@panepeek.app](mailto:support@panepeek.app?subject=PanePeek%20privacy). These details are used to reply and investigate the issue. Apple’s iCloud Mail handles support emails under [Apple’s Privacy Policy](https://www.apple.com/legal/privacy/en-ww/).

Support emails and attachments are deleted three months after receipt. You can email the same address to ask about your personal information or request earlier deletion.

You can also [open an issue in the PanePeek repository](https://github.com/bcinarli/pane-peek/issues). Information submitted there is handled by GitHub and visible to people with access to the issue. The email retention period does not apply to GitHub Issues. Keep private documents and sensitive paths out of reports.

## Changes to this policy

This policy is updated when PanePeek’s privacy practices change. The date at the top shows the latest version.
