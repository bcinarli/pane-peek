# Using PanePeek

## Start browsing

Use Go to Folder to enter a folder's full path. Home opens your home folder; folder names above the file list take you back to a parent folder. Double-click a folder to open it, or select a file to preview it in Details.

Command-click adds or removes items from the selection. Shift-click selects a range. Click Name, Size or Modified to sort; click again to reverse the order. Use View to show hidden files or refresh a pane.

## Preview documents

Details shows the main selected file's preview, full path and file information. Preview shows formatted Markdown; Edit shows its source text. Markdown images appear as description links and aren't loaded automatically.

Images and videos are read-only. Videos start paused and stop when you change the selection or close the preview.

Press Space from the file list to open macOS Quick Look, including PDFs and other supported formats. Escape closes it. Quick Look shows the saved file, while unsaved edits stay in Details.

## Edit and save

Choose Edit to change a text file, then click Save to write your changes. Switching to Preview keeps your unsaved edits and shows your Markdown changes.

Unsaved appears beside the filename until you save or discard your edits. Actions that affect unsaved edits ask you to Save, Discard or Cancel. Cancel stops the action and keeps your edits. A failed Save also keeps your edits open.

If PanePeek detects an outside change or a missing file, Save stops and keeps your edits. Avoid editing the same file in another app at the same time.

File links are read-only. Open the file they point to if you want to edit it.

![An inline Markdown edit in dark appearance, with Unsaved beside the filename and Save available.](screenshots/inline-editing-dark.png)

## Sharing with AI agents

The copy button beside the path in Details copies that path. For several files, select them and choose Copy Absolute Path or Copy Relative Path from the Edit or right-click menu. Paths are copied as plain text, one per line in list order. File links use the link's path.

For a file in the fictional folder `/Users/demo/Documents/Project`:

```text
Absolute: /Users/demo/Documents/Project/project-brief.md
Relative: project-brief.md
```

Use Go → Copy Directory Path to copy the open folder's path.

A path works when the agent can read the same filesystem. For a chat that can't access your Mac, upload the file or paste its contents. PanePeek does not send files or paths to an AI service.

![The file's right-click menu, with Copy Absolute Path and Copy Relative Path.](screenshots/copy-path-menu.png)

## Arrange the window

Use One Pane / Two Panes in the toolbar or View menu. One Pane keeps the folder you're using. Switching back brings the other folder back on the right.

Drag the divider beside Details to resize it. Expand Details gives you a larger preview; Restore Previous Details Width returns to your chosen width.

## Create, rename and organise files

Choose New Text File or New Folder from the File menu. Include an extension if you want one. Names starting with a dot turn on Show Hidden Files in that pane.

Rename an item from its right-click menu, or double-click a file. Return confirms; Escape cancels.

With two panes open, choose Copy to Other Pane or Move to Other Pane from the right-click menu. The destination is the folder that was open in the other pane when you started.

Copy and Move offer Keep Both or Cancel for name clashes, with Replace also available for regular files. Keep Both suggests an unused name that you can edit. The actions appear in one horizontal row. Folders, packages and links aren't merged or replaced.

Move to Trash sends selected items to Trash. If this fails, PanePeek reports an error instead of deleting them permanently.

Drag files from Finder into a pane to copy them; hold Command to request a move when allowed. You can also drag selected rows between panes or into Finder. If PanePeek asks about unsaved edits before dragging out, choose Save or Discard, then drag again. Refresh after Finder changes files.

If a transfer fails partway through, completed files stay in place. Check the error details and destination before trying again: a failed copy can leave an incomplete file.

Use Reveal in Finder to open a folder or locate a file in Finder.

## Favourites

Click the star beside the folder path to save or remove it. Favourites are shared across panes and windows, and stay saved after quitting.

Use the toolbar Favourites button to search, open or remove saved folders. The menu-bar Favourites menu offers opening and removal too.

## Windows and reopening

File → New Window opens a separate window with its own folders and unsaved edits.

When you reopen PanePeek, it restores the last active window's folders and layout. Selections, sorting, hidden-file settings and unsaved edits aren't restored.

## About and privacy

PanePeek → About PanePeek shows the version and build number. Select the version text and press Command-C to copy it for a report. Privacy and Acknowledgements open local documents you can read offline.

See the [privacy policy](../PRIVACY.md) for file access and local storage details.

## Keyboard shortcuts

Shortcuts use the active pane unless you're typing in the editor or a dialog.

| Action | Shortcut |
| --- | --- |
| Go to Folder | Command-L |
| Enclosing Folder | Command-Up |
| Open selected folder | Command-Down |
| Select all visible rows | Command-A |
| Show hidden files | Command-Shift-period |
| Refresh | Command-R |
| Quick Look | Space |
| Copy absolute paths | Command-Option-C |
| Copy relative paths | Command-Option-Shift-C |
| Rename selected item | Return or Command-Shift-R |
| New Text File | Command-Option-N |
| New Folder | Command-Shift-N |
| Save | Command-S |
| Undo / Redo | Command-Z / Command-Shift-Z |
| Details wider / narrower | Control-Command-Left / Right |
| Open file's right-click menu | Shift-F10 (Fn may be needed) |
| Cancel rename, close Quick Look or clear list selection | Escape |

## Formats and limits

| Content | Current support |
| --- | --- |
| Text and inline editing | UTF-8 files up to 1 MiB. |
| Images | Formats supported by macOS, up to 32 MiB and 64 million pixels. Animations show a still frame. |
| Video | Local videos that contain their own media and are supported by macOS. Protected and audio-only files aren't previewed. |
| Other documents | File information and Quick Look where macOS supports the format. |
| Folders and packages | File information without folder size totals. Packages are treated as files. |

Syntax highlighting covers common code and config files, including Swift, JSON, JavaScript/TypeScript and Python. Other UTF-8 text is still editable. HTML is shown as source and isn't run.
