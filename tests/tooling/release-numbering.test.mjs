import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
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
  for (const name of ['prepare-release.mjs', 'release-metadata.mjs', 'build-app.mjs']) {
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
