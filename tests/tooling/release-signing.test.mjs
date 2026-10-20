import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, test } from 'node:test';
import { validateReleaseEntitlements } from '../../scripts/release-signing.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));
const directories = [];
afterEach(() => {
  for (const directory of directories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function fixture() {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-release-signing-'));
  directories.push(directory);
  mkdirSync(join(directory, 'scripts'));
  for (const name of readdirSync(join(root, 'scripts')).filter(name => name.endsWith('.mjs'))) {
    copyFileSync(join(root, 'scripts', name), join(directory, 'scripts', name));
  }
  writeFileSync(join(directory, 'version.json'), '{"version":"0.1.0","build":4}\n');
  return directory;
}

function run(directory, args) {
  const before = readFileSync(join(directory, 'version.json'));
  const result = spawnSync(process.execPath, [join(directory, 'scripts/build-app.mjs'), ...args], {
    encoding: 'utf8', timeout: 15_000,
  });
  assert.equal(result.status, 1, result.stderr);
  assert.deepEqual(readFileSync(join(directory, 'version.json')), before);
  assert.deepEqual(readdirSync(directory).sort(), ['scripts', 'version.json']);
  return result;
}

test('release signing rejects names, ad hoc signing and malformed fingerprints before building', () => {
  const directory = fixture();
  for (const identity of ['-', 'Developer ID Application', 'a'.repeat(39), 'a'.repeat(41), 'g'.repeat(40), 'a'.repeat(40) + '\n']) {
    const result = run(directory, ['--release', '--sign', identity]);
    assert.match(result.stderr, /40-character SHA-1/);
  }
});

test('signing cannot change development builds or accept duplicate and incomplete options', () => {
  const directory = fixture();
  for (const args of [['--sign', 'a'.repeat(40)], ['--release', '--sign'], ['--release', '--release'], ['--release', '--sign', 'a'.repeat(40), '--sign', 'b'.repeat(40)]]) {
    assert.match(run(directory, args).stderr, /Usage:/);
  }
});

test('an unavailable signing identity fails before building or creating release assets', { skip: process.platform !== 'darwin' }, () => {
  const result = run(fixture(), ['--release', '--sign', '0'.repeat(40)]);
  assert.match(result.stderr, /not a valid Developer ID Application/);
});

const sandboxEntitlements = {
  'com.apple.security.app-sandbox': true,
  'com.apple.security.files.user-selected.read-write': true,
  'com.apple.security.files.bookmarks.app-scope': true,
};

test('sandbox entitlement policy accepts exactly the approved enabled permissions', () => {
  assert.doesNotThrow(() => validateReleaseEntitlements(sandboxEntitlements));
});

test('sandbox entitlement policy rejects missing, disabled and mistyped permissions', () => {
  assert.throws(() => validateReleaseEntitlements({}), /sandbox entitlements/);
  for (const key of Object.keys(sandboxEntitlements)) {
    const missing = { ...sandboxEntitlements };
    delete missing[key];
    for (const values of [missing, { ...sandboxEntitlements, [key]: false }, { ...sandboxEntitlements, [key]: 'true' }]) {
      assert.throws(() => validateReleaseEntitlements(values), /sandbox entitlements/);
    }
  }
});

test('sandbox entitlement policy rejects additional access and runtime exceptions', () => {
  for (const key of ['com.apple.security.network.client', 'com.apple.security.get-task-allow', 'com.apple.security.cs.disable-library-validation']) {
    for (const value of [true, false]) {
      assert.throws(() => validateReleaseEntitlements({ ...sandboxEntitlements, [key]: value }), /sandbox entitlements/);
    }
  }
});
