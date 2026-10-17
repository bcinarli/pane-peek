# Repository privacy checks

Run from the repository root with Node.js 24+ and Git. The checker requires exactly Gitleaks 8.30.1, pinned in [privacy-rules.json](privacy-rules.json), using the default offline secret rules through [gitleaks.toml](gitleaks.toml). Use the [official release](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1) and verify its published checksum. Set `GITLEAKS_BIN` to an absolute executable path if it is outside `PATH`.

```sh
node --test tests/tooling/*.test.mjs
node scripts/check-privacy.mjs --tree HEAD
node scripts/check-privacy.mjs --staged
node scripts/check-privacy.mjs --range BASE HEAD
```

`--tree` scans every file in the named commit. `--staged` scans added or changed index blobs, including new files and type changes, without reading unstaged edits. `--range` scans every complete tree introduced by `BASE..HEAD`, plus the final tree, so adding then deleting a secret still fails. Supply existing commit references for `BASE` and `HEAD`; the necessary history must be available locally. The default is `--tree HEAD`. `--repo` selects another Git working tree.

Results contain repository-relative file names, source lines and rule IDs, with commit identifiers for committed content. Matched values and raw scanner output are withheld. Exit codes are `0` for no findings, `1` for findings and `2` for an incomplete check, including missing tools, invalid references and unsupported submodules. Do not treat exit code `2` as a pass.

Privacy rules detect personal home paths (including common URL/HTML encodings), machine cache paths, private vault links and common credential/signing filenames. Only exact file/value pairs in the policy are exempt, after decoding and normalising escaped Windows separators: the confirmed dummy design paths and an existing synthetic Windows highlighting fixture. A new path in those files still fails. Examples such as `.env.example` remain subject to secret scanning; inline Gitleaks allow comments and repository ignore files cannot suppress the scan.

The regression suite creates disposable Git repositories and synthetic credentials, including a temporary private key. It checks real scanner behaviour without contacting credential providers. Git symlinks are scanned as link text; their targets are never followed.

Files containing NUL bytes are counted as binary for manual privacy review. A passing result does not establish that screenshots, other binary content, arbitrary personal prose, every secret format, or earlier unscanned history are safe. Review those separately before publication. Scanner reports and snapshots are private temporary files removed when the process finishes normally; an interrupted process can leave temporary files. Never upload raw reports or logs containing sensitive data.

## CI and merge enforcement

The [privacy workflow](../.github/workflows/privacy.yml) configures the stable `Privacy and secrets` check for PRs targeting `main`, pushes to `main` and manual dispatch. It uses a Linux runner with Node.js 24, downloads the policy's Gitleaks version and verifies the archive against a pinned SHA256 before extraction. It runs the regression suite and checks the entire final Git tree. Full history is fetched for the additional PR base-to-head or main before-to-after range scan. Manual dispatch checks the selected commit's complete tree.

The workflow has read-only repository permissions, no persisted checkout credentials, no application secrets and no uploaded scanner reports. Missing history, download/checksum problems, findings or incomplete scans fail the job. Keep action hashes, scanner version/checksum and the required-check identity aligned when upgrading. Review changes to the checker, policy and workflow as part of the PR.

Enable the live required check only after verifying a successful hosted run and the GitHub Actions check identity. Preserve the existing build/test requirement and other merge rules. [Evidence](../agent-paper-trail/specs/001-mvp/evidence/privacy-secrets-checker.md) owns the current hosted/enforcement state.

## Optional local hooks

Make Node.js 24+ and the pinned Gitleaks version available to Git, including GUI clients. `GITLEAKS_BIN`, when needed, must be available to each Git process. From the repository root:

```sh
node scripts/privacy-hooks.mjs install
node scripts/privacy-hooks.mjs uninstall
```

Installation writes executable `pre-commit` and `pre-push` wrappers to Git's common hooks directory. It is opt-in for each clone. Linked worktrees using the default hook location share these wrappers; a worktree with its own hook manager needs manual integration. Existing hooks, symlinks or a configured `core.hooksPath` stop setup before either wrapper changes. Repeating setup is safe; uninstall removes only unchanged owned wrappers and preserves unrelated hooks and configuration.

Pre-commit checks the actual staged blobs, preserving partial staging. Pre-push checks every proposed ref update, including force pushes and commit tags. Existing branches use the destination's old object as the range base. For new refs, Git reads fresh destination refs and checks every commit not already reachable there, plus the final tree. Destination objects unavailable locally cannot exclude history. An empty destination therefore requires scanning all reachable history. Deletion-only pushes upload no file content and need no scan.

Outgoing scans require complete local history. Fetch missing destination objects or unshallow the checkout before retrying an incomplete check. New-ref discovery contacts the destination through Git; secret scanning remains offline. All worktrees need the checked-in tooling and scanner environment; an older checkout without tooling blocks the Git operation with a setup message.

For an existing hook manager, keep its ownership and run these commands from the working-tree root:

```sh
# pre-commit
node scripts/privacy-hooks.mjs pre-commit
# pre-push: forward Git's two arguments and original standard input
node scripts/privacy-hooks.mjs pre-push "$@"
```

Propagate non-zero exits. If another pre-push check consumes standard input, arrange for each check to receive the complete original input. [Git documents the hook arguments and input](https://git-scm.com/docs/githooks#_pre_push).

Hooks can be bypassed or removed, so required CI remains the merge gate. The file-content limits above apply; commit/tag messages and ref names are outside this checker. Keep credentials and private data out of those fields too.
