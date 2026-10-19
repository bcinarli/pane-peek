import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import { notariseReleaseBundle } from '../../scripts/release-notarisation.mjs';

const directories = [];
afterEach(() => {
  for (const directory of directories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});
const identity = 'a'.repeat(40);
const cdhash = 'b'.repeat(40);
const id = '12345678-1234-1234-1234-123456789abc';

function fixture({ status = 'Accepted', issues = null, changeLog = {}, fail = '' } = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-notarisation-'));
  directories.push(directory);
  const bundle = join(directory, 'PanePeek.app');
  mkdirSync(bundle);
  const calls = [];
  let currentHash = cdhash;
  const options = {
    verify: () => currentHash,
    finalise: () => {
      calls.push('publish');
      if (fail === 'publish') { throw new Error('Injected final-package failure.'); }
    },
    run(command, args) {
      const action = command === 'ditto' ? 'archive' : args.slice(0, 2).join(' ');
      calls.push(action);
      if (action === fail) { throw new Error('Injected external-tool failure.'); }
      if (action === 'archive') { writeFileSync(args.at(-1), 'signed submission fixture'); }
      if (action === 'notarytool submit') { return JSON.stringify({ id }); }
      if (action === 'notarytool info') { return JSON.stringify({ id, status }); }
      if (action === 'notarytool log') {
        const sha256 = createHash('sha256').update(readFileSync(join(directory, 'notarisation/submission.zip'))).digest('hex');
        writeFileSync(args.at(-1), JSON.stringify({ jobId: id, status, sha256, issues, ticketContents: [{ cdhash, arch: 'arm64' }], ...changeLog }));
      }
      return '';
    },
  };
  return { directory, bundle, calls, options, changeHash: value => { currentHash = value; } };
}
function run(source, profile = 'test-profile') {
  return notariseReleaseBundle(source.bundle, identity, profile, source.options);
}

test('only a matching Accepted result with a clean log reaches stapling and validation', async () => {
  const source = fixture();
  const result = await run(source);
  assert.ok(result?.id);
  assert.equal(result.id, id);
  assert.deepEqual(source.calls, ['archive', 'notarytool submit', 'notarytool wait', 'notarytool info', 'notarytool log', 'stapler staple', 'stapler validate', 'publish']);
});

test('pending and rejected submissions preserve receipts and never staple', async () => {
  for (const status of ['In Progress', 'Invalid', 'Rejected']) {
    const source = fixture({ status });
    await assert.rejects(run(source), /notarisation/i);
    assert.equal(JSON.parse(readFileSync(join(source.directory, 'notarisation/submission.json'))).id, id);
    assert.ok(!source.calls.includes('stapler staple'));
    assert.equal(source.calls.includes('notarytool log'), status !== 'In Progress');
  }
});

test('mismatched logs and unreviewed issues cannot produce a stapled result', async () => {
  for (const changeLog of [{ jobId: 'bad-id' }, { sha256: '0'.repeat(64) }, { status: 'Invalid' }, { ticketContents: [] }, { issues: [{ severity: 'warning', message: 'Review required.' }] }]) {
    const source = fixture({ changeLog });
    await assert.rejects(run(source));
    assert.ok(!source.calls.includes('stapler staple'));
  }
});

test('a retry reuses the saved submission and rejects changed code or upload bytes before contacting Apple', async () => {
  const source = fixture();
  await run(source);
  source.calls.length = 0;
  await run(source);
  assert.ok(!source.calls.includes('archive') && !source.calls.includes('notarytool submit'));
  source.calls.length = 0;
  source.changeHash('c'.repeat(40));
  await assert.rejects(run(source), /changed|match/i);
  assert.deepEqual(source.calls, []);
  source.changeHash(cdhash);
  writeFileSync(join(source.directory, 'notarisation/submission.zip'), 'tampered');
  await assert.rejects(run(source), /changed|match/i);
  assert.deepEqual(source.calls, []);
});

test('stapling and ticket-validation failures remain failures with the submission available to resume', async () => {
  for (const fail of ['stapler staple', 'stapler validate']) {
    const source = fixture({ fail });
    await assert.rejects(run(source), /external-tool failure/);
    assert.equal(JSON.parse(readFileSync(join(source.directory, 'notarisation/submission.json'))).id, id);
  }
});

test('invalid profile names are refused before any external tool or job output', async () => {
  for (const profile of ['', '--password', 'profile\n', 'a'.repeat(65)]) {
    const source = fixture();
    await assert.rejects(run(source, profile), /profile|Usage/i);
    assert.deepEqual(source.calls, []);
    assert.deepEqual(readdirSync(source.directory), ['PanePeek.app']);
  }
});


test('an existing job lock and an upload without a receipt are preserved without another upload', async () => {
  const locked = fixture();
  mkdirSync(join(locked.directory, 'notarisation'));
  const lock = join(locked.directory, 'notarisation/job.lock');
  writeFileSync(lock, 'another job');
  await assert.rejects(run(locked), /lock/);
  assert.equal(readFileSync(lock, 'utf8'), 'another job');
  assert.deepEqual(locked.calls, []);
  const orphaned = fixture();
  mkdirSync(join(orphaned.directory, 'notarisation'));
  const archive = join(orphaned.directory, 'notarisation/submission.zip');
  writeFileSync(archive, 'existing upload');
  await assert.rejects(run(orphaned), /without a receipt/);
  assert.equal(readFileSync(archive, 'utf8'), 'existing upload');
  assert.deepEqual(orphaned.calls, []);
});

test('final packaging holds the job lock and retains the submission on failure', async () => {
  const source = fixture({ fail: 'publish' });
  const finalise = source.options.finalise;
  source.options.finalise = () => {
    assert.ok(readdirSync(join(source.directory, 'notarisation')).includes('job.lock'));
    finalise();
  };
  await assert.rejects(run(source), /final-package failure/);
  assert.equal(JSON.parse(readFileSync(join(source.directory, 'notarisation/submission.json'))).id, id);
  assert.ok(!readdirSync(join(source.directory, 'notarisation')).includes('job.lock'));
});
