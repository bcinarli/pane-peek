# Repository privacy checks

Run from the repository root with Node.js 24+ and Git. The checker requires exactly Gitleaks 8.30.1, pinned in [privacy-rules.json](privacy-rules.json), using the default offline secret rules through [gitleaks.toml](gitleaks.toml). Use the [official release](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1) and verify its published checksum. Set `GITLEAKS_BIN` to an absolute executable path if it is outside `PATH`.

```sh
node --test tests/tooling/privacy-check.test.mjs
node scripts/check-privacy.mjs --tree HEAD
node scripts/check-privacy.mjs --staged
node scripts/check-privacy.mjs --range BASE HEAD
```

`--tree` scans every file in the named commit. `--staged` scans added or changed index blobs, including new files and type changes, without reading unstaged edits. `--range` scans every complete tree introduced by `BASE..HEAD`, plus the final tree, so adding then deleting a secret still fails. Supply existing commit references for `BASE` and `HEAD`; the necessary history must be available locally. The default is `--tree HEAD`. `--repo` selects another Git working tree.

Results contain repository-relative file names, source lines and rule IDs, with commit identifiers for committed content. Matched values and raw scanner output are withheld. Exit codes are `0` for no findings, `1` for findings and `2` for an incomplete check, including missing tools, invalid references and unsupported submodules. Do not treat exit code `2` as a pass.

Privacy rules detect personal home paths (including common URL/HTML encodings), machine cache paths, private vault links and common credential/signing filenames. Only exact file/value pairs in the policy are exempt, after decoding and normalising escaped Windows separators: the confirmed dummy design paths and an existing synthetic Windows highlighting fixture. A new path in those files still fails. Examples such as `.env.example` remain subject to secret scanning; inline Gitleaks allow comments and repository ignore files cannot suppress the scan.

The regression suite creates disposable Git repositories and synthetic credentials, including a temporary private key. It checks real scanner behaviour without contacting credential providers. Git symlinks are scanned as link text; their targets are never followed.

Files containing NUL bytes are counted as binary for manual privacy review. A passing result does not establish that screenshots, other binary content, arbitrary personal prose, every secret format, or earlier unscanned history are safe. Review those separately before publication. Scanner reports and snapshots are private temporary files removed when the process finishes normally; an interrupted process can leave temporary files. Never upload raw reports or logs containing sensitive data.

CI enforcement and local hook installation are separate implementation units. Running this command alone does not prevent a push or merge.
