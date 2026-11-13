import assert from 'node:assert/strict';
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, test } from 'node:test';

const root = fileURLToPath(new URL('../..', import.meta.url));
const temporary = [];
afterEach(() => {
  for (const directory of temporary.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function fixture(metadata = { version: '0.1.0', build: 3 }) {
  const directory = mkdtempSync(join(tmpdir(), 'panepeek-release-numbering-'));
  temporary.push(directory);
  mkdirSync(join(directory, 'scripts'));
  for (const name of ['prepare-release.mjs', 'release-metadata.mjs', 'release-signing.mjs', 'release-package.mjs', 'release-notarisation.mjs', 'release-dmg.mjs', 'dmg-layout.mjs', 'app-documents.mjs', 'launcher-resource.mjs', 'bundle-metadata.mjs', 'build-app.mjs']) {
    copyFileSync(join(root, 'scripts', name), join(directory, 'scripts', name));
  }
  writeFileSync(join(directory, 'version.json'), JSON.stringify(metadata, null, 2) + '\n');
  return directory;
}

function run(directory, args = []) {
  return spawnSync(process.execPath, [join(directory, 'scripts/prepare-release.mjs'), ...args], {
    encoding: 'utf8', timeout: 10_000,
  });
}

function metadata(directory) {
  return JSON.parse(readFileSync(join(directory, 'version.json'), 'utf8'));
}

function noTemporaryFiles(directory) {
  assert.deepEqual(readdirSync(directory).sort(), ['scripts', 'version.json']);
}

test('new preparations allocate consecutive builds and retain version and other metadata', () => {
  const directory = fixture({ version: '0.1.0', build: 3, channel: 'preview' });
  assert.equal(run(directory).status, 0);
  assert.deepEqual(metadata(directory), { version: '0.1.0', build: 4, channel: 'preview' });
  assert.equal(run(directory).status, 0);
  assert.equal(metadata(directory).build, 5);
  noTemporaryFiles(directory);
});

test('an explicit version change still advances the existing build sequence', () => {
  const directory = fixture();
  const result = run(directory, ['--version', '1.0.0']);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(metadata(directory), { version: '1.0.0', build: 4 });
  assert.match(result.stdout, /1\.0\.0/);
});

test('invalid arguments and requested versions leave metadata unchanged', () => {
  const directory = fixture();
  const path = join(directory, 'version.json');
  const before = readFileSync(path);
  for (const args of [['--unknown'], ['--version'], ['--version', '1.0'], ['--version', '1.0.0-beta'], ['--version', '1.0.0', '--version', '2.0.0']]) {
    assert.equal(run(directory, args).status, 1, JSON.stringify(args));
    assert.deepEqual(readFileSync(path), before);
    noTemporaryFiles(directory);
  }
});

test('invalid current metadata and exhausted build numbers fail without replacement', () => {
  const directory = fixture();
  const path = join(directory, 'version.json');
  for (const value of ['{ invalid', '{}', 'null', '{"version":"0.1","build":3}', '{"version":"0.1.0","build":0}', '{"version":"0.1.0","build":"3"}', '{"version":"0.1.0","build":1.5}', JSON.stringify({ version: '0.1.0', build: Number.MAX_SAFE_INTEGER })]) {
    writeFileSync(path, value);
    assert.equal(run(directory).status, 1, value);
    assert.equal(readFileSync(path, 'utf8'), value);
    noTemporaryFiles(directory);
  }
  writeFileSync(path, JSON.stringify({ version: '0.1.0', build: 3 }));
  assert.equal(run(directory).status, 0);
  assert.equal(metadata(directory).build, 4);
});

test('an existing preparation lock is refused and preserved', () => {
  const directory = fixture();
  const lock = join(directory, 'version.json.lock');
  writeFileSync(lock, 'Another preparation owns this lock.\n');
  const result = run(directory);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /A release preparation lock exists/);
  assert.equal(metadata(directory).build, 3);
  assert.equal(readFileSync(lock, 'utf8'), 'Another preparation owns this lock.\n');
});

test('overlapping preparations never allocate the same build or expose partial JSON', async () => {
  const directory = fixture();
  const readErrors = [];
  const observer = setInterval(() => {
    try { metadata(directory); } catch (error) { readErrors.push(error); }
  }, 1);
  let results;
  try {
    results = await Promise.all(Array.from({ length: 8 }, () => new Promise((resolve, reject) => {
      const child = spawn(process.execPath, [join(directory, 'scripts/prepare-release.mjs')]);
      let stdout = '', stderr = '';
      child.stdout.on('data', data => { stdout += data; });
      child.stderr.on('data', data => { stderr += data; });
      child.on('error', reject);
      child.on('close', status => { resolve({ status, stdout, stderr }); });
    })));
  } finally {
    clearInterval(observer);
  }
  assert.deepEqual(readErrors, []);
  const successful = results.filter(result => result.status === 0);
  assert.ok(successful.length > 0);
  const builds = successful.map(result => Number(result.stdout.match(/build (\d+)/)?.[1])).sort((a, b) => a - b);
  assert.deepEqual(builds, Array.from({ length: successful.length }, (_, index) => 4 + index));
  assert.equal(metadata(directory).build, 3 + successful.length);
  for (const result of results.filter(result => result.status !== 0)) {
    assert.equal(result.status, 1);
    assert.match(result.stderr, /A release preparation lock exists/);
  }
  noTemporaryFiles(directory);
});

test('atomic replacement preserves metadata permissions', () => {
  const directory = fixture();
  const path = join(directory, 'version.json');
  chmodSync(path, 0o640);
  assert.equal(run(directory).status, 0);
  assert.equal(statSync(path).mode & 0o777, 0o640);
});

test('packaging commands reject invalid shared metadata before build tools run', () => {
  const directory = fixture({ version: '0.1.0', build: 0 });
  const path = join(directory, 'version.json');
  const before = readFileSync(path);
  for (const args of [[], ['--release']]) {
    const result = spawnSync(process.execPath, [join(directory, 'scripts/build-app.mjs'), ...args], {
      encoding: 'utf8', timeout: 10_000,
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /version.json: build must be a positive safe integer/);
    assert.deepEqual(readFileSync(path), before);
    noTemporaryFiles(directory);
  }
});

function buildFixture() {
  const directory = fixture();
  for (const name of ['assets', 'xcode', 'bin']) { mkdirSync(join(directory, name)); }
  for (const name of ['LICENSE', 'NOTICE', 'PRIVACY.md', 'assets/PanePeek.icns', 'assets/lucide-LICENSE.txt', 'assets/panepeek', 'xcode/Info.plist']) {
    copyFileSync(join(root, name), join(directory, name));
  }
  writeFileSync(join(directory, 'bin/PanePeek'), 'Fixture executable');
  const toolLog = join(directory, 'tools.log');
  writeFileSync(join(directory, 'bin/xcrun'), `#!${process.execPath}
const { appendFileSync } = require('node:fs');
appendFileSync(process.env.FIXTURE_TOOL_LOG, 'xcrun\\n');
const args = process.argv.slice(2);
if (args.includes('--show-bin-path')) { console.log(__dirname); }
else if (args.includes('dump-package')) { console.log(JSON.stringify({ platforms: [{ platformName: 'macos', version: '26.0' }] })); }
else if (args[0] !== 'actool' && args[1] !== 'build') { process.exitCode = 1; }
`, { mode: 0o755 });
  const signing = join(directory, 'scripts/release-signing.mjs');
  renameSync(signing, join(directory, 'scripts/real-release-signing.mjs'));
  writeFileSync(signing, `
import { appendFileSync } from 'node:fs';
export * from './real-release-signing.mjs';
function validateIdentity() { appendFileSync(process.env.FIXTURE_TOOL_LOG, 'validate identity\\n'); }
export { validateIdentity as validateReleaseIdentity, validateIdentity as validateReviewIdentity };
export function signLocalSandboxBundle(bundlePath) {
  appendFileSync(process.env.FIXTURE_TOOL_LOG, 'signing\\n');
  console.log('Ready to sign ' + bundlePath);
  throw new Error('Fixture signing boundary');
}
`);
  const build = (args, kind, sequence) => spawnSync(process.execPath, [join(directory, 'scripts/build-app.mjs'), ...args], {
    encoding: 'utf8', timeout: 10_000,
    env: { ...process.env, PATH: `${join(directory, 'bin')}:${process.env.PATH}`,
      DEVELOPER_DIR: directory, FIXTURE_TOOL_LOG: toolLog, RELEASE_KIND: kind, RELEASE_SEQUENCE: sequence },
  });
  return { build, toolLog };
}

test('packaging writes the candidate suffix alongside numeric metadata before signing', { skip: process.platform !== 'darwin' }, () => {
  const { build } = buildFixture();
  const cases = [
    [[], 'beta', '2', undefined],
    ...['--release', '--sandbox-review'].flatMap(mode => [
      [[mode], undefined, undefined, undefined],
      [[mode], 'stable', '', undefined],
      [[mode], 'beta', '2', 'beta.2'],
      [[mode], 'rc', '1', 'rc.1'],
    ]),
  ];
  for (const [args, kind, sequence, suffix] of cases) {
    const result = build(args, kind, sequence);
    assert.equal(result.status, args.length ? 1 : 0, result.stderr);
    if (args.length) { assert.match(result.stderr, /Fixture signing boundary/); }
    const bundlePath = result.stdout.match(/^(?:Ready to sign|Built) (.+)$/m)?.[1];
    assert.ok(bundlePath, result.stderr);
    const info = JSON.parse(execFileSync('/usr/bin/plutil',
      ['-convert', 'json', '-o', '-', join(bundlePath, 'Contents/Info.plist')], { encoding: 'utf8' }));
    assert.equal(info.CFBundleShortVersionString, '0.1.0');
    assert.equal(info.CFBundleVersion, '3');
    assert.equal(info.PanePeekPrereleaseSuffix, suffix, JSON.stringify({ args, kind, sequence }));
  }
});

test('packaging rejects invalid candidate inputs before build or signing tools run', () => {
  const { build, toolLog } = buildFixture();
  for (const mode of ['--release', '--sandbox-review']) {
    for (const [kind, sequence, message] of [
      ['beta', undefined, /positive safe integer/],
      ['rc', '01', /positive safe integer/],
      ['stable', '1', /do not accept a sequence/],
      ['preview', '1', /kind must be stable, beta or rc/],
    ]) {
      const result = build([mode, '--sign', 'a'.repeat(40)], kind, sequence);
      assert.equal(result.status, 1, result.stderr);
      assert.match(result.stderr, message);
      assert.equal(existsSync(toolLog), false);
    }
  }
});
