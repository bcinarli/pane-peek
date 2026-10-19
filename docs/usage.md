# Using PanePeek

## Start browsing

Use Go to Folder to enter a folder's full path. Home opens your home folder. Click a folder name above the file list to return to a parent folder, or double-click a folder in the list to open it. Select a file to preview it in Details.

`⌘`-click adds or removes items from the selection. `⇧`-click selects a range. Click a column heading to sort by Name, Size or Modified; click it again to reverse the order. Use View to show hidden files or refresh the active pane.

![A project folder in light appearance, with its selected Markdown file shown in Details.](screenshots/browse-preview-light.png)

## Preview documents

Details shows the main selected file's preview and information, including its full path. For Markdown, Preview shows formatted text and Edit shows the source. Markdown images appear as description links; open a link to view its image separately.

Images and videos have read-only previews. Videos start paused and stop when you change the selection or close the preview.

Press `Space` from the file list to open macOS Quick Look, including PDFs and other supported formats. `Escape` closes it. Quick Look shows the saved file. Unsaved edits stay in Details.

## Edit and save

Choose Edit to change a text file, then click Save to write your changes. Switching to Preview keeps your edits and shows the current Markdown text.

Unsaved appears beside the filename until you save or discard your edits. Actions that affect those edits ask how to handle them. Save writes the changes; Discard closes them. Cancel stops the action and keeps your edits open. Your edits also stay open if Save fails.

If another app changes or removes the file, PanePeek pauses saving and keeps your edits. Keep one app responsible for editing a file at a time.

File links have read-only previews. Open the file they point to when you want to edit it.

![An unsaved Markdown edit in the Macchiato dark appearance, with Save available.](screenshots/inline-editing-dark.png)

## Sharing with AI agents

The copy button beside the path in Details copies that path. For several files, select them and choose Copy Absolute Path or Copy Relative Path from the Edit or right-click menu. Paths are copied as plain text, one per line in list order. A file link uses the link's own path.

The screenshots use the sample folder `/Users/Shared/PanePeek Demo/Project`:

```text
Absolute: /Users/Shared/PanePeek Demo/Project/project-brief.md
Relative: project-brief.md
```

Use Go → Copy Directory Path to copy the open folder's path.

Paste a path into an agent that can read the same filesystem. For a chat with access through uploads, attach the file or paste its contents. You choose what to share in the receiving app; PanePeek works locally.

![The selected file's right-click menu, with Copy Absolute Path and Copy Relative Path.](screenshots/copy-path-menu.png)

## Arrange the window

Use One Pane / Two Panes in the toolbar or View menu. One Pane keeps the folder you're using. Switching back brings the other folder back on the right.

Drag the divider beside Details to resize it. Expand Details gives you a larger preview; Restore Previous Width returns to your chosen width.

## Create, rename and organise files

Choose New Text File or New Folder from the File menu. Include an extension if you want one. Names starting with a dot turn on Show Hidden Files in that pane.

Rename an item from its right-click menu, or double-click a file. `Return` confirms the new name; `Escape` cancels.

With two panes open, choose Copy to Other Pane or Move to Other Pane from the right-click menu. The destination is the folder that was open in the other pane when you started.

When a name is already in use, Keep Both suggests an unused name that you can edit. Cancel stops the transfer. For regular files, Replace is also available. These choices appear in a horizontal row. Folders, packages and links offer Keep Both or Cancel.

Move to Trash sends selected items to Trash. A Trash error lists completed and remaining items so you can check the result before trying again.

Drag files from Finder into a pane to copy them; hold `⌘` to request a move when allowed. You can also drag selected rows between panes or into Finder. If PanePeek asks about unsaved edits before dragging out, choose Save or Discard, then drag again. Use Refresh after Finder changes files.

If a transfer stops partway through, completed files stay in place. Check the error details and destination before trying again: a failed copy can leave an incomplete file.

Use Reveal in Finder to open a folder or locate a file in Finder.

## Favourites

Click the star beside the folder path to save or remove it. Favourites are shared across panes and windows, and stay saved after quitting.

Use the toolbar Favourites button to search saved folders by name or path. Each result has buttons to open the folder in the active pane or remove it from Favourites. The menu-bar Favourites menu offers those actions too. It shows folder names, adding parent folders only to distinguish repeated names.

## Windows and reopening

File → New Window opens a separate window with its own folders and unsaved edits.

When you reopen PanePeek, it restores the last active window's folders and layout. Selection and sorting start fresh, with hidden files concealed. Save your edits before quitting.

## About and privacy

PanePeek → About PanePeek shows the version and build number. Select the version text and press `⌘-C` to copy it for a report. Privacy and Acknowledgements open local documents you can read offline.

See the [privacy policy](../PRIVACY.md) for file access and local storage details.

## Keyboard shortcuts

Shortcuts for file actions use the active pane. Text fields and the editor handle their usual typing shortcuts.

| Action | Shortcut |
| --- | --- |
| Go to Folder | `⌘-L` |
| Enclosing Folder | `⌘-Up` |
| Open selected folder | `⌘-Down` |
| Select all visible rows | `⌘-A` |
| Show hidden files | `⌘-⇧-period` |
| Refresh | `⌘-R` |
| Quick Look | `Space` |
| Copy absolute paths | `⌘-⌥-C` |
| Copy relative paths | `⌘-⌥-⇧-C` |
| Rename selected item | `Return` or `⌘-⇧-R` |
| New Text File | `⌘-⌥-N` |
| New Folder | `⌘-⇧-N` |
| Save | `⌘-S` |
| Undo / Redo | `⌘-Z` / `⌘-⇧-Z` |
| Details wider / narrower | `Control-⌘-Left` / `Right` |
| Open file's right-click menu | `⇧-F10` (`Fn` may be needed) |
| Cancel rename, close Quick Look or clear list selection | `Escape` |

## Formats and limits

| Content | Current support |
| --- | --- |
| Text and inline editing | UTF-8 files up to 1 MiB. |
| Images | Formats supported by macOS, up to 32 MiB and 64 million pixels. Animations show a still frame. |
| Video | Local videos that contain their own media and are supported by macOS. Audio-only and protected files show file information. |
| Other documents | File information and Quick Look where macOS supports the format. |
| Folders and packages | File information. The file list shows `-` for folder sizes; packages behave as files. |

Syntax highlighting covers common code and config files, including Swift, JSON, JavaScript/TypeScript and Python. Other UTF-8 text stays editable. HTML appears as source text.
