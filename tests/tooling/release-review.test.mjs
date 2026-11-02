import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import { releaseNotes, verifyReleaseSource } from '../../scripts/release-review.mjs';

const directories = [];
afterEach(() => {
  for (const directory of directories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});
function git(root, ...args) {
  return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim();
}
function fixture() {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'panepeek-release-review-')));
  directories.push(root);
  git(root, 'init', '--initial-branch=main');
  git(root, 'config', 'user.name', 'Release Test');
  git(root, 'config', 'user.email', 'release@example.invalid');
  git(root, 'config', 'commit.gpgsign', 'false');
  writeFileSync(join(root, 'version.json'), '{"version":"0.1.0","build":4}\n');
  git(root, 'add', 'version.json');
  git(root, 'commit', '-m', 'Create release fixture');
  const commit = git(root, 'rev-parse', 'HEAD');
  git(root, 'update-ref', 'refs/remotes/origin/main', commit);
  return { root, commit, repository: 'example/panepeek', token: 'fixture-token' };
}
function requestFor(source, overrides = {}) {
  return async (url, options) => {
    assert.equal(url.origin, 'https://api.github.com');
    assert.equal(options.redirect, 'error');
    assert.equal(options.headers.Authorization, 'Bearer fixture-token');
    assert.equal(url.searchParams.get('head_sha'), source.commit);
    assert.equal(url.searchParams.get('event'), 'push');
    assert.equal(url.searchParams.get('branch'), 'main');
    const workflow = url.pathname.split('/').at(-2);
    const run = { head_sha: source.commit, head_branch: 'main', event: 'push', status: 'completed', conclusion: 'success', html_url: `https://github.com/example/panepeek/actions/runs/${workflow === 'ci.yml' ? 1 : 2}` };
    return { ok: true, json: async () => ({ workflow_runs: [{ ...run, ...overrides }] }) };
  };
}

test('an exact clean main commit requires successful main runs from both workflows', async () => {
  const source = fixture();
  const urls = await verifyReleaseSource({ ...source, request: requestFor(source) });
  assert.deepEqual(urls, ['https://github.com/example/panepeek/actions/runs/1', 'https://github.com/example/panepeek/actions/runs/2']);
});

test('invalid commit, repository or missing token fails before any request', async () => {
  const source = fixture();
  const request = () => { assert.fail('Invalid input reached the API.'); };
  for (const change of [{ commit: 'main' }, { commit: source.commit.slice(0, 7) }, { commit: `${source.commit}\n` }, { repository: '../elsewhere' }, { token: '' }]) {
    await assert.rejects(verifyReleaseSource({ ...source, ...change, request }));
  }
});

test('unmerged and dirty source trees fail before any request', async () => {
  const source = fixture();
  const request = () => { assert.fail('Ineligible source reached the API.'); };
  git(source.root, 'switch', '-c', 'feature');
  writeFileSync(join(source.root, 'candidate.txt'), 'feature content');
  git(source.root, 'add', 'candidate.txt');
  git(source.root, 'commit', '-m', 'Add unmerged fixture');
  const feature = git(source.root, 'rev-parse', 'HEAD');
  await assert.rejects(verifyReleaseSource({ ...source, commit: feature, request }), /main/);
  git(source.root, 'switch', 'main');
  writeFileSync(join(source.root, 'version.json'), '{"version":"0.1.0","build":5}');
  await assert.rejects(verifyReleaseSource({ ...source, request }), /clean/);
});

test('an eligible earlier main commit is checked before selecting its source', async () => {
  const source = fixture();
  writeFileSync(join(source.root, 'newer.txt'), 'Newer reviewed main content.');
  git(source.root, 'add', 'newer.txt');
  git(source.root, 'commit', '-m', 'Advance main fixture');
  git(source.root, 'update-ref', 'refs/remotes/origin/main', git(source.root, 'rev-parse', 'HEAD'));
  const current = git(source.root, 'rev-parse', 'HEAD');
  assert.equal((await verifyReleaseSource({ ...source, request: requestFor(source) })).length, 2);
  assert.equal(git(source.root, 'rev-parse', 'HEAD'), current);
});

test('non-successful, missing or mismatched latest workflow runs are rejected', async () => {
  const source = fixture();
  for (const change of [{ status: 'in_progress', conclusion: null }, { conclusion: 'failure' }, { conclusion: 'cancelled' }, { head_sha: 'a'.repeat(40) }, { head_branch: 'feature' }, { event: 'pull_request' }]) {
    await assert.rejects(verifyReleaseSource({ ...source, request: requestFor(source, change) }), /successful/);
  }
  await assert.rejects(verifyReleaseSource({ ...source, request: async () => ({ ok: true, json: async () => ({ workflow_runs: [] }) }) }), /successful/);
  const successful = requestFor(source);
  await assert.rejects(verifyReleaseSource({ ...source, request: (url, options) => url.pathname.includes('privacy.yml') ? Promise.resolve({ ok: true, json: async () => ({ workflow_runs: [] }) }) : successful(url, options) }), /privacy.yml/);
});

test('API failures fail closed without exposing response bodies', async () => {
  const source = fixture();
  await assert.rejects(verifyReleaseSource({ ...source, request: async () => ({ ok: false, status: 403, json: async () => { assert.fail('Error body must not be read.'); } }) }), /HTTP 403/);
  await assert.rejects(verifyReleaseSource({ ...source, request: async () => { throw new Error('network unavailable'); } }));
});

const notes = {
  metadata: { version: '0.1.0', build: 4 }, commit: 'a'.repeat(40), repository: 'example/panepeek', minimumVersion: '26.0',
  changelog: '# Changelog\n\n## Unreleased\n\n- Future work.\n\n## [0.1.0] - 2026-10-18\n\n### Added\n\n- Browse folders.\n\n## [0.0.1] - 2026-10-01\n\n- Earlier work.\n',
};
test('draft notes select app changes and metadata without release-process instructions', () => {
  const result = releaseNotes(notes);
  assert.match(result, /Draft: PanePeek 0\.1\.0 \(build 4\)/);
  assert.match(result, /Browse folders/);
  assert.doesNotMatch(result, /Future work|Earlier work/);
  assert.match(result, /macOS 26\.0\+.*Apple Silicon/);
  assert.match(result, /commit\/a{40}/);
  assert.doesNotMatch(result, /Developer ID|signing|notarisation|pending|before publication|installation check/);
});
test('unreleased content stays explicitly draft without a fabricated release date', () => {
  const result = releaseNotes({ ...notes, metadata: { version: '1.0.0', build: 5 } });
  assert.match(result, /Unreleased changelog draft/);
  assert.match(result, /Future work/);
  assert.doesNotMatch(result, /Browse folders|2026-10-18/);
});
test('missing or empty changelog content and invalid metadata are refused', () => {
  for (const changelog of ['# Changelog\n', '## Unreleased\n\n', '## [0.1.0] - 2026-10-18\n\n## Unreleased\n- Later.']) {
    assert.throws(() => releaseNotes({ ...notes, changelog }), /changelog/);
  }
  assert.throws(() => releaseNotes({ ...notes, metadata: { version: '0.1.0', build: 0 } }), /build/);
});

for (const kind of ['beta', 'rc']) {
  test(`${kind} notes identify the candidate and use Unreleased over a matching stable section`, () => {
    const result = releaseNotes({ ...notes, kind, sequence: '2' });
    assert.ok(result.startsWith(`# Draft: PanePeek 0.1.0-${kind}.2 (build 4)\n`));
    assert.ok(result.includes(`Tag: \`v0.1.0-${kind}.2\``));
    assert.match(result, /App version: 0\.1\.0 \(build 4\)/);
    assert.match(result, /Unreleased changelog draft/);
    assert.match(result, /Future work/);
    assert.doesNotMatch(result, /Browse folders|Earlier work|2026-10-18/);
    assert.match(result, /commit\/a{40}/);
    assert.match(result, /Install manually.*DMG/);
    assert.match(result, /older stable.*reinstall.*manually/);
  });
}

test('candidate kinds and sequences reject unsupported, ambiguous and unsafe inputs', () => {
  for (const kind of ['', 'preview', 'Beta', null]) {
    assert.throws(() => releaseNotes({ ...notes, kind, sequence: '1' }), /kind/);
  }
  for (const sequence of [undefined, '', '0', '-1', '1.5', '1e2', '01', ' 1', '1\n', '9007199254740992', 1]) {
    assert.throws(() => releaseNotes({ ...notes, kind: 'beta', sequence }), /sequence/);
  }
  for (const sequence of ['', '1']) {
    assert.throws(() => releaseNotes({ ...notes, kind: 'stable', sequence }), /sequence/);
  }
  assert.ok(releaseNotes({ ...notes, kind: 'rc', sequence: String(Number.MAX_SAFE_INTEGER) }).includes(`v0.1.0-rc.${Number.MAX_SAFE_INTEGER}`));
});

test('prereleases require non-empty Unreleased content even with a matching stable section', () => {
  for (const changelog of ['## [0.1.0] - 2026-10-18\n\n- Stable only.\n', '## Unreleased\n\n## [0.1.0] - 2026-10-18\n\n- Stable only.\n']) {
    assert.throws(() => releaseNotes({ ...notes, kind: 'beta', sequence: '1', changelog }), /Unreleased/);
  }
});

test('default and explicit stable notes identify the numeric tag without prerelease instructions', () => {
  const result = releaseNotes(notes);
  assert.equal(result, releaseNotes({ ...notes, kind: 'stable' }));
  assert.ok(result.includes('Tag: `v0.1.0`'));
  assert.doesNotMatch(result, /App version:|Install manually/);
});

function reviewFixture() {
  const source = fixture();
  mkdirSync(join(source.root, 'scripts'));
  for (const name of ['release-review.mjs', 'release-metadata.mjs']) {
    copyFileSync(new URL(`../../scripts/${name}`, import.meta.url), join(source.root, 'scripts', name));
  }
  writeFileSync(join(source.root, 'CHANGELOG.md'), notes.changelog);
  const run = (args, env = {}) => spawnSync(process.execPath, [join(source.root, 'scripts/release-review.mjs'), ...args], {
    cwd: source.root, encoding: 'utf8', timeout: 10_000,
    env: { ...process.env, GITHUB_OUTPUT: undefined, GITHUB_REPOSITORY: source.repository, ...env },
  });
  return { ...source, run };
}

function reviewPackage(root) {
  const path = join(root, 'package');
  const contents = join(path, 'PanePeek.app', 'Contents');
  mkdirSync(contents, { recursive: true });
  const plist = join(contents, 'Info.plist');
  writeFileSync(plist, JSON.stringify({ CFBundleShortVersionString: '0.1.0', CFBundleVersion: '4', LSMinimumSystemVersion: '26.0' }));
  execFileSync('plutil', ['-convert', 'xml1', plist]);
  for (const format of ['dmg', 'zip']) {
    const name = `PanePeek-0.1.0-build4-macos-arm64.${format}`;
    const bytes = Buffer.from(`Fixture ${format} bytes`);
    writeFileSync(join(path, name), bytes);
    writeFileSync(join(path, `${name}.sha256`), `${createHash('sha256').update(bytes).digest('hex')}  ${name}\n`);
  }
  return path;
}

test('candidate CLI derives tags and titles without changing numeric app metadata', () => {
  const source = reviewFixture();
  const metadata = readFileSync(join(source.root, 'version.json'), 'utf8');
  for (const [args, tag, title, prerelease] of [
    [[], 'v0.1.0', 'PanePeek 0.1.0 (build 4)', false],
    [['beta', '2'], 'v0.1.0-beta.2', 'PanePeek 0.1.0-beta.2 (build 4)', true],
    [['rc', '1'], 'v0.1.0-rc.1', 'PanePeek 0.1.0-rc.1 (build 4)', true],
  ]) {
    const result = source.run(['candidate', ...args]);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { tag, title, prerelease, artifactName: `PanePeek-${tag.slice(1)}-build4-review` });
    assert.equal(readFileSync(join(source.root, 'version.json'), 'utf8'), metadata);
  }
});

test('notes CLI checks real package metadata/checksums and preserves an existing notes file', { skip: process.platform !== 'darwin' }, () => {
  const source = reviewFixture();
  const path = reviewPackage(source.root);
  let result = source.run(['notes', path, 'beta', '1']);
  assert.equal(result.status, 0, result.stderr);
  const file = join(path, 'release-notes.md');
  const content = readFileSync(file, 'utf8');
  assert.ok(content.includes('Tag: `v0.1.0-beta.1`'));
  assert.ok(content.includes(source.commit));
  assert.match(content, /Future work/);
  assert.doesNotMatch(content, /Browse folders/);
  result = source.run(['notes', path, 'rc', '1']);
  assert.equal(result.status, 1);
  assert.equal(readFileSync(file, 'utf8'), content);
  const tampered = reviewPackage(join(source.root, 'tampered'));
  writeFileSync(join(tampered, 'PanePeek-0.1.0-build4-macos-arm64.dmg'), 'Changed fixture bytes');
  result = source.run(['notes', tampered, 'rc', '1']);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /checksum/);
  assert.throws(() => readFileSync(join(tampered, 'release-notes.md')), { code: 'ENOENT' });
});

test('notes CLI rejects invalid candidate inputs before inspecting a package', () => {
  const source = reviewFixture();
  const result = source.run(['notes', join(source.root, 'absent-package'), 'preview', '1']);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /kind must/);
  assert.doesNotMatch(result.stderr, /Info\.plist|ENOENT/);
});

test('candidate CLI appends the artifact output with stable-compatible naming', () => {
  const source = reviewFixture();
  const output = join(source.root, 'workflow-outputs');
  for (const [args, label] of [
    [[], '0.1.0'], [['beta', '2'], '0.1.0-beta.2'], [['rc', '1'], '0.1.0-rc.1'],
  ]) {
    writeFileSync(output, 'earlier=value\n');
    const result = source.run(['candidate', ...args], { GITHUB_OUTPUT: output });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(output, 'utf8'), 'earlier=value\n' +
      `artifact_name=PanePeek-${label}-build4-review\n`);
  }
});

test('invalid candidates and output paths cannot publish workflow outputs', () => {
  const source = reviewFixture();
  const output = join(source.root, 'workflow-outputs');
  writeFileSync(output, 'earlier=value\n');
  for (const args of [['preview', '1'], ['beta'], ['beta', '1\n'], ['stable', '1']]) {
    const result = source.run(['candidate', ...args], { GITHUB_OUTPUT: output });
    assert.equal(result.status, 1);
    assert.equal(readFileSync(output, 'utf8'), 'earlier=value\n');
  }
  for (const invalid of ['relative-output', `${output}\n`]) {
    const result = source.run(['candidate', 'beta', '1'], { GITHUB_OUTPUT: invalid });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /output file/);
  }
});

test('workflow preflight refuses selected helpers without an artifact output', () => {
  const workflow = readFileSync(new URL('../../.github/workflows/release-preparation.yml', import.meta.url), 'utf8');
  const step = workflow.match(/        id: candidate\n        run: \|\n((?:          .+\n)+)/);
  assert.ok(step, 'The candidate preflight must be available before signing.');
  const source = reviewFixture();
  const output = join(source.root, 'workflow-outputs');
  for (const legacyOutput of ['', 'tag=v0.1.0-beta.1\n']) {
    writeFileSync(output, '');
    writeFileSync(join(source.root, 'scripts/release-review.mjs'),
      `import { appendFileSync } from 'node:fs';\nappendFileSync(process.env.GITHUB_OUTPUT, ${JSON.stringify(legacyOutput)});\n`);
    const result = spawnSync('bash', ['-e', '-o', 'pipefail', '-c', step[1].replace(/^ {10}/gm, '')], {
      cwd: source.root, encoding: 'utf8', timeout: 10_000,
      env: { ...process.env, RELEASE_KIND: 'beta', RELEASE_SEQUENCE: '1', GITHUB_OUTPUT: output },
    });
    assert.equal(result.status, 1, 'Missing artifact output must stop the job before signing.');
  }
});
