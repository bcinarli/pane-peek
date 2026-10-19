import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
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
  const root = mkdtempSync(join(tmpdir(), 'panepeek-release-review-'));
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
