import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import * as notarisation from '../../scripts/release-notarisation.mjs';
import { packageReleaseBundle } from '../../scripts/release-package.mjs';
import { verifyReleaseDiskImage, withMountedDiskImage } from '../../scripts/release-dmg.mjs';

const directories = [];
afterEach(() => {
  for (const directory of directories.splice(0)) { rmSync(directory, { recursive: true, force: true }); }
});
const identity = 'a'.repeat(40);
const cdhash = 'b'.repeat(40);
const id = '12345678-1234-1234-1234-123456789abc';
function fixture({ tickets = [{ cdhash }], fail = '' } = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-dmg-'));
  directories.push(directory);
  const image = join(directory, 'PanePeek.dmg');
  writeFileSync(image, 'signed read-only image');
  const calls = [];
  let hash = cdhash;
  const options = {
    verify: () => hash,
    finalise: () => { calls.push('publish'); },
    run(command, args) {
      const action = args.slice(0, 2).join(' ');
      calls.push(action);
      if (action === fail) { throw new Error('Injected tool failure.'); }
      if (action === 'notarytool submit') {
        assert.ok(args[2].endsWith('.dmg'));
        assert.deepEqual(readFileSync(args[2]), readFileSync(image));
        return JSON.stringify({ id });
      }
      if (action === 'notarytool info') { return JSON.stringify({ id, status: 'Accepted' }); }
      if (action === 'notarytool log') {
        const upload = join(directory, 'dmg-notarisation/submission.dmg');
        writeFileSync(args.at(-1), JSON.stringify({ jobId: id, status: 'Accepted', sha256: createHash('sha256').update(readFileSync(upload)).digest('hex'), issues: null, ticketContents: tickets }));
      }
      return '';
    },
  };
  return { directory, image, calls, options, changeHash: value => { hash = value; } };
}

test('DMG notarisation uploads the signed image and requires its own matching ticket before publication', async () => {
  const source = fixture();
  await notarisation.notariseReleaseDiskImage(source.image, identity, 'test-profile', source.options);
  assert.deepEqual(source.calls, ['notarytool submit', 'notarytool wait', 'notarytool info', 'notarytool log', 'stapler staple', 'stapler validate', 'publish']);
});

test('a ticket only for the nested app or failed stapling cannot publish the DMG', async () => {
  const wrong = fixture({ tickets: [{ cdhash: 'c'.repeat(40), arch: 'arm64' }] });
  await assert.rejects(notarisation.notariseReleaseDiskImage(wrong.image, identity, 'test-profile', wrong.options), /ticket/);
  assert.ok(!wrong.calls.includes('stapler staple') && !wrong.calls.includes('publish'));
  const failed = fixture({ fail: 'stapler validate' });
  await assert.rejects(notarisation.notariseReleaseDiskImage(failed.image, identity, 'test-profile', failed.options), /failure/);
  assert.ok(!failed.calls.includes('publish'));
  assert.ok(existsSync(join(failed.directory, 'dmg-notarisation/submission.json')));
});

test('DMG resume reuses its submission and refuses a changed container before contacting Apple', async () => {
  const source = fixture();
  await notarisation.notariseReleaseDiskImage(source.image, identity, 'test-profile', source.options);
  source.calls.length = 0;
  await notarisation.notariseReleaseDiskImage(source.image, identity, 'test-profile', source.options);
  assert.ok(!source.calls.includes('notarytool submit'));
  source.calls.length = 0; source.changeHash('c'.repeat(40));
  await assert.rejects(notarisation.notariseReleaseDiskImage(source.image, identity, 'test-profile', source.options), /changed|match/);
  assert.deepEqual(source.calls, []);
});

test('a mounted image detaches its own device even when verification fails', async () => {
  const calls = [];
  const run = (command, args) => {
    calls.push(args);
    if (args[0] === 'attach') { return JSON.stringify({ 'system-entities': [{ 'dev-entry': '/dev/disk42', 'mount-point': '/Volumes/PanePeek test' }] }); }
  };
  await assert.rejects(withMountedDiskImage('/review/image.dmg', async volume => {
    assert.equal(volume, '/Volumes/PanePeek test'); throw new Error('Failed package verification.');
  }, { run }), /Failed package verification/);
  assert.deepEqual(calls.at(-1), ['detach', '/dev/disk42']);
});

test('mount failure cannot run verification or detach an unrelated disk', async () => {
  const calls = [];
  await assert.rejects(withMountedDiskImage('/review/image.dmg', () => { calls.push('verify'); }, {
    run(command, args) { calls.push(args[0]); throw new Error('Mount failed.'); },
  }), /Mount failed/);
  assert.deepEqual(calls, ['attach']);
});


test('packaging withholds ZIP and workflow outputs when the DMG cannot be verified', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-package-'));
  directories.push(directory);
  const output = join(directory, 'outputs');
  mkdirSync(join(directory, 'PanePeek.app'));
  writeFileSync(join(directory, 'PanePeek.app/fixture.txt'), 'complete app fixture');
  const calls = [];
  await assert.rejects(packageReleaseBundle(join(directory, 'PanePeek.app'), { version: '1.0.0', build: 5 }, {
    env: { GITHUB_OUTPUT: output },
    buildDiskImage: async () => { throw new Error('Invalid disk image.'); },
    run: () => { calls.push('zip'); },
  }), /Invalid disk image/);
  assert.deepEqual(calls, []);
  assert.equal(existsSync(output), false);
  assert.equal(existsSync(join(directory, 'PanePeek-1.0.0-build5-macos-arm64.zip')), false);
});

test('packaging retains ZIP and exports both verified download formats with final checksums', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-package-'));
  directories.push(directory);
  const output = join(directory, 'outputs');
  const image = join(directory, 'PanePeek.dmg');
  await packageReleaseBundle(join(directory, 'PanePeek.app'), { version: '1.0.0', build: 5 }, {
    env: { GITHUB_OUTPUT: output },
    buildDiskImage: async () => ({ diskImage: image, diskImageChecksum: image + '.sha256' }),
    run: (command, args) => { assert.equal(command, 'ditto'); writeFileSync(args.at(-1), 'final stapled app ZIP'); },
  });
  const archive = join(directory, 'PanePeek-1.0.0-build5-macos-arm64.zip');
  assert.equal(readFileSync(archive + '.sha256', 'utf8').split('  ')[0], createHash('sha256').update(readFileSync(archive)).digest('hex'));
  const fields = Object.fromEntries(readFileSync(output, 'utf8').trim().split('\n').map(line => line.split('=')));
  assert.equal(fields.archive, archive);
  assert.equal(fields.disk_image, image);
  assert.equal(fields.disk_image_checksum, image + '.sha256');
  assert.equal(fields.version, '1.0.0');
  assert.equal(fields.build, '5');
});


test('an attached image without a mounted volume still detaches only its owned device', async () => {
  const calls = [];
  await assert.rejects(withMountedDiskImage('/review/image.dmg', () => assert.fail('No mounted volume.'), {
    run(command, args) {
      calls.push(args);
      return JSON.stringify({ 'system-entities': [{ 'dev-entry': '/dev/disk42' }] });
    },
  }), /no mounted volume/);
  assert.deepEqual(calls.at(-1), ['detach', '/dev/disk42']);
});

test('DMG inspection rejects external app links and wrong Applications destinations, with mount cleanup', async () => {
  for (const linkedApp of [true, false]) {
    const directory = mkdtempSync(join(tmpdir(), 'panepeek-mounted-'));
    directories.push(directory);
    if (linkedApp) { symlinkSync('/Applications/PanePeek.app', join(directory, 'PanePeek.app')); }
    else { mkdirSync(join(directory, 'PanePeek.app')); }
    mkdirSync(join(directory, '.background'));
    for (const name of ['.DS_Store', '.VolumeIcon.icns', '.background/installer.tiff']) { writeFileSync(join(directory, name), 'fixture'); }
    symlinkSync('/unexpected', join(directory, 'Applications'));
    const calls = [];
    await assert.rejects(verifyReleaseDiskImage('/review/image.dmg', '/review/PanePeek.app', {
      run(command, args) {
        calls.push([command, ...args]);
        if (args[0] === 'imageinfo') { return JSON.stringify({ Format: 'UDZO' }); }
        if (args[0] === 'attach') { return JSON.stringify({ 'system-entities': [{ 'dev-entry': '/dev/disk42', 'mount-point': directory }] }); }
        return '';
      },
    }), linkedApp ? /embedded directory/ : /unexpected destination/);
    assert.deepEqual(calls.at(-1), ['hdiutil', 'detach', '/dev/disk42']);
    assert.equal(calls.some(call => call[0] === 'diff'), false);
  }
});
